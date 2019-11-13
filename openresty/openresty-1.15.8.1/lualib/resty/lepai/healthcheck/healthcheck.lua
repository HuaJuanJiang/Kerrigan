-- Copyright © (C) Zhendong (DDJ)
-- 最近更新
--          2019.03.14 11:05
--      健康检查主模块，函数的模块最后只提供一个接口，
--  需要通过定时器healthcheck timer来驱动
--
--          2019.07.01 11:56
--      对全局变量进行改造，尽量用本地变量表示

local du               = require"resty.lepai.upstream.dynamic_upstream"
local ctc              = require"resty.lepai.basic.composite_tab_c"
local sec              = require"resty.lepai.basic.get_ngx_sec"
local ba               = require"ngx.balancer"
local cj               = require "cjson"
local healthcheck_zone = ngx.shared['healthcheck_zone']
local say              = ngx.say
local log              = ngx.log
local INFO             = ngx.INFO
local ERR              = ngx.ERR
local find             = ngx.re.find
local thread           = ngx.thread.spawn
local wait             = ngx.thread.wait
local pairs            = pairs
local setmetatable     = setmetatable

--[[
local healthcheck_table = { 
    timestamp = sec.sec(),                  私有时间戳
    status = "running",                     当前健康检查模块状态
    http_path = "/",                        健康检查的路径
    health = {                              健康检查（对不健康的节点进行健康检查，如果节点已经健康，满足下面条件以后，将节点视为健康）
        interval = 4,                       健康检查间隔（单位：秒）
        successes = 2,                      健康检查成功次数算作节点已经健康
        http_status = { 200, 302 },         健康检查合格节点的HTTP状态码
    },  
    unhealth = {                            健康检查（对健康的节点进行检查，如果发现节点出现问题，在满足下面的条件以后，将节点视为不健康）
        interval = 4,                       健康检查间隔（单位：秒）
        http_failures = 2,                  健康检查失败次数算作节点已经宕机
        timeout = 1,                        健康检查超时时间，超过时间，算作这次检查失败（单位：秒）
        http_status = { 429, 404, 500, 501, 健康检查不合格节点的HTTP状态码
                        502, 503, 504, 505 },
    },
}
]]
-- 健康检查模板，和另一个文件当中的模板是一样的，
-- 但是作用却不一样，这里模板的主要作用是：
-- 在第一次健康检查的时候，dict是没有任何数据的，
-- 因此需要这个模板作为第一次创建的原始数据，
-- 而另一个文件当中模板，仅仅是为了重置模板
-- healthcheck template
local healthcheck_table = {
    timestamp = sec.sec(),
	status = "running",
	http_path = "/",
	health = {
		interval = 4,	
		successes = 2,
		http_status = { 200, 302 },
	},
	unhealth = {
		interval = 4,
		http_failures = 2,
		timeout = 1,
		http_status = { 429, 404, 500, 501,
			    	    502, 503, 504, 505 },
	},
}

-- implantation healthcheck template
-- 尝试新的写法，将这个模板直接引用到初始化对象当中
-- 在对象第一次引用的时候就很方便了
local _M = { 
    _AUTHOR = 'zhendong 2019.01.07',
    _VERSION = '0.1.7',   
	hc_template = healthcheck_table
}

local mt = { __index = _M }

function _M:new()
    local self = { 
        _index = table  
    }   
    return setmetatable(self, mt) 
end

-- 获取healthcheck zone key
local function hcz_get(key)
    return healthcheck_zone:get(key)
end

-- 写入 healthcheck zone
local function hcz_set(key, val)
    healthcheck_zone:set(key, val)
end

-- 初始化模块，引用当中set get 函数，
-- 默认将key存于upstream list，如果
-- 需求有变更，需要自己重写
local du = du:new()
local usz_get = du.zone_get
local usz_set = du.zone_set
 
-- judge http_status:status_code)
-- 健康检查status_code检测函数:
-- 在健康检查以后，会将这个 ip port 检测结果返回，
-- 经过过滤是一个状态码，下面的函数可以将状态码进行
-- 比对，来确定它是属于health_status_code 还是
-- unhealth_status_code，从而告诉后面的代码
-- 这次健康检查的结果
local function http_status(status_code)
	for _, v in pairs(HEALTH_STATUS)do
		if v == status_code then
			return 'health_status_code'
		end
	end
	for _, v in pairs(UNHEALTH_STATUS)do
		if v == status_code then
			return 'unhealth_status_code'
		end
	end
	return 1
end

-- set a ip_port status from "down" to "up"
-- 设置ip:port状态从"down"到"up"函数:
-- 设置server ip:port的状态status，
-- 由“down”到“up”，设置这个意味着这个server
-- 的状态是可用的，通过了健康检查，因为在
-- 动态负载均衡的连接器当中，它只会去转发当前
-- upstream的状态status=“up”的server块儿
local function get_up(upstream, ip, port)
	local get_upstream = usz_get(upstream)
	local get_upstream = cj.decode(get_upstream)
	local ip_port = ip..':'..port
    local pool = get_upstream['pool']
    for num = 1, ctc.ctco(pool) do
        local server = 'server'..num
        if pool[server]['ip_port'] == ip_port then
            pool[server]['status'] = 'up'
        end
    end 
	local sec = sec.sec()
    get_upstream['pool'] = pool
    get_upstream['timestamp'] = sec
	local get_upstream = cj.encode(get_upstream)	
	usz_set('upstream_list_update_time', sec)
	usz_set(upstream, get_upstream)
end

-- set a ip_port status from "up" to "down"
-- 设置ip:port状态从"up"到"down"函数:
local function get_down(upstream, ip, port)
	local get_upstream = usz_get(upstream)
    local get_upstream = cj.decode(get_upstream)
    local ip_port = ip..':'..port
    local pool = get_upstream['pool']
    for num = 1, ctc.ctco(pool) do
        local server = 'server'..num
        if pool[server]['ip_port'] == ip_port then
            pool[server]['status'] = 'down'
        end
    end 
	local sec = sec.sec()
    get_upstream['pool'] = pool
    get_upstream['timestamp'] = sec
	local get_upstream = cj.encode(get_upstream)	
	usz_set('upstream_list_update_time', sec)
	usz_set(upstream, get_upstream)
end

-- 作为在健康检查当中最重要的两个参数
-- success 和 unhealth_failure
-- 需要对每次健康检查失败还是成功情况次数进行统计
-- 需要存储到共享空间当中，每个upstream的每个server
-- 的健康检查都有唯一的计数统计，不能重复。

-- UNHEALTH_FAIL timer
-- 健康检查unhealth_failure计数器
local function health_failure_hander(
    timer_name, 
    upstream, 
    ip, port)
    local get_UNHEALTH_FAIL
	get_UNHEALTH_FAIL = 
    hcz_get(timer_name..'UNHEALTH_FAIL')
    local temp_healthfail_name = 
    timer_name..'UNHEALTH_FAIL'
    get_UNHEALTH_FAIL = 
    (not get_UNHEALTH_FAIL 
    and {1} or {get_UNHEALTH_FAIL})[1]
	--if not get_UNHEALTH_FAIL then
	--	get_UNHEALTH_FAIL = 1
	--end
    -- 判断当前health_failure 和模板配置的比值，
    -- 是否到达次数
	if get_UNHEALTH_FAIL < UNHEALTH_FAIL then
        log(ERR,'[ ERR ]: '..'Healthcheck: '
        ..' The Upstream Server:'
        ..' { '..upstream..' }-[ '..ip
        ..':'..port..' ] '
        ..' Health_failure rate : '
        ..'[ '..get_UNHEALTH_FAIL..' ] of [ '
        ..UNHEALTH_FAIL..' ]')
		get_UNHEALTH_FAIL = get_UNHEALTH_FAIL + 1
        hcz_set(temp_healthfail_name,
        get_UNHEALTH_FAIL)
		return
    -- 满足unhealth_failure条件，也就是健康检查
    -- 失败次数已经超过了设置值
	else
        log(ERR,'[ INFO ]: '..'Healthcheck: '
        ..' The Upstream Server:'
        ..' { '..upstream..' }-[ '..ip
        ..':'..port
        ..' ] BECOMING NOT HEALTH NOW ！！！'
        ..' Health_failure rate : '
        ..'[ '..get_UNHEALTH_FAIL..' ] of [ '
        ..UNHEALTH_FAIL..' ]')
		local res = get_down(upstream, ip, port)
        hcz_set(temp_healthfail_name, nil)
		return
	end
end

-- HEALTH_SUCCE timer
-- 健康检查success 计数器
local function health_success_hander(
    timer_name, 
    upstream, 
    ip, port)
    local get_HEALTH_SUCCE
    get_HEALTH_SUCCE = 
    hcz_get(timer_name..'HEALTH_SUCCE')
    local temp_healthsucce_name = 
    timer_name..'HEALTH_SUCCE'
    get_HEALTH_SUCCE = 
    (not get_HEALTH_SUCCE 
    and {1} or {get_HEALTH_SUCCE})[1]
    --if not get_HEALTH_SUCCE then
    --    get_HEALTH_SUCCE = 1 
    --end 
    if get_HEALTH_SUCCE < HEALTH_SUCCE then
        log(ERR, '[ ERR ]: '..'Unhealthcheck: '
        ..' The Upstream Server:'
        ..' { '..upstream..' }-[ '..ip
        ..':'..port..' ] '
        ..' Health_success rate : '
        ..'[ '..get_HEALTH_SUCCE..' ] of [ '
        ..HEALTH_SUCCE..' ]')
        get_HEALTH_SUCCE = get_HEALTH_SUCCE + 1 
        hcz_set(temp_healthsucce_name, 
        get_HEALTH_SUCCE)
        return
    else
        log(ERR,'[ ERR ]: '..'Unhealthcheck: '
        ..' The Upstream Server:'
        ..' { '..upstream..' }-[ '..ip
        ..':'..port..' ] BECOMING VERY HEALTH NOW ！！！'
        ..' Health_success rate : '
        ..'[ '..get_HEALTH_SUCCE..' ] of [ '
        ..HEALTH_SUCCE..' ]')
        local res = get_up(upstream, ip, port)
        hcz_set(temp_healthsucce_name, nil)
        return
    end 
end

-- 健康检查的原理是利用sock进行通讯检查，可以类比于shell当中的curl
-- 返回的一个带头部信息的响应，其中就包含了状态码，所以这个健康检查
-- 的本质就是对每一个收到的ip:port进行通讯检查，可以看到，这个检查是
-- 七层协议，也就是七层的健康检查
-- health checker factory
-- 健康检查驱动器
local function health_checker(
    upstream, 
    up, count)
	local ip = up[count][1]
	local port = up[count][2]
    -- 为了确保唯一性，将ip地址的最后一段数字+端口，组成一个
    -- 特有的字符，保证在一个upstream当中是不会重复的
    local a, b, c, d = 
    string.match(ip, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
    local timer_name = upstream..a..b..c..d..port
	-- healthcheck interval
    -- 这里的interval，也就是健康检查的间隔控制，是通过定时器的执行时间
    -- 来控制的，举例: 
    -- healthcheck_timer_interval 定时器执行次数: 是2秒/次，
    -- HEALTH_INTER healthcheck模板当中interval数: 4秒/次
    -- time_HEALTH_INTER 经过计算后的数: 2
    -- 那么根据这个数字和定时器执行时间来控制interval
    local get_HEALTH_INTER
    local timer_HEALTH_INTER
	timer_HEALTH_INTER = 
    HEALTH_INTER / healthcheck_timer_interval
	get_HEALTH_INTER = 
    hcz_get(timer_name..'HEALTH_INTER')
    local temp_interval_name = 
    timer_name..'HEALTH_INTER'
    -- 判断interval
    get_HEALTH_INTER = 
    (not get_HEALTH_INTER
    and {1} or {get_HEALTH_INTER})[1]
	--if not get_HEALTH_INTER then
	--	get_HEALTH_INTER = 1
	--end
    log(INFO, '[ INFO ]: '..upstream
    ..': [ '..timer_name..' ]  get_HEALTH_INTER: '
    ..get_HEALTH_INTER..' timer_HEALTH_INTER: '
    ..timer_HEALTH_INTER)
    --判断执行次数间隔，为什么不是“==”。理论上这样也可以，但是可能会有一个问题
    --要是由于程序的某个文件导致 get_time_HEALTH_INTER 和 time_HEALTH_INTER 不相等，
    --但是 get_time_HEALTH_INTER 更大，那不就意味着永远装不上规则，导致它一直循环，
    --但是不执行健康检查？？？
	if get_HEALTH_INTER >= timer_HEALTH_INTER then
        hcz_set(temp_interval_name, nil)
	else
		get_HEALTH_INTER = get_HEALTH_INTER + 1
        hcz_set(temp_interval_name,
        get_HEALTH_INTER)
		return
	end
	-- start socket check
    -- 建立sock tcp 连接
	log(INFO, '[ INFO ]: '
    ..'SATRT Health_checker: { '
    ..upstream
    ..' }--[ '..ip..':'..port..' ]')
	local health_socket, err = ngx.socket.tcp()
  	if not health_socket then
    	log(ERR, '[ INFO ]: '
        .."healthcheck: failed to "
        .."create stream socket: ", err)
    	return
	end
    -- 设置tcp连接超时时间
	health_socket:settimeout(UNHEALTH_TIME * 1000)
	-- connect judge
    -- 判断ip:port是否可以连接
    -- 这里调用了 hand_UNHEALTH_FAIL()函数其实就是为了
    -- 记录连接失败次数，达到模板设置以后，就会把
    -- 这个ip:port标记为失败节点
	local ok, err = 
    health_socket:connect(ip, port)
	if not ok then
        health_failure_hander(
        timer_name, 
        upstream, 
        ip, 
        port)
		return
	end
	-- send http_path
    -- 发送http_path路径到建立的连接上
	local request = 
    ("GET %s HTTP/1.0\r\nHost: %s\r\n\r\n"):format(http_path, ip)
	local bytes, err = health_socket:send(request)
	if not bytes then
        log(ERR, '[ INFO ]: '..'health [ postion ] 2'
        , 'bytes:', bytes, ' err: ', err)
        health_failure_hander(
        timer_name, 
        upstream, 
        ip, 
        port)
		return
	end
	-- recevive data
    -- 接收收到的数据，包含了响应信息
	local data, err = 
    health_socket:receive()
   	if not data then
        health_failure_hander(
        timer_name, 
        upstream, 
        ip, 
        port)
		return
    end
	-- get http_status
    -- 获取响应头当中的状态码
	local from, to = 
    find( data, 
    [[^HTTP/\d+\.\d+\s+(\d+)]], 
    "joi", 
    nil, 
    1)
    if from then
        status_code = 
        tonumber(data:sub(from, to))
        -- 将获取到的状态码通过函数 http_status()进行比对，
        -- 得知这个状态码是属于健康的还是不健康的
	    local res = http_status(status_code)
        -- 检测到健康，那么什么都不做
        if res == 'health_status_code' then
            return
        elseif res == 'unhealth_status_code' then
            health_failure_hander(
            timer_name, 
            upstream, 
            ip, 
            port)
            return
        -- 如果没有这个状态码，我就认为这是不健康的
        else
            health_failure_hander(
            timer_name, 
            upstream, 
            ip, 
            port)
            return
        end
    else
        log(ERR, '[ ERR ]: '
        .."healthcheck : bad status code from  '"
        , ip, ":", port, "': ", status_code)
        return
    end
end

-- unhealth checker factory
-- 非健康检查驱动器
-- 工作机制同上
-- 那么这两个驱动器的区别在哪里呢？
-- health checker 是针对健康的节点进行健康检查，如果节点出现问题，
-- 那么就标记为不可用节点;
-- unhealth checker 是针对不健康的节点进行健康检查，如果节点恢复正常，
-- 那么就重新标记为可用节点;
local function unhealth_checker(
    upstream, 
    down, 
    count)
	local ip = down[count][1]
	local port = down[count][2]
    local a, b, c, d = 
    string.match(ip, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	local timer_name = upstream..a..b..c..d..port
	--healthcheck interval
    local get_UNHEALTH_INTER
    local timer_UNHEALTH_INTER
	timer_UNHEALTH_INTER = 
    UNHEALTH_INTER / healthcheck_timer_interval
	get_UNHEALTH_INTER = 
    hcz_get(timer_name..'UNHEALTH_INTER')
    local temp_interval_name = 
    timer_name..'UNHEALTH_INTER'
    get_UNHEALTH_INTER = 
    (not get_UNHEALTH_INTER
    and {1} or {get_UNHEALTH_INTER})[1]
	--if not get_UNHEALTH_INTER then
	--	get_UNHEALTH_INTER = 1
	--end
    log(INFO, '[ INFO ]: '..upstream
    ..': [ '..timer_name..' ]  get_UNHEALTH_INTER: '
    ..get_UNHEALTH_INTER..' timer_UNHEALTH_INTER: '
    ..timer_UNHEALTH_INTER)
	if get_UNHEALTH_INTER >= timer_UNHEALTH_INTER then
        hcz_set(temp_interval_name, nil)
	else
	    get_UNHEALTH_INTER = get_UNHEALTH_INTER + 1
        hcz_set(temp_interval_name,
        get_UNHEALTH_INTER)
		return
	end
	-- start socket check
	log(INFO,'[ INFO ]: '
    ..'SATRT Unhealth_checker: { '
    ..upstream..' }--[ '
    ..ip..':'..port..' ]')
	local health_socket, err = ngx.socket.tcp()
  	if not health_socket then
    	log(ERR, '[ ERR ]: '.."failed to create "
        .."stream socket: ", err)
    	return
	end
	health_socket:settimeout(UNHEALTH_TIME * 1000)
	--connect judge
	local ok, err = health_socket:connect(ip, port)
	if not ok then
        log(ERR,'[ ERR ]: '..'Unhealthcheck FAILED:'
        ..' health socket failed to connect, '
        ..'{ '..upstream..' }---[ '..ip..':'
        ..port..' ] IS STILL DOWN ！！！')
		return
	end
	--send http_path
	local request = 
    ("GET %s HTTP/1.0\r\nHost: %s\r\n\r\n"):format(http_path, ip)
	local bytes, err = 
    health_socket:send(request)
    log(ERR, '[ ERR ]: '
    ..'unhealth [ postion ] 2', 
    'bytes:', bytes, ' err: ', err)
	if not bytes then
		log(ERR, '[ ERR ]: '
        ..'unhealthcheck: failed to '
        ..'send http request, '
        ..'{ '..upstream..' }---[ '..ip..':'
        ..port..' ] IS STILL DOWN ！！！')
		return
	end
	-- recevive data
	local data, err = health_socket:receive()
    if not data then
        log(ERR, '[ ERR ]: '..'unhealthcheck: '
        ..'failed to receive data, ' 
        ..'{ '..upstream..' }---[ '..ip..':'
        ..port..' ] IS STILL DOWN ！！！')
        return
    end
	--get http_status
	local from, to = 
    find(
    data, 
    [[^HTTP/\d+\.\d+\s+(\d+)]], 
    "joi", 
    nil, 
    1)
    if from then
        status_code = 
        tonumber(data:sub(from, to))
        local res = http_status(status_code)
        if res == 'health_status_code' then
            health_success_hander(
            timer_name, 
            upstream, 
            ip, 
            port)
            return
        elseif res == 'unhealth_status_code' then
            return
        else
            log(ERR, '[ ERR ]: '
            ..'unhealthcheck: a [ '..status_code
            ..' ] code , can not see it , so [ '
            ..ip..':'..port..' ] is STILL UNHEALTH')
            return
        end
    else
        log(ERR, '[ ERR ]: '
        .."unhealthcheck: "
        .."bad status code from  '", 
        ip, ":", port, "': ", status_code)
        return
    end
end

-- up healthcheck
-- 对一个upstream当中server的status状态为up，
-- 也就是可用节点，进行health_checker健康检查
local function checker_health(upstream, up)
    local up = cj.decode(up)
    for num = 1, #up do
       -- 并发执行
       thread(health_checker, upstream, up, num)
       --wait(thread_obj)
       --health_checker(upstream, up, i)
    end
end

-- down unhealthcheck
-- 对一个upstream当中server的status状态为down，
-- 也就是非可用节点，进行unhealth_checker健康检查
local function checker_unhealth(upstream, down)
	local down = cj.decode(down)
    for num = 1, #down do
       -- 并发执行
       thread(unhealth_checker, upstream, down, num)
       --wait(thread_obj)
       --unhealth_checker(upstream, down, i)
    end
end

-- 健康检查主函数，也是对外提供唯一接口的函数，需要配合定时器
-- 这里需要传入的参数有：
-- upstream: 准备进行健康检查的upstream名字 ，例如vmims
-- up: upstream当中status为up的server数组，包含ip:port，例如{'192.168.211.130:8888','192.168.211.131:9999'}
-- down: upstream当中status为down的server数组，包含ip:port，例如{'192.168.211.130:5555','192.168.211.131:6666'}
-- healthcheck main
function _M:main_checker(
    upstream, 
    up, 
    down, 
    delay)
    -- 计划将定时器的执行间隔作为interval的计时工具、
    -- 如果不存在就指定
    healthcheck_timer_interval = 
    (not delay and {1} or {delay})[1]
	--if not delay then
	--	healthcheck_timer_interval = 1
	--else
	--	healthcheck_timer_interval = delay
	--end
    -- 每个upstream在health_zone当中都有以自己作为key为命名的
    -- 健康检查模板，但是第一次启动的时候是没有健康检查模板的，
    -- 因此需要创建
	local upstream_model = 
    healthcheck_zone:get(upstream)
	if upstream_model then
		local upstream_model = 
        cj.decode(upstream_model)
		if upstream_model.status ~= 'running' then
			log(INFO, '[ INFO ]: '
            ..'NOTICE: [ '..upstream
            ..' ] healthcheck IS NOT RUNNING ！！！ ')
			return
		end	
		http_path       = upstream_model.http_path
		HEALTH_INTER    = upstream_model.health.interval
		HEALTH_SUCCE    = upstream_model.health.successes
		HEALTH_STATUS   = upstream_model.health.http_status
		UNHEALTH_INTER  = upstream_model.unhealth.interval
		UNHEALTH_FAIL   = upstream_model.unhealth.http_failures
		UNHEALTH_TIME   = upstream_model.unhealth.timeout
		UNHEALTH_STATUS = upstream_model.unhealth.http_status
	else
		http_path       = self.hc_template.http_path
		HEALTH_INTER    = self.hc_template.health.interval
		HEALTH_SUCCE    = self.hc_template.health.successes
		HEALTH_STATUS   = self.hc_template.health.http_status
		UNHEALTH_INTER  = self.hc_template.unhealth.interval
		UNHEALTH_FAIL   = self.hc_template.unhealth.http_failures
		UNHEALTH_TIME   = self.hc_template.unhealth.timeout
		UNHEALTH_STATUS = self.hc_template.unhealth.http_status
		local hc_template = cj.encode(self.hc_template)
		local res = healthcheck_zone:set(upstream, hc_template)
	end
    -- 健康检查子入口
	checker_health(upstream, up)
	checker_unhealth(upstream, down)
end

return _M

