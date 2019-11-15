-- Copyright © (C) Zhendong (DDJ)
-- init upstream config timer 
-- 初始化 upstream list 定时器
--[[
注意：遇到table类型的anry字典，通常可以通过for循环打印，但是想要获取
完成列表，可以通过json的encode来实现
更新日期
  2019.02.28 
    优化代码
  
  2019.03.26
        增加redis判断，因为会有一些意外情况发生，比如redis现在存活，
    但是由于nginx重启，导致需要定时器需要从新从redis当中导出数据，
    但是倘若redis数据发生异常，那么就需要dict的数据是由初始化的方式
    实现，然后将数据反推给redis；但redis数据要是没有问题，那么
    下面这种初始化的方式，可能导致在下一次定时器启动的时候，将redis
    原有的数据覆盖掉，因此在这种情况下，希望初始化不执行。
        这次更新的主要内容就是针对这个情况进行先行判断，但是也只能避免
    一部分redis数据异常的情况

  2019.04.01
        在其他定时器增加了“并集”逻辑设计，完全避免了覆盖数据的问题
    现在打算对这个定时器也进行类似更新，正在考虑逻辑上是否允许
    由于在之前增加对持久化 upstream 文件作为初始化文件的功能，那么
     增加“并集”逻辑是合乎情理的

  2019.04.02 15:45
        增加了针对每个title的时间戳，是为了定时器可以很方便的检测状态

  2019.04.09 10:15
        这次更新是针对(n)nginx+redis的架构，确保第一个nginx会执行正常的
    初始化upstream list 的操作，而以集群的形式加入的nginx，则不会执行这段代码，
    增加了判断条件：如果redis当中有值的话，会默认跳过，不会覆盖，如果对于
    同一个title，在初始化文件当中保留的还是旧的server配置，而redis是新的
    server配置，就会导致信息出现问题，因此对于出现在初始化文件当中，
    但是也出现在了redis当中的tile，不会进行任何操作，没有的，会正常补集操作。     
]]

local redis         = require"resty.kerri.basic.redis_conn"
local ctc           = require"resty.kerri.basic.composite_tab_c"
local stt           = require"resty.kerri.basic.str_to_table"
local tts           = require"resty.kerri.basic.table_to_str"
local sec           = require"resty.kerri.basic.get_ngx_sec"
local du            = require"resty.kerri.upstream.dynamic_upstream"
local cj            = require"cjson"
local upstream_zone = ngx.shared['upstream_zone']
local state         = ngx.req.get_uri_args()["state"]
local config_path   = ngx.req.get_uri_args()["config_path"]
local json_file     = ngx.req.get_uri_args()["json_file"]
local python_file   = ngx.req.get_uri_args()["python_file"]
local python_cmd    = ngx.req.get_uri_args()["python_cmd"]
local delay         = ngx.req.get_uri_args()["delay"]
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local null          = ngx.null
local timer         = ngx.timer.at
local timers        = ngx.timer.every
local pairs         = pairs
local setmetatable  = setmetatable

--时钟0.01s
local function sleeper()
	ngx.sleep(0.01)
end

-- 判断redis是否连接
local function judge_redis()
    local _, res = 
    pcall(function() 
    local lepai = redis.redis_conn()
    -- 返回值为1 ，意味着redis连接失败
    if not lepai then
        redis.redis_close(lepai)
        return 1
    else
        redis.redis_close(lepai)
        return
    end 
    end)
    return res 
end

--获取配置文件
local function load_conf()
	--执行python脚本读取配置文件
	local python_format = 
	python_cmd..' '
	..config_path..'/'..python_file..' -c '
	..config_path..'/'..json_file..' > '
	..config_path..'/tmp_upstream_conf'
	local get_res = 'cat '
	..config_path..'/tmp_upstream_conf'
	local rm_res = 'mv '
	..config_path..'/tmp_upstream_conf /tmp'
	--将读取结果重定向到一个文件当中，因为直接获取结
    --果是行不通的，需要间接获得os.execute()只是执行
    --一个shell命令，返回结果只能是true或者false
	--执行结果并不会展示；
	--io.popen(),除了执行一个shell命令，还会把文件
    --句柄返回，也就是查看shell命令
	--执行后的结果;
	local cm = os.execute(python_format)
	if not cm then
		log(ERR, '[ ERR ]: '
		..'the init upstream conf route '
        ..'is WRONG ? ? ?'
		..' please check the shell: '..'\r\n'
		..python_format)
		return
	end
	sleeper()
	local the_res_conf = io.popen(get_res)
	local conf = the_res_conf:read()
	sleeper()
	local rm = io.popen(rm_res)
	--最终读取出来的配置文件 字符串
	return conf
end

-- 把读取到的配置文件写入dict
-- 有一个问题：在每次重启nginx，都会初始化配置，
-- 很明显，这个会把之前的配置冲掉，但是因为dict
-- 在重启以后信息都消失了，因此可以先初始化成这个配置，
-- 这也是在redis无法连接的情况下，但是当redis是在线的，
-- 那么这个问题就需要作出判断了。
local function persis_conf(conf)
    conf = cj.decode(conf)
    -- upstream list 获取和写入
    local _, upstream_list = 
    pcall(function() 
    local lepai = redis.redis_conn() 
    local redis_upstream_list = 
    lepai:get('upstream_list') 
    local _, redis_upstream_list = 
    pcall(function() 
    local redis_upstream_list = 
    stt.stt(redis_upstream_list) 
    return redis_upstream_list
    end)
    -- redis的upstream_list不为空，并且长度不为零，那么就对它
    -- 和conf取并集，并把没有的元素写入redis
    -- 有数据
    if redis_upstream_list 
    and #redis_upstream_list ~= 0 
    and state == 'uncover' then
        for title, title_body in pairs(conf) do
            local redis_title_body = lepai:get(title)
            if redis_title_body == null then
                local sec = sec.sec()
                title_body['timestamp'] = sec
                table.insert(redis_upstream_list, title)
                local title_body = cj.encode(title_body)
                lepai:set(title, title_body)
            end
        end
        redis.redis_close(lepai)
        return redis_upstream_list
    end
    end)
    -- 无数据
    -- 列表为空(redis宕机)
    -- state 为 cover
    local tab = {}
    if type(upstream_list) ~= 'table'
    or state == 'cover' 
    or state == 'uncover' then
        for title, title_body in pairs(conf) do
            local sec = sec.sec()
            table.insert(tab, title)
            title_body['timestamp'] = sec
            local title_body = cj.encode(title_body)
            upstream_zone:set(title, title_body)
        end
    end
    local upstream_list = 
    tts.tts(tab)
    local sec = sec.sec()
    upstream_zone:set('upstream_list', upstream_list)
    upstream_zone:set('upstream_list_update_time', sec)
    pcall(function()
        local lepai = redis.redis_conn()
        lepai:set('upstream_list', upstream_list)
        lepai:set('upstream_list_update_time', sec)
        redis.redis_close(lepai)
    end)
    log(INFO, '[ INFO ]: '
    ..'INIT UPSTREAM CONF TIMER :'
    ..'INIT UPSTREAM CONF SUCCESS ！！！')
end

local function persis_main()
    -- 判断nginx是否是第一次启动，因为这部分代码设计就是为了nginx
    if state ~= 'cover' 
    and state ~= 'uncover' then
        log(INFO, '[ INFO ]: '
        ..'INIT UPSTREAM CONF TIMER :'
        ..' DOWN ！！！')
        return
    end
    local _, cluster_state = 
    pcall(function()
    local lepai = redis.redis_conn()
    local cluster_state = lepai:get('cluster_state')
    if cluster_state ~= null then
        return cluster_state
    end
    end)
    if cluster_state 
    and pcall(function() 
    cj.decode(cluster_state) 
    end) then
        local cluster_state = 
        cj.decode(cluster_state)
        local sec = sec.sec()
        local cluster_timestamp = 
        cluster_state['cluster_timestamp']
        local node_num = 
        ctc.ctco(cluster_state['node'])
        if math.abs(sec - cluster_timestamp) <= 2 then
            -- 多节点，退出
            if node_num > 1 then
                log(INFO, '[ INFO ]: '
                ..'INIT UPSTREAM CONF TIMER :'
                ..'NODE NUMBER > 1 ！！！')
                return
            end 
        end 
    end
    local conf = load_conf()
    if not conf then
        log(ERR, '[ ERR ]: '
        ..'INIT UPSTREAM CONF TIMER :'
        ..'CANNOT get init upstream'
        ..' conf file ! ! !')
        return
    end
    log(INFO,'[ INFO ]: '
        ..'INIT UPSTREAM CONF TIMER :'
    ..'have get upstream conf file ！！！')
    persis_conf(conf)
end

timer(delay, persis_main)

