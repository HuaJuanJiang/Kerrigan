--[[ Copyright © (C) Zhendong (DDJ)
黑白名单定时器，定期将redis当中的数据同步到dict，但是也为防止redis数据过旧,
所以还通过dict同步数据到redis，进行反向更新，类似upstream定时器的配置
  最近更新：2019.03.11
    2019.03.15 16:15
	        取消了redis实时更新数据的需求dict为主，只在初期通过定时器把redis更新到dict

    2019.03.21 11:28
            增加在定时器初始化的时候可以指定white ip 白名单列表做为初始化到dict当中
    
    2019.03.28 09:39
            在对于多个nginx的时候，在另一个定时器初始化的时候，会把日志当中的所有非法请求ip
        全部读到dict当中，并且需要注意的是，不同的nginx有不同的ip，而黑名单要求的是求多个
        nginx黑名单的并集，因此执行逻辑做出大的修改，主要针对黑名单
    
    2019.03.29 10:24
            在今天出现的bug当中，当redis未连接的时候，会导致白名单初始化ip的逻辑无法执行，
        所以虽然现在已经把redis连接在外部进行了判断，但是还会导致问题的出现，现在尝试取消
        redis的连接判断，通过pcall错误处理的方式来优化逻辑
            在今天出现的一个奇怪的bug打在日志当中，这个错误之前是我没有注意过的，在建康检查
        的过程当中，在无法连接一组server的ip:port的时候，nginx会尝试三次，也就是打印出三行
        一模一样的日志：“*236 connect() failed (111: Connection refused)”，这个其实是redis
        的无法连接时的日志，但是这个的出现也和我代码设计的逻辑有关系，因为我去掉了关于redis
        是否连接的前期判断，而是直接通过pcall错误处理的方式来直接连接redis，即使redis宕机，
        使得代码不报错，但是会打印出上述日志。
    
    2019.04.10 10:47
            昨天和今天更新的集群的删除功能，因为代码设计的原因导致了删除功能会出现在集群当中
        无法同步到其他nginx，而这次针对定时器的再次更新主要解决这个问题，用到了redis当中的标记位
        做标识来让其他连着的nginx可以同步删除信息。

]]
local redis			= require"resty.kerri.basic.redis_conn"
local stt			= require"resty.kerri.basic.str_to_table"
local tts			= require"resty.kerri.basic.table_to_str"
local sec			= require"resty.kerri.basic.get_ngx_sec"
local ji            = require"resty.kerri.basic.judge_ip"
local convert       = require"resty.kerri.basic.ip_converter"
local cj			= require "cjson"
local delay			= ngx.req.get_uri_args()["delay"]
local iwip_str		= ngx.req.get_uri_args()["iwip_str"]
local wip_zone		= ngx.shared['white_ip_zone']
local bip_zone		= ngx.shared['black_ip_zone']
local log			= ngx.log
local INFO			= ngx.INFO
local ERR			= ngx.ERR
local null          = ngx.null
local timer         = ngx.timer.at
local timers        = ngx.timer.every
local pairs			= pairs
local setmetatable	= setmetatable
local exptime_hour	= 8
local exptime		= 3600 * exptime_hour 

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

-- white: 从redis当中取出数据覆盖到dict (redis一定是正常的)
-- white: 从dict当中取出数据覆盖到redis
-- 不需要判断redis的wip_list是否为空值，因为是没有必要的
-- once white
-- white: 只在nginx启动时执行一次，目的在于将redis列表中ip
-- 作为key 先写入dict
-- 1 dict ---> redis
-- 2 redis ---> dict
-- 3 once
-- 由于出现redis判断出现问题，因此需要在后面进行判断
local function white_ip_update(point)
    log(INFO, '[ INFO ]: '
    ..'WHITE POINT :'..point)
    if point == 3 then
        local iwip_tab = convert.decode(iwip_str, '-')
        local iwip_str = tts.tts(iwip_tab)
        -- 防止空值
        if #iwip_tab == 0 then
            if iwip_tab[1] == '' then
                iwip_tab = {'127.0.0.1'}
            end
        end 
        local dict_wip_list
        dict_wip_list = wip_zone:get('wip_list')
        pcall(function() 
        dict_wip_list = stt.stt(dict_wip_list) 
        end)
        if not dict_wip_list then
            dict_wip_list = {}
        end
        -- 将合格ip放入table当中
        -- 将初始化ip添加到wip_list
        -- 需要假设wip list 当中是有值的
        for num = 1, #iwip_tab do
            local res_ji = ji.ji_for_other(iwip_tab[num])
            local res = wip_zone:get(iwip_tab[num])
            if not res_ji and iwip_tab[num] 
            or not res then
                local sec = sec.sec()
                wip_zone:set(iwip_tab[num], sec)
                table.insert(dict_wip_list, iwip_tab[num])
            end
        end
    else
        -- 通过设置标记位，来引导其他连接redis的nginx通过删除原来
        -- 信息的方式来同步信息，因为由于前面“并集”逻辑设计的问题
        -- 导致删除信息的功=功能会出现问题
        if point == 2 then
            local _, points = 
            pcall(function() 
            local lepai = redis.redis_conn()
            local points = 
            lepai:get('DEL_wip_point')
            if points ~= null then
                 return 1
            end
            redis.redis_close(lepai)
            end)
            if points then
                pcall(function() 
                local lepai = redis.redis_conn()
                local redis_wip_list = lepai:get('wip_list')
                local redis_wip_list = stt.stt(redis_wip_list)
                local dict_wip_list  = wip_zone:get('wip_list')
                local dict_wip_list  = stt.stt(dict_wip_list)
                for num = 1, #dict_wip_list do
                    wip_zone:delete(dict_wip_list[num])
                end
                local sec = sec.sec()
                for num = 1, #redis_wip_list do
                    wip_zone:set(redis_wip_list[num], sec)
                end
                wip_zone:set('wip_list', tts.tts(redis_wip_list))
                wip_zone:set('wip_list_update_time', sec)
                local DEL_wip_point = lepai:get('DEL_wip_point')
                if DEL_wip_point ~= null then
                    if tonumber(DEL_wip_point) >= 2 then
                        lepai:set('DEL_wip_point', DEL_wip_point - 1)
                    else
                        lepai:del('DEL_wip_point')
                    end
                end
                redis.redis_close(lepai)
                end)
                return
            end
        end
        -- 在另外两种情况下，直接获取表，没有初始化ip
        local _, dict_wip_list =
        pcall(function()
        local dict_wip_list = wip_zone:get('wip_list')
        return stt.stt(dict_wip_list)
        end)
        if not dict_wip_list then
            dict_wip_list = {}
        end
    end
    local _, wip_list = 
    pcall(function() 
    lepai = redis.redis_conn() 
    local wip_list = lepai:get('wip_list')
    return wip_list
    end)
    -- 这里需要做一个判断，比较复杂，就是redis是连接的，但是wip list
    -- 对应的key是null，在这种情况下，1、2、3 受到这个的影响是不同的，
    -- 2:“redis ---> dict” 是需要redis一定是有值的，但是在这个情况下，
    -- redis为空，那么就需要在下次定时器执行的时候将dict当中的wip list
    -- 同步到redis，触发这个条件的就是时间戳，因此要在这个情况下只更新
    -- dict的时间戳；在 1、3 下 ，redis为空，影响就不大了，只需要dict是
    -- 有值的，并且是dict将数据推向redis，注意：redis为空，那么也不存在
    -- 会覆盖原有值的问题。
    if wip_list == null or not wip_list 
    or wip_list == '' then
        if point == 2 then
            local sec = sec.sec()
            wip_zone:set('wip_list_update_time', sec)
            redis.redis_close(lepai)
            return
    -- 通过观察上面的代码和对比下面的代码，发现dict_wip_list倘若是有值的
    -- 这个可能来自两个地方，一是在初始化的时候包含了初始化ip和wip list
    -- 二是在正常的执行过程当中，wip list的值，那么就可以很清晰的知道，
    -- 除了在初始化的时候，其余情况下，ip是已经被写入了dict了，不需要
    -- 执行 ”wip_zone:set(ip, sec, exptime)“。
        else
            if #dict_wip_list == 0 or not dict_wip_list then
                local sec = sec.sec()
                wip_zone:set('wip_list_update_time', sec)
                pcall(function() 
                redis.redis_close(lepai) 
                end)
                return
            end
            local wip_list = tts.tts(dict_wip_list) 
            local sec = sec.sec()
            wip_zone:set('wip_list_update_time', sec)
            wip_zone:set('wip_list', wip_list)
            pcall(function() 
            lepai:set('wip_list_update_time', sec)
            lepai:set('wip_list', wip_list)
            redis.redis_close(lepai)
            end)
            return
        end
    end
    -- 程序执行到这个位置，一般就是认为redis是有值的，wip list不为空，
    -- 那么就按照之前的逻辑设计走，下面的for循环结束以后，肯定是可以
    -- 保证dict_wip_list的内容是最新的，即使redis有之前dict表当中没有，
    -- 最后也都会加进来，这个最新的表之后会被同时推到redis和dict，
    -- 对于redis和dict来说，都是一个覆盖过程，并且
    local wip_list = stt.stt(wip_list)
    for num = 1, #wip_list do
        local res = 
        wip_zone:get(wip_list[num])
        if not res then
            local sec = sec.sec()
            wip_zone:set(wip_list[num], sec)
            table.insert(dict_wip_list, 
            wip_list[num])
        end 
    end 
    local wip_list = tts.tts(dict_wip_list)
    local sec = sec.sec()
    wip_zone:set('wip_list_update_time', sec)
    wip_zone:set('wip_list', wip_list)
    pcall(function() 
    lepai:set('wip_list_update_time', sec) 
    lepai:set('wip_list', wip_list)
    redis.redis_close(lepai)
    end)
    if point == 1 then
        log(INFO, '[ INFO ]: '
        ..'WHITE IP TIMER: '
        ..' DICT ===> REDIS ！！！')
        return
    elseif point == 2 then
        log(INFO, '[ INFO ]: '
        ..'WHITE IP TIMER: '
        ..' REDIS ===> DICT ！！！')
    else
        log(INFO, '[ INFO ]: '
        ..'WHITE IP TIMER: '
        ..' WHITE IP INIT COMPLETE ！！！')
    end 
end

-- once black
-- black: 从redis当中取出数据覆盖到dict (redis一定是正常的)
-- black: 从dict当中取出数据覆盖到redis
-- redis ---> dict
-- 最新的更新当中，已经取消了黑名单的两个
-- 1 dict ---> redis
-- 2 redis ---> dict
-- 3 once
local function black_ip_update(point)
    log(INFO, '[ INFO ]: '
    ..'BLACK POINT :'..point)
    if point == 2 then
        local _, points = 
        pcall(function() 
        local lepai = redis.redis_conn()
        local points = lepai:get('DEL_bip_point')
        if points ~= null then
             return 1
        end
        redis.redis_close(lepai)
        end)
        if points then
            pcall(function() 
            local lepai = redis.redis_conn()
            local redis_bip_list = lepai:get('bip_list')
            local redis_bip_list = stt.stt(redis_bip_list)
            local dict_bip_list  = bip_zone:get('bip_list')
            local dict_bip_list  = stt.stt(dict_bip_list)
            for num = 1, #dict_bip_list do
                bip_zone:delete(dict_bip_list[num])
            end 
            local sec = sec.sec()
            for num = 1, #redis_bip_list do
                bip_zone:set(redis_bip_list[num], sec)
            end 
            bip_zone:set('bip_list', tts.tts(redis_bip_list))
            bip_zone:set('bip_list_update_time', sec)
            local DEL_bip_point = lepai:get('DEL_bip_point')
            if DEL_bip_point ~= null then
                if tonumber(DEL_bip_point) >= 2 then
                    lepai:set('DEL_bip_point', DEL_bip_point - 1)
                else
                    lepai:del('DEL_bip_point')
                end
            end 
            redis.redis_close(lepai)
            end)
            return
        end 
    end 
    -- redis ---> dict
    -- 触发这次条件的是，redis的数据时间戳更新，或者dict的时间戳为空，
    -- 那么，下一次就需要dict将数据更新到redis，那么就需要更新dict时间戳
    -- 来触发这次条件
	local _, bip_list = 
    pcall(function()
    local lepai = redis.redis_conn() 
    local bip_list = lepai:get('bip_list')
    return bip_list
    end)
    local _, dict_bip_list = 
    pcall(function() 
    local dict_bip_list = 
    bip_zone:get('bip_list')
    return stt.stt(dict_bip_list)
    end)
    if not dict_bip_list then
        dict_bip_list = {}
    end
    if bip_list == null or not bip_list 
    or bip_list == '' then 
        if point == 2 then
            local sec = sec.sec()
            bip_zone:set('bip_list_update_time', sec)
            redis.redis_close(lepai)
            return
        else
            if #dict_bip_list == 0 then
                local sec = sec.sec()
                bip_zone:set('bip_list_update_time', sec)
                redis.redis_close(lepai)
                return
            end
            local bip_list = tts.tts(dict_bip_list)
            local sec = sec.sec()
            bip_zone:set('bip_list_update_time', sec)
            bip_zone:set('bip_list', bip_list)
            pcall(function() 
            lepai:set('bip_list_update_time', sec) 
            lepai:set('bip_list', bip_list)
            redis.redis_close(lepai)
            end)
            return
        end
    end
    local bip_list = stt.stt(bip_list)
    for num = 1, #bip_list do
        local res = 
        bip_zone:get(bip_list[num])
        if not res then
            table.insert(dict_bip_list, 
            bip_list[num])
            local sec = sec.sec()
            bip_zone:set(bip_list[num], 
            sec, exptime)
        end
    end
    local bip_list = tts.tts(dict_bip_list)
    local sec = sec.sec()
	bip_zone:set('bip_list_update_time', sec)
	bip_zone:set('bip_list', bip_list)
	pcall(function() 
    lepai:set('bip_list_update_time', sec) 
    lepai:set('bip_list', bip_list)
    redis.redis_close(lepai)
    end)
    if point == 1 then
        log(INFO, '[ INFO ]: '
        ..'BLACK IP TIMER: '
        ..' DICT ===> REDIS ！！！')
        return
    elseif point == 2 then
        log(INFO, '[ INFO ]: '
        ..'BLACK IP TIMER: '
        ..' REDIS ===> DICT ！！！')
    else
        log(INFO, '[ INFO ]: '
        ..'BLACK IP TIMER: '
        ..' BLACK IP INIT COMPLETE ！！！')
    end
end

-- white ip更新主函数
local function white_ip()
	local res = judge_redis()
	--redis无法连接	
	if res then
        log(INFO, '[ INFO ]: '
        ..'WHITE IP TIMER: '
        ..'REDIS CANNOT CONNECT..'
        ..'.. NO UPDATE ！！！')
		local sec = sec.sec()
		wip_zone:set(
        'wip_list_update_time', 
        sec)
        return
    end
	--redis正常
	local lepai = redis.redis_conn()
	local redis_sec = 
    lepai:get('wip_list_update_time')
	local dict_sec = 
    wip_zone:get('wip_list_update_time')
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
	if not dict_sec and 
    not redis_sec then
        log(INFO, '[ INFO ]: '
        ..'WHITE IP TIMER: '
        ..'REDIS DICT ALL NULL'
        ..'REDIS and DICT NO UPDATE ！！！')
	elseif not dict_sec then
        white_ip_update(2)
	elseif not redis_sec then
        white_ip_update(1)
	elseif 0 < d_value 
    and rate < d_value then
        white_ip_update(2)
	elseif d_value < 0 
    and abs_d_value > rate then
        white_ip_update(1)
	elseif abs_d_value >= 0 
    and abs_d_value <= rate then
		log(INFO, '[ INFO ]: '
        ..'WHITE IP TIMER: '
        ..'UPDATETIME DIFF: '..abs_d_value
        ..' < '..' threshold: '..rate
        ..', REDIS and DICT NO UPDATE ！！！')
	else
		log(ERR, '[ ERR ]: '
        ..'WHITE IP TIMER ERROR ！！！')
	end
	pcall(function() 
    redis.redis_close(lepai) 
    end)	
end 

-- black ip 更新主函数
local function black_ip()
	local res = judge_redis()
	--redis无法连接	
	if res then
        log(INFO, '[ INFO ]: '
        ..'BLACK IP TIMER: '
        ..'REDIS CANNOT CONNECT..'
        ..'.. NO UPDATE ！！！')
	    local sec = sec.sec()
        bip_zone:set(
        'bip_list_update_time', 
        sec)
		return 
	--redis正常
    end
	local lepai = redis.redis_conn()
	local redis_sec = 
    lepai:get('bip_list_update_time')
	local dict_sec = 
    bip_zone:get('bip_list_update_time')
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
    ..'BLACK IP TIMER: '	
    ..'REDIS DICT ALL NULL'
    ..'REDIS and DICT NO UPDATE ！！！')
	elseif not dict_sec then
	    black_ip_update(2)
	elseif not redis_sec then
	    black_ip_update(1)
	elseif 0 < d_value 
    and rate < d_value then
	    black_ip_update(2)
	elseif d_value < 0 
    and abs_d_value > rate then
	    black_ip_update(1)
	elseif abs_d_value >= 0 
    and abs_d_value <= rate then
		log(INFO, '[ INFO ]: '
        ..'BLACK IP TIMER: '
        ..'UPDATETIME DIFF: '..abs_d_value
        ..' < '..' threshold: '..rate
        ..', REDIS and DICT NO UPDATE ！！！')
	else
		log(ERR, '[ ERR ]: '
        ..'BLACK IP TIMER ERROR ！！！')
	end
	pcall(function() 
    redis.redis_close(lepai) 
    end)	
end

--定时更新 主函数
local function main()
	white_ip()
	black_ip()
end

-- 同步key到dict 主函数
-- 在第一次执行定时器的时候，会将redis当中的黑名单
-- 同步到dict，这里会做出一些逻辑判断
-- 如果redis当中所有的表为空，那么就会导致获取出错
local function once_main()
	white_ip_update(3)
	black_ip_update(3)
end

-- timer(2, once_main)
timers(delay, main)

