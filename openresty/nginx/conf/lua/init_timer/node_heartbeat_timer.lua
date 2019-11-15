-- Copyright © (C) Zhendong (DDJ)
-- 节点心跳状态同步定时器
-- 更新日期
--   2019.04.08 09:51
--          说明：在这个日期前面开发的定时器，其实都是针对一个nginx+redis的组合，
--      而对于多个nginx+redis的组合，其实这个定时器是由bug的，我的设计初衷是：“希望
--      (n)nginx+redis可以通过redis作为中介来传递保存数据，例如通过任意一个nginx
--      更新了upstream list的数据可以以定时器的方式通过redis将更新信息传递到其他
--      nginx，保证整个nginx集群的信息同步”。但是由于先设计的单个nginx+redis的程序
--      逻辑，其中有一条就是对比upstream list当中单个upstream的时间戳，来判断那个
--      upstream是否变化，因为可能会更新server等信息。假设当前nginx准备加入一个已经
--      创建好的nginx+redis集群，当前nginx会在启动的时候将所有时间戳进行更新，然后
--      定时器开始工作，其中有条逻辑就是：“判断redis和nginx当中的upstream时间戳，
--      谁的时间戳更新，那么就将它存在的数据更新到另一方，但是由于原先nginx+redis的
--      定时器是存在时间差的，也就是说当新的nginx进行时间戳比对的时候，发现有可能
--      总是新nginx的时间戳更新，因为redis时间戳总是落后它一步，那么就导致新nginx
--      的upstream信息被更新到redis，从而由更新到原来的nginx”。这显然是不符合我的设计
--      预期的，可以说明的是：之前设计的逻辑适用于nginx加入redis已经稳定后，
--      数据交换的规则，但是并不适用于nginx刚刚加入redis的情况。

local redis         = require"resty.kerri.basic.redis_conn"
local ctc           = require"resty.kerri.basic.composite_tab_c"
local stt           = require"resty.kerri.basic.str_to_table"
local tts           = require"resty.kerri.basic.table_to_str"
local sec           = require"resty.kerri.basic.get_ngx_sec"
local cj            = require "cjson"
local delay         = ngx.req.get_uri_args()["delay"]
local node          = ngx.req.get_uri_args()["node"]
local ups_zone      = ngx.shared['upstream_zone']
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local null          = ngx.null
local timer         = ngx.timer.at
local timers        = ngx.timer.every
local pairs         = pairs
local setmetatable  = setmetatable

--[[

cluster_state = {
    cluster_timestamp = "191315649",        每秒进行更新
    update_node = "nginx_01",               同一时间只由一个nginx进行更新
    node = {                               注册进来的节点（存亡通过“cluster_timestamp”时间戳判断）
            "nginx_01" = "195646156",
            "nginx_02" = "192318631"
            }
    }

]]

--local node = "nginx_01"

local cluster_state_module = {
    cluster_timestamp = "timestamp", 
    update_node = "node", 
    node = {}
    }

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

local function heartbeat()
    local res = judge_redis()
    if res then
        log(INFO, '[ INFO ]: '
        ..'REDIS NOT CONNECT, HEARTBEAT PASS ！！！')
        return
    end
    local lepai = redis.redis_conn()
    local cluster_state = 
    lepai:get('cluster_state')
    -- 不存在，说明它是第一个
    if cluster_state == null then
        local sec = sec.sec()
        cluster_state_module['cluster_timestamp'] = sec
        cluster_state_module['update_node'] = node
        cluster_state_module['node'][node] = sec
        local cluster_state = 
        cj.encode(cluster_state_module)
        lepai:set(
        'cluster_state', 
        cluster_state)
        return
    end
    local cluster_state = 
    cj.decode(cluster_state)
    -- 判断当前nginx是否为更新时间戳的nginx
    -- 当前nginx节点是更新时间戳节点
    local tab
    if cluster_state['update_node'] == node then
        local sec = sec.sec()
        cluster_state['cluster_timestamp'] = sec
        cluster_state['node'][node] = sec
        tab = {}
        -- 将貌似离群的node剔除
        for nodes, timestamp in pairs(cluster_state['node']) do
            if math.abs(timestamp - sec ) <= 4 then
                tab[nodes] = timestamp
            else
                log(INFO, '[ INFO ]: '
                ..' NODE: [ '..nodes
                ..' ] MABEY LEAVE ！！！')
            end 
        end
        cluster_state['node'] = tab
        local cluster_state = 
        cj.encode(cluster_state)
        lepai:set('cluster_state', 
        cluster_state)
    -- 为普通节点
    else
        local sec = sec.sec()
        local diff = 
        math.abs(sec - cluster_state['cluster_timestamp'])
        -- 判断作为更新时间戳的nginx是否挂了，如果挂了，需要当前nginx开始更新
        -- 也用来将第一次启动nginx，以前残留的key进行筛选
        if diff > 8 then
            --local sec = sec.sec()
            log(INFO, '[ INFO ]: '
            ..'NODE: [ '..node
            ..' ] BECOME THE MASTER ！！！')
            cluster_state['cluster_timestamp'] = sec 
            cluster_state['update_node'] = node
            cluster_state['node'][node] = sec 
            local cluster_state = 
            cj.encode(cluster_state)
            lepai:set('cluster_state', 
            cluster_state)
            return
        end
        cluster_state['node'][node] = sec
        local cluster_state = 
        cj.encode(cluster_state)
        lepai:set('cluster_state', 
        cluster_state)
    end
end

--heartbeat()
timer(0, heartbeat)
timers(delay, heartbeat)

