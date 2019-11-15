-- Copyright © (C) Zhendong (DDJ)
-- 动态负载均衡定时器，用来从dict当中将数据同步到redis
-- 更新日期
--	 2019.03.15 16:50
--
-- 单纯的数组：通过table_to_string来实现转换和存储
-- 复合型数组：通过encode将数组编码来实现转换和存储
--
-- 2019.03.26 09:54
--       对定时器部分进行检查，然后将数据同步的功能都集中在定时器部分，
--   明确功能划分。
--
-- 2019.04.01 09:51
--       这次更新的主要内容是解决多个nginx通过redis共享upstream list 
--   信息的时候，会出现的bug，因为我们设计的思想是：在任意一个nginx上
--   进行更新，可以通过redis同步到其他nginx上，逻辑上始终是“并集”的思路，
--   因此在black&white IP 定时器上使用了这种逻辑方式，并通过测试，认为
--   这样的逻辑是比之前更加严密，出错概率更低，因此dynamic upstream 定时器
--   也需要更新成这样的逻辑。详细参考black&white IP 定时器注释。
--       同样有个问题，这样的逻辑下，导致删除一个server，会因为触发定时器而把
--   删除的server同步回来，需要在在redis和dict端同时删除
--
-- 2019.04.02 10:21
--      今天发现一个bug，是关于之前设计的upstream list 的新逻辑，出现了redis没有更新
--   title_body的情况，最后检查是因为，代码参照了黑白名单的方式，没有注意到一点就是
--   在dict当中也可能出现redis没有的 tilte ，并且发现了这个title ，还要把它的body
--   写入redis，以达到同分布数据的目的。
--      还出现一个bug就是：当更新一个title以后，比如增加了多个server，但是由于上面设计
--   的原因，导致只能检测是否title对应的title_body是否存在，但是内部发生的变化，我们是
--   无法察觉的，也就是说这个是无法进行同步的，因为设计思路就是“补集”和“拒绝覆盖”
--
-- 2019.04.04 15:45
--      在今天开发关于状态同步定时器的时候，出现了一个逻辑上的漏洞，那就是对于一个nginx
--   新加入一个已有的nginx+redis体系当中的时候，在和时间戳做对比，发现无论怎么样，其实
--   新加入的nginx的时间戳无论从哪个方面比较，都是优于redis的，因此redis和另一个nginx在
--   通过定时器做互相更新的时候，是有时间间隔的，在间隔期间，新的nginx加入，在新nginx定时器
--   对时间戳做逻辑比较的时候，总是时间比redis当中的时间戳更新，因此会触发dict信息同步redis，
--   这显然违背了我们的初衷，我们希望新加入的nginx可以将redis的所有数据同步更新下来，而不是做
--   “补集”，毕竟加入一个新群体，就是要和他们形成一个统一的整体，而不是特立独行。因此这次更新
--   将通过标记为解决nignx自己判断是不是第一次连接nginx+redis群体
--
-- 2019.04.08 16:14
--      今天将“node heartbeat”定时器完成，每个nginx节点将在redis进程注册，最主要的还是通过redis
--  当中的key: “cluster_state”来获取“cluster_timestamp”时间戳，和当前时间做比对：如果误差不超过
--  2秒，且node节点只有一个，那么就认为当前nginx是集群的第一个nginx；如果误差不超过2秒，且node节点
--  多于1个，就认为当前nginx是以节点的方式加入集群，采用新的方式来同步信息。但是需要一个标记位
--  来标记是否存在：“刚开始两个nginx存在，但是一个宕机，另一个nginx还用原来的方式进行同步”或者
--  “单个nginx在后续定时器循环，出现一直采用新方式同步信息的bug”
--
-- 2019.04.10. 16:30
--      这次的更新主要是集中在(n)nginx+redis集群当中数据删除操作的信息同步，因为本身代码逻辑
--  是不支持删除的，因此需要另写代码来支持这个功能

local redis			= require"resty.kerri.basic.redis_conn"
local ctc           = require"resty.kerri.basic.composite_tab_c"
local stt			= require"resty.kerri.basic.str_to_table"
local tts           = require"resty.kerri.basic.table_to_str"
local sec			= require"resty.kerri.basic.get_ngx_sec"
local cj			= require "cjson"
local delay			= ngx.req.get_uri_args()["delay"]
local ups_zone      = ngx.shared['upstream_zone']
local log			= ngx.log
local INFO			= ngx.INFO
local ERR			= ngx.ERR
local null          = ngx.null
local timer         = ngx.timer.at
local timers        = ngx.timer.every
local pairs			= pairs
local setmetatable	= setmetatable

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
local function upstream_update(point)
    log(INFO, '[ INFO ]: '
    ..'DYNAMIC UPSTREAM POINT :'..point)
    if point == 2 then
        local _, points = 
        pcall(function() 
        local lepai = redis.redis_conn()
        local points = 
        lepai:get('DEL_upstream_point')
        if points ~= null then
             return 1
        end 
        redis.redis_close(lepai)
        end)
        if points then
            pcall(function()
            local lepai = redis.redis_conn()
            local redis_upstream_list = 
            lepai:get('upstream_list')
            local redis_upstream_list = 
            stt.stt(redis_upstream_list)
            local dict_upstream_list = 
            ups_zone:get('upstream_list')
            local dict_upstream_list = 
            stt.stt(dict_upstream_list)
            for num = 1, #dict_upstream_list do
                local res = 
                lepai:get(dict_upstream_list[num])
                if res == null then
                    ups_zone:delete(
                    dict_upstream_list[num]) 
                end
            end
            ups_zone:set('upstream_list', 
            tts.tts(redis_upstream_list))
            ups_zone:set(
            'upstream_list_update_time', 
            sec)
            local DEL_upstream_point = 
            lepai:get('DEL_upstream_point')
            if DEL_upstream_point ~= null then
                if tonumber(DEL_upstream_point) >= 2 then
                    lepai:set(
                    'DEL_upstream_point', 
                    DEL_upstream_point - 1)
                else
                    lepai:del('DEL_upstream_point')
                end 
            end 
            redis.redis_close(lepai)
            end)
            return
        end
    end
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
    local dict_upstream_list
    _, dict_upstream_list = 
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
    if not redis_upstream_list then
        local lepai = redis.redis_conn()
        if point == 2 then
            local sec = sec.sec()
            ups_zone:set(
            'upstream_list_update_time', sec)
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
                ups_zone:set(
                'upstream_list_update_time', sec)
                redis.redis_close(lepai)
                return
            end
            -- 写入redis，为确保准确性，还需要进行获取判断
            tab = {}
            for num  = 1, #dict_upstream_list do
                local title_body = 
                ups_zone:get(dict_upstream_list[num])
                if title_body then
                    local title_body = 
                    cj.decode(title_body)
                    local sec = sec.sec()
                    title_body['timestamp'] = sec
                    local title_body = cj.encode(title_body)
                    pcall(function() 
                    lepai:set(dict_upstream_list[num], title_body) 
                    end)
                    table.insert(tab, dict_upstream_list[num])
                end
            end
            local upstream_list = tts.tts(tab)
            local sec = sec.sec()
            ups_zone:set(
            'upstream_list_update_time', sec)
            ups_zone:set(
            'upstream_list', upstream_list)
            pcall(function() 
            lepai:set(
            'upstream_list_update_time', sec) 
            lepai:set(
            'upstream_list', upstream_list)
            redis.redis_close(lepai)
            end)
            return
        end
    end
    local redis_upstream_list
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
    local dict_upstream_list
    _, dict_upstream_list = 
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
        ..'DYNAMIC UPSTREAM TIMER: '
        ..'redis_upstream_list AND '
        ..'dict_upstream_list ALL NULL ！！！')
        return
    end
    -- 这个部分是很重要的，04.02的更新主要在这里的逻辑，
    -- 因为 upstream 不仅需要把不同的写入
    -- dict，还需要把dict当中redis没有的，写入redis，
    -- 但是这部分没有，导致出现问题。
    -- 更新dict
    for num = 1, #redis_upstream_list do
        local dict_title_body = 
        ups_zone:get(redis_upstream_list[num])
        local redis_title_body = 
        lepai:get(redis_upstream_list[num])
        local _, d_value = pcall(function() 
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
        ..'DYNAMIC UPSTREAM TIMER: '
        ..' DICT UPDATE [ '
        ..redis_upstream_list[num]..' ] '
        ..' DIFF value: ', d_value)
        return d_value 
        end)
        -- 更新body到dict，不更新upstream list
        -- 这里判断差值大小，通过正负来判断谁的数据更新
        -- d_value > 0: dict数据优于redis
        -- d_value < 0: redis数据优于dict
        if tonumber(d_value) >= 1 then
            local dict_title_body = 
            cj.decode(dict_title_body)
            local sec = sec.sec()
            dict_title_body['timestamp'] = 
            sec 
            local dict_title_body = 
            cj.encode(dict_title_body)
            lepai:set(
            redis_upstream_list[num], 
            dict_title_body)
        end 
        if tonumber(d_value) <= -1 then
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = 
            sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            ups_zone:set(
            redis_upstream_list[num], 
            redis_title_body)
        end
        -- dict可以不存在，但是必须redis存在
        if not dict_title_body 
        and redis_title_body ~= null then
            table.insert(
            dict_upstream_list, 
            redis_upstream_list[num])
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = 
            sec 
            local redis_title_body = 
            cj.encode(redis_title_body)
            ups_zone:set(
            redis_upstream_list[num], 
            redis_title_body)
            log(INFO, '[ INFO ]: '
            ..'DYNAMIC UPSTREAM TIMER: '
            ..' DICT UPDATE TITLE [ ',
            redis_upstream_list[num], ' ] ')
        end
    end
    -- 更新redis
    for num = 1, #dict_upstream_list do
        local dict_title_body = 
        ups_zone:get(dict_upstream_list[num])
        local redis_title_body = 
        lepai:get(dict_upstream_list[num])
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
        ..'DYNAMIC UPSTREAM TIMER: '
        ..' REDIS UPDATE ['
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
            lepai:set(
            dict_upstream_list[num], 
            dict_title_body)
        end
        if tonumber(d_value) <= -1 then
            local redis_title_body = 
            cj.decode(redis_title_body)
            local sec = sec.sec()
            redis_title_body['timestamp'] = sec
            local redis_title_body = 
            cj.encode(redis_title_body)
            ups_zone:set(
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
            lepai:set(
            dict_upstream_list[num], 
            dict_title_body)
            log(INFO, '[ INFO ]: '
            ..'DYNAMIC UPSTREAM TIMER: '
            ..' REDIS UPDATE TITLE [ ',
            dict_upstream_list[num], ' ] ')
        end
    end
    local upstream_list = 
    tts.tts(dict_upstream_list)
    local sec = sec.sec()
    ups_zone:set(
    'upstream_list_update_time', sec)
    ups_zone:set(
    'upstream_list', upstream_list)
    pcall(function() 
    lepai:set('upstream_list_update_time', sec) 
    lepai:set('upstream_list', upstream_list)
    redis.redis_close(lepai)
    end)
    if point == 1 then
        log(INFO, '[ INFO ]: '
        ..'DYNAMIC UPSTREAM TIMER: '
        ..' DICT ===> REDIS ！！！')
        return
    elseif point == 2 then
        log(INFO, '[ INFO ]: '
        ..'DYNAMIC UPSTREAM TIMER: '
        ..' REDIS ===> DICT ！！！')
    else
        log(INFO, '[ INFO ]: '
        ..'DYNAMIC UPSTREAM TIMER: '
        ..' DYNAMIC UPSTREAM INIT COMPLETE ！！！')
    end
end

-- 以加入node节点的方式同步信息（覆盖方式为主）
local function upstream_node()
    local lepai = redis.redis_conn()
    local upstream_list = 
    lepai:get('upstream_list') 
    if upstream_list == null then
        log(INFO, '[ INFO ]: '
        ..'DYNAMIC UPSTREAM TIMER: '
        ..' upstream list is NULL')
        return
    end
    local upstream_list = 
    stt.stt(upstream_list)
    for num = 1, #upstream_list do
        local title_body = 
        lepai:get(upstream_list[num])
        if title_body then
            local title_body = 
            cj.decode(title_body)
            local sec = sec.sec()
            title_body['timestamp'] = sec
            local title_body = cj.encode(title_body)
            ups_zone:set(
            upstream_list[num], title_body)
        end
    end
    local upstream_list = 
    tts.tts(upstream_list)
    local sec = sec.sec()
    ups_zone:set('upstream_list', 
    upstream_list)
    ups_zone:set(
    'upstream_list_update_time', sec)
    lepai:set(
    'upstream_list_update_time', sec)
    redis.redis_close(lepai)
    log(INFO, '[ INFO ]: '
    ..'DYNAMIC UPSTREAM TIMER: '
    ..' JOIN THE CLUSTER FIRST ！！！')
end

--定时器主函数
-- 1 dict ---> redis
-- 2 redis ---> dict
-- 3 once
local function dynamic_upstream()
	local res = judge_redis()
	if res then
        log(INFO, '[ INFO ]: '
        ..'DYNAMIC UPSTREAM TIMER: '
        ..'REDIS CANNOT CONNECT...'
        ..'. NO UPDATE ！！！')
		local sec = sec.sec()
		ups_zone:set(
        'upstream_list_update_time', sec)
        return
    end
	local lepai = redis.redis_conn()
    -- 判断nginx是否是第一次启动，因为这部分代码设计就是为了nginx
    -- 在第一次启动的时候进行判断执行，后面无需执行
    -- 这段代码执行的关键是两个参数来控制：
    -- first_up 是否存在
    -- node_num 是否大于1
    -- 需要两个同时满足
    local first_up = 
    ups_zone:get('first_up')
    if not first_up then
        local cluster_state = 
        lepai:get('cluster_state')
        if cluster_state then
            local cluster_state = 
            cj.decode(cluster_state)
            local sec = sec.sec()
            local cluster_timestamp = 
            cluster_state['cluster_timestamp']
            local node_num = ctc.ctco(cluster_state['node'])
            if math.abs(sec - cluster_timestamp) <= 2 then
                -- 以node的身份进入
                if node_num > 1 then
                    upstream_node()
                    ups_zone:set('first_up', 1)
                    return
                end
            end
        end
        ups_zone:set('first_up', 1)
    end
	local redis_sec = 
    lepai:get('upstream_list_update_time')
	local dict_sec = 
    ups_zone:get('upstream_list_update_time')
	local redis_sec = tonumber(redis_sec)
	local dict_sec = tonumber(dict_sec)
    local _, d_value, abs_d_value =
    pcall(function() 
    local d_value = redis_sec - dict_sec 
    local abs_d_value = math.abs(d_value)
    return d_value, abs_d_value
    end)
	if not dict_sec and 
    not redis_sec then
		log(INFO, '[ INFO ]: '
        ..'DYNAMIC UPSTREAM TIMER: '
		..'REDIS DICT ALL NULL'
		..'REDIS and DICT NO UPDATE ！！！')
	elseif not dict_sec then
        upstream_update(2)
	elseif not redis_sec then
        upstream_update(1)
	elseif 0 < d_value 
    and rate < d_value then
        upstream_update(2)
	elseif d_value < 0 
    and rate < abs_d_value then
        upstream_update(1)
	elseif 0 <= abs_d_value 
    and abs_d_value <= rate then
		log(INFO, '[ INFO ]: '
        ..'DYNAMIC UPSTREAM TIMER : '
		..'UPDATETIME DIFF: '..abs_d_value
		..' < '..' threshold: '..rate
		..', REDIS and DICT NO UPDATE ！！！')
	else
		log(INFO, '[ INFO ]: '
		..'DYNAMIC UPSTREAM TIMER ERROR ！！！')
	end
	pcall(function() 
    redis.redis_close(lepai) 
    end)	
end 

timer(2, dynamic_upstream)
timers(delay, dynamic_upstream)

