-- Copyright © (C) Zhendong (DDJ)
-- healthcheck&location状态同步定时器
--
-- 更新日期
--   2019.04.04 10:35
--          “healthcheck&location状态同步定时器”的定位和“init_dynamic_upstream_timer”
--      定时器类似，都是通过时间戳来同步upstream list具体的body信息，因为存在模板和参数
--      这里将完全参照它的写法来复制。
--
--   2019.04.09 09:17
--          上个星期对定时器的开发暂时停滞，因为对于(n)nginx+redis会出现信息同步bug，
--      具体问题可以看“dynamic_upstream_timer”的更新日志，在问题解决以后，这个定时器终于
--      也可以进行开发了，因为在这个定时器当中healthcheck模板信息同步本质和upstream list
--      同步没有什么区别，location的同步仿照white IP的方式。
--   
--   2019.04.10 17:46
--          现在已经解决了几乎发现的所有的关于定时器的问题，可以开始开发location wip 信息
--      同步功能了

local redis         = require"resty.lepai.basic.redis_conn"
local ctc           = require"resty.lepai.basic.composite_tab_c"
local stt           = require"resty.lepai.basic.str_to_table"
local tts           = require"resty.lepai.basic.table_to_str"
local sec           = require"resty.lepai.basic.get_ngx_sec"
local cj            = require "cjson"
local delay         = ngx.req.get_uri_args()["delay"]
local ups_zone      = ngx.shared['upstream_zone']
local hc_zone       = ngx.shared['healthcheck_zone']
local wip_zone      = ngx.shared['white_ip_zone']
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local null          = ngx.null
local thread        = ngx.thread.spawn
local timer         = ngx.timer.at
local timers        = ngx.timer.every
local pairs         = pairs
local setmetatable  = setmetatable

-- 阈值修改，如果超过规定就是按照2.5秒的差值为更新
local _, rate = 
pcall(function()
    if 2 <= tonumber(delay) / 2 
    and tonumber(delay) / 2 <= 4 then
        return tonumber(delay) / 2 
    end 
    return 3
end)

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

-- 处理函数
-- 1 dict ---> redis
-- 2 redis ---> dict
-- 3 once
-- 这里会有一个upstream list
local function healthcheck_update(point)
    log(INFO, '[ INFO ]: '
    ..'HEALTHCHECK STATE SYNC POINT :'..point)
    local redis_upstream_list
    _, redis_upstream_list =
    pcall(function()
    local lepai = redis.redis_conn()
    local redis_upstream_list = 
    lepai:get('upstream_list')
    if redis_upstream_list ~= null 
    and #redis_upstream_list ~= 0 then
        return redis_upstream_list
    else
        return
    end
    end)
    local _, dict_upstream_list =
    pcall(function()
    local dict_upstream_list = 
    ups_zone:get('upstream_list')
    if dict_upstream_list 
    and #dict_upstream_list ~= 0 then
        return dict_upstream_list
    else
        return
    end
    end)
    -- redis的 upstream list 为空
    local lepai = redis.redis_conn()
    if not redis_upstream_list then
        if point == 2 then
            local sec = sec.sec()
            hc_zone:set(
            'hc_upstream_list_update_time', 
            sec)
            pcall(function() 
            redis.redis_close(lepai) 
            end)
            return
        else
            local dict_upstream_list = 
            stt.stt(dict_upstream_list)
            if #dict_upstream_list == 0 
            or not dict_upstream_list then
                local sec = sec.sec()
                hc_zone:set(
                'hc_upstream_list_update_time', 
                sec)
                redis.redis_close(lepai)
                return
            end
            -- 写入redis，为确保准确性，还需要进行获取判断
            for num  = 1, #dict_upstream_list do
                local hc_body = 
                hc_zone:get(
                dict_upstream_list[num])
                if hc_body then
                    local hc_body = 
                    cj.decode(hc_body)
                    local sec = sec.sec()
                    hc_body['timestamp'] = sec
                    local hc_body = 
                    cj.encode(hc_body)
                    pcall(function() 
                    lepai:set('hc_'
                    ..dict_upstream_list[num], 
                    title_body) 
                    end)
                end
            end
            local sec = sec.sec()
            hc_zone:set(
            'hc_upstream_list_update_time', sec)
            pcall(function() 
            lepai:set(
            'hc_upstream_list_update_time', sec) 
            redis.redis_close(lepai)
            end)
            return
        end
    end
    _, redis_upstream_list =
    pcall(function()
    if redis_upstream_list then
        redis_upstream_list = 
        stt.stt(redis_upstream_list)
        return redis_upstream_list
    else
        return {}
    end
    end)
    local _, dict_upstream_list =
    pcall(function()
    if dict_upstream_list then
        dict_upstream_list = 
        stt.stt(dict_upstream_list)
        return dict_upstream_list
    else
        return {}
    end
    end)
    if #redis_upstream_list == 0 
    and #dict_upstream_list ==0 then
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..'redis_upstream_list AND '
        ..'dict_upstream_list ALL NULL ！！！')
        return
    end
    -- 更新dict
    for num = 1, #redis_upstream_list do
        local dict_title_body = 
        hc_zone:get(
        redis_upstream_list[num])
        local redis_title_body = 
        lepai:get(
        'hc_'..redis_upstream_list[num])
        local _, d_value = 
        pcall(function()
        if not dict_title_body 
        or redis_title_body == null then
            return 0
        end
        local dict_title_body = 
        cj.decode(dict_title_body)
        local dict_timestamp = 
        dict_title_body['timestamp']
        local redis_title_body = 
        cj.decode(redis_title_body)
        local redis_timestamp = 
        redis_title_body['timestamp']
        local d_value = 
        dict_timestamp - redis_timestamp
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..' DICT UPDATE [ '
        ..redis_upstream_list[num]..' ] '
        ..' DIFF value: ', d_value)
        return d_value
        end)
        if tonumber(d_value) >= 1 then
            local dict_title_body = 
            cj.decode(dict_title_body)
            local sec = sec.sec()
            dict_title_body['timestamp'] = sec
            local dict_title_body = 
            cj.encode(dict_title_body)
            lepai:set('hc_'
            ..redis_upstream_list[num], 
            dict_title_body)
        end
        if tonumber(d_value) <= -1 then
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            hc_zone:set(
            redis_upstream_list[num], 
            redis_title_body)
        end
        -- dict可以不存在，但是必须redis存在
        if not dict_title_body 
        and redis_title_body ~= null then
            table.insert(dict_upstream_list, 
            redis_upstream_list[num])
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            hc_zone:set(redis_upstream_list[num], 
            redis_title_body)
            log(INFO, '[ INFO ]: '
            ..'HEALTHCHECK STATE SYNC TIMER: '
            ..' DICT UPDATE TITLE [ ',
            redis_upstream_list[num], ' ] ')
        end
    end
    -- 更新redis
    for num = 1, #dict_upstream_list do
        local dict_title_body = 
        hc_zone:get(dict_upstream_list[num])
        local redis_title_body = 
        lepai:get('hc_'
        ..dict_upstream_list[num])
        local _, d_value = pcall(function()
        if redis_title_body == null 
        or not dict_title_body then
            return 0
        end
        local dict_title_body = 
        cj.decode(dict_title_body)
        local dict_timestamp = 
        dict_title_body['timestamp']
        local redis_title_body = 
        cj.decode(redis_title_body)
        local redis_timestamp = 
        redis_title_body['timestamp']
        local d_value = 
        dict_timestamp - redis_timestamp
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..' REDIS UPDATE [ '
        ..dict_upstream_list[num]..']'
        ..' DIFF value: ', d_value)
        return d_value
        end)
        if tonumber(d_value) >= 1 then
            local dict_title_body = 
            cj.decode(dict_title_body)
            local sec = sec.sec()
            dict_title_body['timestamp'] = sec
            local dict_title_body = 
            cj.encode(dict_title_body)
            lepai:set('hc_'
            ..dict_upstream_list[num], 
            dict_title_body)
        end
        if tonumber(d_value) <= -1 then
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            hc_zone:set(
            redis_upstream_list[num], 
            redis_title_body)
        end
        if redis_title_body == null 
        and dict_title_body then
            local dict_title_body = 
            cj.decode(dict_title_body)
            local sec = sec.sec()
            dict_title_body['timestamp'] = sec
            local dict_title_body = 
            cj.encode(dict_title_body)
            lepai:set('hc_'
            ..dict_upstream_list[num], 
            dict_title_body)
            log(INFO, '[ INFO ]: '
            ..'HEALTHCHECK STATE SYNC TIMER: '
            ..' REDIS UPDATE TITLE [ ',
            dict_upstream_list[num], ' ] ')
        end
    end
    local sec = sec.sec()
    hc_zone:set(
    'hc_upstream_list_update_time', 
    sec)
    pcall(function() 
    lepai:set(
    'hc_upstream_list_update_time', 
    sec) 
    redis.redis_close(lepai)
    end)
    if point == 1 then
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..' DICT ===> REDIS ！！！')
        return
    elseif point == 2 then
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..' REDIS ===> DICT ！！！')
    else
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..' HEALTHCHECK STATE SYNC COMPLETE ！！！')
    end
end

-- wip location 定时器
local function location_update(point)
    log(INFO, '[ INFO ]: '
    ..'DYNAMIC UPSTREAM POINT :'..point)
    local _, redis_domain_list =
    pcall(function()
    local lepai = redis.redis_conn()
    local redis_domain_list = 
    lepai:get('domain_list')
    if redis_domain_list ~= null 
    and #redis_domain_list ~= 0 then
        return redis_domain_list
    else
        return
    end
    end)
    local _, dict_domain_list =
    pcall(function()
    local dict_domain_list = 
    wip_zone:get('domain_list')
    if dict_domain_list 
    and #dict_domain_list ~= 0 then
        return dict_domain_list
    else
        return
    end
    end)
    -- redis的 domain list 为空
    local lepai = redis.redis_conn()
    if not redis_domain_list then
        if point == 2 then
            local sec = sec.sec()
            wip_zone:set(
            'domain_list_update_time', 
            sec)
            pcall(function() 
            redis.redis_close(lepai) 
            end)
            return
        else
            local dict_domain_list = 
            stt.stt(dict_domain_list)
            if #dict_domain_list == 0 
            or not dict_domain_list then
                local sec = sec.sec()
                wip_zone:set(
                'domain_list_update_time', 
                sec)
                redis.redis_close(lepai)
                return
            end
            -- 写入redis，为确保准确性，还需要进行获取判断
            tab = {}
            for num  = 1, #dict_domain_list do
                local lc_body = 
                wip_zone:get(dict_domain_list[num])
                if lc_body then
                    local lc_body = 
                    cj.decode(lc_body)
                    local sec = sec.sec()
                    lc_body['timestamp'] = sec
                    local lc_body = 
                    cj.encode(lc_body)
                    pcall(function() 
                    lepai:set('lc_'
                    ..dict_domain_list[num], 
                    title_body) 
                    end)
                    table.insert(tab, 
                    dict_domain_list[num])
                end
            end
            local domain_list = 
            tts.tts(tab)
            local sec = sec.sec()
            wip_zone:set(
            'domain_list_update_time', 
            sec)
            wip_zone:set('domain_list', 
            domain_list)
            pcall(function() 
            lepai:set(
            'domain_list_update_time', 
            sec) 
            lepai:set('domain_list', 
            domain_list)
            redis.redis_close(lepai)
            end)
            return
        end
    end
    local _, redis_domain_list =
    pcall(function()
    if redis_domain_list then
        local redis_domain_list = 
        stt.stt(redis_domain_list)
        return redis_domain_list
    else
        return {}
    end
    end)
    local _, dict_domain_list =
    pcall(function()
    if dict_domain_list then
        dict_domain_list = 
        stt.stt(dict_domain_list)
        return dict_domain_list
    else
        return {}
    end
    end)
    if #redis_domain_list == 0 
    and #dict_domain_list ==0 then
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..'redis_domain_list AND '
        ..'dict_domain_list ALL NULL ！！！')
        return
    end
    -- 更新dict
    for num = 1, #redis_domain_list do
        local dict_title_body = 
        wip_zone:get(redis_domain_list[num])
        local redis_title_body = 
        lepai:get('lc_'
        ..redis_domain_list[num])
        local _, d_value = 
        pcall(function()
        if not dict_title_body 
        or redis_title_body == null then
            return 0
        end
        local dict_title_body = 
        cj.decode(dict_title_body)
        local dict_timestamp = 
        dict_title_body['timestamp']
        local redis_title_body = 
        cj.decode(redis_title_body)
        local redis_timestamp = 
        redis_title_body['timestamp']
        local d_value = 
        dict_timestamp - redis_timestamp
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..' DICT UPDATE [ '
        ..redis_domain_list[num]..' ] '
        ..' DIFF value: ', d_value)
        return d_value
        end)
        if tonumber(d_value) >= 1 then
            local dict_title_body = 
            cj.decode(dict_title_body)
            local sec = sec.sec()
            dict_title_body['timestamp'] = sec
            local dict_title_body = 
            cj.encode(dict_title_body)
            lepai:set('lc_'
            ..redis_domain_list[num], 
            dict_title_body)
        end
        if tonumber(d_value) <= -1 then
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            wip_zone:set(
            redis_domain_list[num], 
            redis_title_body)
        end
        -- dict可以不存在，但是必须redis存在
        if not dict_title_body 
        and redis_title_body ~= null then
            table.insert(
            dict_domain_list, 
            redis_domain_list[num])
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            wip_zone:set(
            redis_domain_list[num], 
            redis_title_body)
            log(INFO, '[ INFO ]: '
            ..'LOCATION STATE SYNC TIMER: '
            ..' DICT UPDATE TITLE [ ',
            redis_domain_list[num], ' ] ')
        end
    end
    -- 更新redis
    for num = 1, #dict_domain_list do
        local dict_title_body = 
        wip_zone:get(
        dict_domain_list[num])
        local redis_title_body = 
        lepai:get('lc_'..dict_domain_list[num])
        local _, d_value = pcall(function()
        if redis_title_body == null 
        or not dict_title_body then
            return 0
        end
        local dict_title_body = 
        cj.decode(dict_title_body)
        local dict_timestamp = 
        dict_title_body['timestamp']
        local redis_title_body = 
        cj.decode(redis_title_body)
        local redis_timestamp = 
        redis_title_body['timestamp']
        local d_value = 
        dict_timestamp - redis_timestamp
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..' REDIS UPDATE [ '
        ..dict_domain_list[num]..']'
        ..' DIFF value: ', d_value)
        return d_value
        end)
        if tonumber(d_value) >= 1 then
            local dict_title_body = 
            cj.decode(dict_title_body)
            local sec = sec.sec()
            dict_title_body['timestamp'] = sec
            local dict_title_body = 
            cj.encode(dict_title_body)
            lepai:set('lc_'
            ..dict_domain_list[num], 
            dict_title_body)
        end
        if tonumber(d_value) <= -1 then
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            wip_zone:set(
            redis_domain_list[num], 
            redis_title_body)
        end
        if redis_title_body == null 
        and dict_title_body then
            local dict_title_body = 
            cj.decode(dict_title_body)
            local sec = sec.sec()
            dict_title_body['timestamp'] = sec
            local dict_title_body = 
            cj.encode(dict_title_body)
            lepai:set('lc_'
            ..dict_domain_list[num], 
            dict_title_body)
            log(INFO, '[ INFO ]: '
            ..'LOCATION STATE SYNC TIMER: '
            ..' REDIS UPDATE TITLE [ ',
            dict_domain_list[num], ' ] ')
        end
    end
    local domain_list = 
    tts.tts(dict_domain_list)
    local sec = sec.sec()
    wip_zone:set(
    'domain_list_update_time', sec)
    wip_zone:set(
   'domain_list', domain_list)
    pcall(function() 
    lepai:set(
    'domain_list_update_time', sec) 
    lepai:set(
    'domain_list', domain_list)
    redis.redis_close(lepai)
    end)
    if point == 1 then
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..' DICT ===> REDIS ！！！')
        return
    elseif point == 2 then
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..' REDIS ===> DICT ！！！')
    else
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..' LOCATION STATE SYNC COMPLETE ！！！')
    end
end

-- 针对加入nginx+redis节点，执行下列函数
local function state_sync_node()
    local lepai = redis.redis_conn()
    local upstream_list = 
    lepai:get('upstream_list')
    if upstream_list == null then
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..' upstream list is NULL')
        return
    end
    local upstream_list = 
    stt.stt(upstream_list)
    for num = 1, #upstream_list do
        local title_body = 
        lepai:get('hc_'
        ..upstream_list[num])
        if title_body ~= null then
            local title_body = 
            cj.decode(title_body)
            local sec = sec.sec()
            title_body['timestamp'] = sec
            local title_body = 
            cj.encode(title_body)
            hc_zone:set(
            upstream_list[num], 
            title_body)
        end
    end
    local upstream_list = 
    tts.tts(upstream_list)
    local sec = sec.sec()
    hc_zone:set(
    'hc_upstream_list_update_time', sec)
    lepai:set(
    'hc_upstream_list_update_time', sec)
    redis.redis_close(lepai)
    log(INFO, '[ INFO ]: '
    ..'HEALTHCHECK STATE SYNC TIMER: '
    ..' JOIN THE CLUSTER FIRST ！！！')
end

--定时器主函数
-- 1 dict ---> redis
-- 2 redis ---> dict
-- 3 once
local function healthcheck_state_sync()
    local res = judge_redis()
    if res then
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..'REDIS CANNOT CONNECT..'
        ..'.. NO UPDATE ！！！')
        local sec = sec.sec()
        hc_zone:set(
        'hc_upstream_list_update_time', sec)
        return
    end
    local lepai = redis.redis_conn()
    local first_up = 
    hc_zone:get('first_up')
    if not first_up then
        local cluster_state = 
        lepai:get('cluster_state')
        if cluster_state then
            local cluster_state = 
            cj.decode(cluster_state)
            local sec = sec.sec()
            local cluster_timestamp = 
            cluster_state['cluster_timestamp']
            local node_num = 
            ctc.ctco(cluster_state['node'])
            if math.abs(sec - cluster_timestamp) <= 2 then
                -- 以node的身份进入
                if node_num > 1 then
                    state_sync_node()
                    hc_zone:set('first_up', 1)
                    return
                end 
            end 
        end 
        hc_zone:set('first_up', 1)
    end
    local redis_sec = 
    lepai:get('hc_upstream_list_update_time')
    local dict_sec = 
    hc_zone:get('hc_upstream_list_update_time')
    local redis_sec = tonumber(redis_sec)
    local dict_sec = tonumber(dict_sec)
    local _, d_value, abs_d_value =
    pcall(function() 
    local d_value = redis_sec - dict_sec 
    local abs_d_value = math.abs(d_value)
    return d_value, abs_d_value
    end)
    if not dict_sec 
    and not redis_sec then
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..'REDIS DICT ALL NULL'
        ..'REDIS and DICT NO UPDATE ！！！')
    elseif not dict_sec then
        healthcheck_update(2)
    elseif not redis_sec then
        healthcheck_update(1)
    elseif 0 < d_value 
    and rate < d_value then
        healthcheck_update(2)
    elseif d_value < 0 
    and rate < abs_d_value then
        healthcheck_update(1)
    elseif 0 <= abs_d_value 
    and abs_d_value <= rate then
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER: '
        ..'UPDATETIME DIFF: '..abs_d_value
        ..' < '..' threshold: '..rate
        ..', REDIS and DICT NO UPDATE ！！！')
    else
        log(INFO, '[ INFO ]: '
        ..'HEALTHCHECK STATE SYNC TIMER ERROR ！！！')
    end
    pcall(function() 
    redis.redis_close(lepai) 
    end)
end

local function location_state_sync()
    local res = judge_redis()
    --redis无法连接 
    if res then
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..'REDIS CANNOT CONNECT..'
        ..'.. NO UPDATE ！！！')
        local sec = sec.sec()
        wip_zone:set(
        'domain_list_update_time', sec)
        return 
    --redis正常
    end 
    local lepai = redis.redis_conn()
    local redis_sec = 
    lepai:get('domain_list_update_time')
    local dict_sec = 
    wip_zone:get('domain_list_update_time')
    -- 测试
    local redis_sec = tonumber(redis_sec)
    local dict_sec = tonumber(dict_sec)
    --计算差值
    local _, d_value, abs_d_value =
    pcall(function() 
    local d_value = redis_sec - dict_sec 
    local abs_d_value = math.abs(d_value)
    return d_value, abs_d_value
    end)
    if not dict_sec 
    and not redis_sec then
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '    
        ..'REDIS DICT ALL NULL'
        ..'REDIS and DICT NO UPDATE ！！！')
    elseif not dict_sec then
        location_update(2)
    elseif not redis_sec then
        location_update(1)
    elseif 0 < d_value 
    and rate < d_value then
        location_update(2)
    elseif d_value < 0 
    and abs_d_value > rate then
        location_update(1)
    elseif abs_d_value >= 0 
    and abs_d_value <= rate then
        log(INFO, '[ INFO ]: '
        ..'LOCATION STATE SYNC TIMER: '
        ..'UPDATETIME DIFF: '..abs_d_value
        ..' < '..' threshold: '..rate
        ..', REDIS and DICT NO UPDATE ！！！')
    else
        log(ERR, '[ ERR ]: '
        ..'LOCATION STATE SYNC TIMER ERROR ！！！')
    end
    pcall(function() 
    redis.redis_close(lepai) 
    end)
end

local function state_sync()
    healthcheck_state_sync()
    location_state_sync()
end

timer(2, state_sync)
timers(delay, state_sync)

