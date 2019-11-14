-- Copyright © (C) Zhendong (DDJ)
-- healthcheck定时器
-- 最近更新日期：
--   2019.03.15 16:57
--
--   2019.04.04 11:11
--          这次更新的内容是针对 healthcheck zone 的 upstream list更新
--      希望可以在修改healthcheck的时候将 healthcheck zone的 upstream list
--      的时间戳作为条件来触发定时器，然后通过定时器逐个遍历数组对应的
--      healthcheck模板，根据每个私有时间戳的变化来判断是否更新
--
--   2019.07.01 11:46
--          这次更新是由于Kerrigan的版本对应的openresty版本进行了升级，因此
--      对于全局变量问题的审查更加严格了，也是因为之前局部变量只在代码块儿内
--      生效，而在外部是不生效的，例如：
--[[
    local up_list = {}
    local down_list = {}
    for num = 1, ctc.ctco(pool) do
        if status == 'up' then
            table.insert(up_list, 'test')
        elseif status == 'down' then
            table.insert(down_list, 'test')
        end 
    end 
    up_list = cj.encode(up_list)
    down_list = cj.encode(down_list)
    log(INFO,'up_list:',up_list)
    log(INFO,'down_list:',down_list)
]]
--      最后的结果:打印出来的列表为空，因为insert是在for和if条件当中执行的，而up_list
--      本身的定义也是局部变量，因此导致数据其实无法插入的，在外部打印就是一个空数组。
--      因此在之前的版本是全局变量来操作的

--      但是在openresty-1.15.8.1的时候，可以不把up_list定义成全局变量的情况下，就在代码块
--      内添加数据。
      
local stt              = require"resty.lepai.basic.str_to_table"
local ctc              = require"resty.lepai.basic.composite_tab_c"
local sec              = require"resty.lepai.basic.get_ngx_sec"
local hc               = require"resty.lepai.healthcheck.healthcheck"
local cj               = require"cjson"
local delay            = ngx.req.get_uri_args()["delay"]
local file_path        = ngx.req.get_uri_args()["upstream_file_path"]
local upstream_zone    = ngx.shared['upstream_zone']
local healthcheck_zone = ngx.shared['healthcheck_zone']
local thread           = ngx.thread.spawn
local wait             = ngx.thread.wait
local log              = ngx.log
local say              = ngx.say
local INFO             = ngx.INFO
local ERR              = ngx.ERR
local timer            = ngx.timer.at
local timers           = ngx.timer.every
local pairs            = pairs
local setmetatable     = setmetatable

--healthcheck API
local function start_healthcheck(upstream, up, down)
	local checker = hc:new()
	checker:main_checker(
    upstream, 
    up, down, 
    delay)
end

--get upstream 'up' and 'down' ip:port list 
local function tab_spawn_checker(upstream)
    local title_body = 
    upstream_zone:get(upstream)
    if not title_body then
        log(ERR, '[ ERR ]: '
	    ..'upstream_zone dict can not get [ '
	    ..upstream..' ] , it does not exist,'
        ..' can not healthcheck!!!')
        return
    end
    local title_body = cj.decode(title_body)
    local pool = title_body['pool']
	local up_list = {}
	local down_list = {}
    for num = 1, ctc.ctco(pool) do
        local server = 'server'..num
   	    local status = 
        title_body['pool'][server]['status']
        local ip_port = 
        title_body['pool'][server]['ip_port']
        local len = string.len(ip_port)
        local spear = string.find(ip_port, ':')
        local ip = string.sub(ip_port, 1, spear - 1)
        local port = string.sub(ip_port, spear + 1, len)
        if status == 'up' then
            local tab = {}
            table.insert(tab, ip)
            table.insert(tab, port)
            table.insert(up_list, tab)
		elseif status == 'down' then
			local tab = {}
			table.insert(tab, ip)
			table.insert(tab, port)
			table.insert(down_list, tab)
		end
    end
    up_list = cj.encode(up_list)
	down_list = cj.encode(down_list)
    log(INFO,'[ UP LIST ]:',up_list)
    log(INFO,'[ DOWN LIST ]:',down_list)
	return up_list, down_list	
end 

-- get every upstream 
-- 对每个upstream开始进行健康
-- 为什么没有在这里页进行并发的健康检查呢？
-- 可以看到我已经注释了 “thread(start_healthcheck, upstream, up_list, down_list)”
-- 经过03.19半个下午的一个问题的排查，
-- 由于并发执行导致了全局变量出现了篡改，混用。
-- 所以根结就在于在这里也执行了并发的操作，
-- 在第一个还未返回的情况下，就执行下一个，
-- _G表当中变量出现混用，最后导致代码出现了异常，
--
-- 第二次更新
--   这次还是采用了轻线程并发的方式来执行，
--   针对前面提出的问题已经找到了解决的方法
--   通过设置wait来等待上一个轻线程执行完毕，
--   如果不加入wait的话，由于for循环，
--   它是会几乎将所有 thread(start_healthcheck, upstream, up_list, down_list) 
--   并发执行最后的问题就是：全局变量共享。
--   依赖全局变量的计数器出现偏差，最后导致问题。
local function spawn_checker(upstream_list)
	local upstream_list = upstream_list
	for num = 1, #upstream_list do
		local up_list, down_list = 
        tab_spawn_checker(upstream_list[num])
		if up_list and down_list then
			log(INFO, '[ INFO ]: '
			..'{ '..upstream_list[num]..' }'
			..'-UP LIST: '..up_list, '\r\n'
			..'{ '..upstream_list[num]
            ..' }-DOWN LIST: '..down_list)
            local thread_obj = 
            thread(start_healthcheck, 
            upstream_list[num], 
            up_list, down_list)
            wait(thread_obj)
		end
	end
end

-- healthcheck main
-- 通过读取upstream配置文件来进行健康检查，
-- 为什么不直接通过dict获取upstream列表来健康检查？
-- 而且直接dict效率还很高，为什么呢？
-- 考虑到可能在dict当中有记录的upstream，
-- 但是在nginx配置文件当中压根不存在，
-- 导致无谓的健康检查
local function healthcheck()
    local upstream_list = 
    upstream_zone:get('upstream_list')
    if not upstream_list then
        log(INFO, '[ ERR ]: '
        ..' NO UPSTREAM LIST FOUND ！！！'
        ..'HEALTHCHECK CANNOT CONTINUE ！！！')
        return
    end
    -- 因为“hc_upstream_list_update_time”时间戳本
    -- 身是不会更新的，只有在修改healthcheck模板
    -- 的时候才会创建或者更新它，但是遇到redis和
    -- nginx都没有时间戳，就不会触发定时器进行更新，
    -- 因此需要在这里先定义它以触发定时器。
    local time = 
    healthcheck_zone:get(
    'hc_upstream_list_update_time')
    if not time then
        local sec = sec.sec()
        healthcheck_zone:set(
        'hc_upstream_list_update_time', 
        sec)
    end
    -- healthcheck_zone:set('hc_upstream_list', upstream_list)
    local upstream_list = 
    stt.stt(upstream_list)
    spawn_checker(upstream_list)
end

-- timer(3, healthcheck)
timers(delay, healthcheck)

