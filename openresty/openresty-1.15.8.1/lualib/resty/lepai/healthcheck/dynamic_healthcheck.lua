-- Copyright © (C) Zhendong (DDJ)
-- 健康检查模板控制模块
-- 更新日期：
--   2019.01.09
--      开始开发健康检查模块
--
--   2019.03.19 10:30
--      主要是代码上的优化，更加简明概要；增加批量修改某个属性的功能
--   
--   2019.04.03 17:24
--      这次更新针对的是定时器改造所需要的时间戳
--
--   2019.04.04 10:56
--          今天的更新主要内容是将绑定的upstream list，尝试是否可以分出去一份到
--      healthcheck zone，有自己独立的时间戳，避免定时器之间的一些问题
 
local stt              = require"resty.lepai.basic.str_to_table"
local tts              = require"resty.lepai.basic.table_to_str"
local sec              = require"resty.lepai.basic.get_ngx_sec"
local cj               = require "cjson"
local upstream_zone    = ngx.shared['upstream_zone']
local healthcheck_zone = ngx.shared['healthcheck_zone']
local find             = ngx.re.find
local say              = ngx.say
local log              = ngx.log
local INFO             = ngx.INFO
local ERR              = ngx.ERR
local pairs            = pairs
local setmetatable     = setmetatable

local _M = {
	_AUTHOR = 'zhendong 2019.01.09',
	_VERSION = '0.1.9',	
}
local mt = { __index = _M }

function _M.new()
	local self = {
		_index = table	
	}
	return setmetatable(self, mt) 
end

--数字判断
local function if_num(num)
    local res = tonumber(num)
    if not res then
        return 1
    end
end

local http_code = { 100, 101, 
                    200, 201, 202, 203, 204, 205, 206,
                    300, 301, 302, 303, 304, 305, 306, 307,
                    400, 401, 402, 403, 404, 405, 406, 407, 
                    408, 409, 410, 411, 412, 413, 414, 415, 
                    416, 417,
                    500, 501, 502, 503, 504, 505 }


--[[
local healthcheck_table = { 
    timestamp = "16165131651",              私有时间戳
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
-- healthcheck template
-- 健康检查模板，当进行重置模板的操作的时候，会从这里拉取 
--
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

-- get upstream list from healthcheck zone
-- 当无法从ustream zone获取到upstream
local function get_upstream()
    local hc_upstream_list = 
    healthcheck_zone:get('hc_upstream_list')
    if not hc_upstream_list then
        local upstream_list = 
        upstream_zone:get('upstream_list')
        if not upstream_list then
            return
        end
        return stt.stt(upstream_list)
    end
    return stt.stt(hc_upstream_list)
end

--  judge title exist from upstream 
--  判断准备进行操作的title是否存在于upstream列表当中,
local function exist_title(title)
	if not title or title == '' then
		say('[ INFO ]: '
        ..'title is NULL, CAN NOT be NULL !!!')
		return
	end
    local tab_upstream = get_upstream()
    for _, v in pairs(tab_upstream)do
		if v == title then
			return "go ahead"
		end
    end 
end

-- add status code
-- 添加 status code 
local function add_status_code(
    title, 
    modify_tab, 
    health_type, 
    modify_val)
	local table_http_status = 
    modify_tab[health_type]['http_status']
    -- 判断status code是不属于http状态码当中的一个
    --ok = nil
    for _, v in pairs(http_code)do
        if v == tonumber(modify_val) then
            ok = 1
        end
    end
    local http_code = tts.tts(http_code)
    if not ok then
        say('[ INFO ]: '
        ..'modify_val is ILLIGES ！！！\r\n'
        ..'it must be in here: \r\n'
        ..http_code)
    end 
    -- 判断重复性
	for _, v in pairs(table_http_status) do
		if v == tonumber(modify_val) then
			say('[ INFO ]: '..title..' "\r\n '
            ..'repeat http status code \r\n '
			..'getcode:[ '..v..' ] == modify:[ '
			..modify_val..' ]\r\n')
			return
		end
	end
	local old_str_http_status = tts.tts(table_http_status)
	table.insert(table_http_status, tonumber(modify_val))
    local sec = sec.sec()
    modify_tab['timestamp'] = sec
	modify_tab[health_type]['http_status'] = 
    table_http_status 
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
    local modify_tab = cj.encode(modify_tab)
	local str_http_status = tts.tts(table_http_status)
	say('[ INFO ]: " '..title..' "\r\n'
    ..'Add http_status { '..modify_val..' } \r\n'
	..'Old: '..old_str_http_status
	..'\r\nNew: '..str_http_status)	
    return modify_tab
end

-- remove status code
-- 删除 status code 
local function remove_status_code(
    title, 
    modify_tab, 
    health_type, 
    modify_val)
    --local modify_tab = cj.encode(modify_tab)
    --log(INFO, modify_tab, health_type, modify_val)
    local table_http_status = 
    modify_tab[health_type]['http_status']
    local old_str_http_status = 
    tts.tts(table_http_status)
    --判断是否存在
	_exist = nil
	tab = {}
    for _, v in pairs(table_http_status) do
        if v == tonumber(modify_val) then
	    	_exist = 0
	    else
		    table.insert(tab, v)
        end
    end
	if not _exist then
		say('[ INFO ]: '..title..' "\r\n '
        ..'http status code is not exist \r\n '
		..'getcode:[ ', v ,' ] == modify:[ '
		..modify_val..' ]\r\n')
		return
	end
	local table_http_status = tab
    local sec = sec.sec()
    modify_tab['timestamp'] = sec
    modify_tab[health_type]['http_status'] = 
    table_http_status
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
    local modify_tab = cj.encode(modify_tab)
    local str_http_status = tts.tts(table_http_status)
    say('[ INFO ]: " '..title..' "\r\n '
    ..'Remove http_status { '..modify_val..' } \r\n'
    ..'Old: '..old_str_http_status
    ..'\r\nNew: '..str_http_status)
    return modify_tab
end

-- 单次修改参数函数
local function f_once_execution(
    modify_key, 
    modify_val, 
    title,
    health_type,
    code_act)
    if not code_act 
    and modify_key == 'http_status' then
        say('[ INFO ]: '
        ..'if " code_act " EXIST，it must be'
        ..' "add_code" or "remove_code"，'
        ..'and modify_key must be "http_status"')
        return
    end
    -- 获取title对应的模板
	local str_modify_tab = 
    healthcheck_zone:get(title)
    if not str_modify_tab then
        say('[ INFO ]: '
        ..'title [ '..title..' ]'
        ..' NOT EXIST to healthcheck_zone ！！！')
        return
    end
	local modify_tab = cj.decode(str_modify_tab)
    -- 开始判断key
    if code_act == 'add_code' 
    and modify_key == 'http_status' then
        local modify_tab = 
        add_status_code(
        title, 
        modify_tab, 
        health_type, 
        modify_val)
        if modify_tab then
            healthcheck_zone:set(
            title, 
            modify_tab)
        end
        return
    elseif code_act == 'remove_code' 
    and modify_key == 'http_status' then
        local modify_tab = 
        remove_status_code(
        title, 
        modify_tab, 
        health_type, 
        modify_val)
        if modify_tab then
            healthcheck_zone:set(
            title, 
            modify_tab)
        end
        return
    end
    -- 判断是修改health内的数值还是外部的数值
    if modify_key == 'http_path' 
    or modify_key == 'status' then
        old = modify_tab[modify_key]
        local sec = sec.sec()
        modify_tab['timestamp'] = sec
        modify_tab[modify_key] = modify_val
        modify_tab = cj.encode(modify_tab)
    else
        old = modify_tab[health_type][modify_key]
        local sec = sec.sec()
        modify_tab['timestamp'] = sec
        modify_tab[health_type][modify_key] = 
        tonumber(modify_val) 
        modify_tab = cj.encode(modify_tab)
    end
    local sec = sec.sec()
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
    healthcheck_zone:set(
    title, 
    modify_tab)
    say('[ INFO ]: " '..title..' " \r\n'
    ..' { '..modify_key..' } modify from [ '
    ..old..' ] to ---> [ '..modify_val..' ] \r\n{ '
    ..modify_key..' } Modify Successful ！！！')
    return
end

-- 批量修改参数函数
local function f_batch_execution(modify_key, 
    modify_val,
    title,
    health_type,
    code_act)
    -- 当时写在for循环里面，但是发现会导致性能损耗和不必要的循环
    if not code_act and modify_key == 'http_status' then
        say('[ INFO ]: '
        ..'if " code_act " EXIST，it must be'
        ..' "add_code" or "remove_code"，'
        ..'and modify_key must be "http_status"')
        return
    elseif code_act and modify_key ~= 'http_status' then
        say('[ INFO ]: '
        ..'if " code_act " EXIST，it must be'
        ..' "add_code" or "remove_code"，'
        ..'and modify_key must be "http_status"')
        return
    end
    local table_hc_usl = get_upstream()
    if not table_hc_usl then
        say('[ ERR ]: '
        ..'CANNOT GET upstream list ！！！')
        return
    end
    -- 逐个进行循环
    for _, upstream_one in pairs(table_hc_usl) do
        local str_modify_tab = 
        healthcheck_zone:get(upstream_one)
        if not str_modify_tab then
            say('[ INFO ]: '
            ..'title [ '..upstream_one..' ]'
            ..' NOT EXIST to healthcheck_zone ！！！')
            return
        end
        local modify_tab = cj.decode(str_modify_tab)
        -- 同样进行上述判断
        if code_act == 'add_code' 
        and modify_key == 'http_status' then
            local modify_tab = 
            add_status_code(
            upstream_one, 
            modify_tab, 
            health_type, 
            modify_val)
            if modify_tab then
                healthcheck_zone:set(
                upstream_one, 
                modify_tab)
            end
        elseif code_act == 'remove_code' 
        and modify_key == 'http_status' then
            local modify_tab = 
            remove_status_code(
            upstream_one, 
            modify_tab, 
            health_type, 
            modify_val)
            if modify_tab then
                healthcheck_zone:set(
                upstream_one, 
                modify_tab)
            end
        end
        if modify_key == 'http_path' 
        or modify_key == 'status' then
            local old = modify_tab[modify_key]
            local sec = sec.sec()
            modify_tab['timestamp'] = sec
            modify_tab[modify_key] = modify_val
            local modify_tab = cj.encode(modify_tab)
            healthcheck_zone:set(
            'hc_upstream_list_update_time', 
            sec)
            healthcheck_zone:set(
            upstream_one, 
            modify_tab)
            say('[ INFO ]: " '..upstream_one..' " \r\n'
            ..'{ '..modify_key..' } modify from [ '
            ..old..' ] to ---> [ '..modify_val..' ] \r\n{ '
            ..modify_key..' } Modify Successful ！！！'..'\r\n')
        -- 在code_act存在的时候，在执行完remove_status_code 或者 
        -- add_status_code 函数的时候就不应该执行下面的代码了，
        -- 但是因为lua 当中没有continue，所以在后续的判断当中，
        -- 还要再排除前面已经通过的条件，因此要这样写。
        -- 当然还有解决方式就是全部写成elseif的形式，这样也是可以的。
        elseif code_act ~= 'add_code' 
        and code_act ~= 'remove_code' 
        and modify_key ~= 'http_status' then 
            local old = modify_tab[health_type][modify_key]
            local sec = sec.sec()
            modify_tab['timestamp'] = sec
            modify_tab[health_type][modify_key] = 
            tonumber(modify_val)
            local modify_tab = cj.encode(modify_tab)
            healthcheck_zone:set(
            'hc_upstream_list_update_time', 
            sec)
            healthcheck_zone:set(
            upstream_one, 
            modify_tab)
            say('[ INFO ]:  [ '..upstream_one..' ] \r\n'
            ..'{ '..modify_key..' } modify from [ '
            ..old..' ] to ---> [ '..modify_val..' ] \r\n{ '
            ..modify_key..' } Modify Successful ！！！'..'\r\n')
        end
    end
end

-- judge modify key and val
-- 判断要修改的key和val，因为模板结构的原因
-- 有些key的修改是需要完全不同的函数结构来完成的
local function modify_legal_judge(title, 
    health_type, 
    modify_key, 
    modify_val,
    code_act,
    batch_execution)
	-- 判断是否为空值
	if title == '' 
    or health_type == '' 
    or modify_key == '' 
    or modify_val == '' then
		say('[ ERR ]: '
        ..'CANNOT BE EMPTY ')
		log(ERR, ' CANNOT BE EMPTY ')
		return 
	end
    -- 判断title对应的模板是否存在
	local modify_tab, err = 
    healthcheck_zone:get(title)
	if not modify_tab then
		say('[ INFO ]: '
        ..'CANNOT FIND title [ '..title
        ..' ] in healthcheck_zone')
		return
	end
    -- 如果修改http_path需要判断它是否合法
	-- http_path judge
	if modify_key == 'http_path' then
		local pos = string.find(modify_val, '/')
		if pos ~= 1 then
			say('[ ERR ]: '
            ..'{ '..modify_key
            ..' } key MUST BE SET A legitimate'
            ..' val, hava "/" '..'[ '
            ..modify_val..' ] is not right')
			return
		end
		return "go ahead"
	end
    -- 对batch_execution 进行判断
    if modify_key == 'status' then 
        if modify_val ~= 'running' 
        and modify_val ~= 'stop' then
            say('[ INFO ]: '
            ..'modify key [ '..modify_key
            ..' ] DONOT have '..' modify val '
            ..'[ '..modify_val..' ]')
            return
        end
        return "go ahead"
    end
    -- 对code_act 进行判断 
    if code_act == 'remove_code' 
    or code_act == 'add_code' then
        if modify_key ~= 'http_status' then
            say('[ INFO ]: '
            ..'if code act [ '..code_act..' ]'
            ..'is YOU WANT, but modify key [ '
            ..modify_key..' ] is NOT http_status')
            return
        end
        -- 判断status code是不属于http状态码当中的一个
        ok = nil
        for _,v in pairs(http_code)do
            if v == tonumber(modify_val) then
                ok = 1
            end
        end
        local http_code = tts.tts(http_code)
        if not ok then
            say('[ INFO ]: '
            ..'modify_val is ILLIGES ！！！\r\n'
            ..'It must BELONG TO the table : \r\n'
            ..http_code)
            return
        end 
    end
    -- 针对healthcheck和unhealthcheck的修改，
    -- 判断输入是否正确
	-- health_type judge
	if health_type == 'health' then 
		-- modify key and val judge
        -- 判断是否为success interval http_status 三种类型
		if modify_key == 'successes' or 
		modify_key == 'interval' or 
		modify_key == 'http_status' then
			local ok = if_num(modify_val)
			if ok then
				say('[ ERR ]: '
                ..'[ '..modify_key
                ..' ] MUST BE SET A NUMBER ! \r\n[ '
				..modify_val..' ] is NOT NUMBER !')
				return
			end
		else
			say('[ ERR ]: '
            ..'{ '..health_type..' } DONNOT have the [ '
			..modify_key..' ] key, so cannot SET ! ')			
			return
		end
	elseif health_type == 'unhealth' then
		-- modify key and val judge
        -- 同理判断 unhealth的 key和val
        if modify_key == 'http_failures' or  
        modify_key == 'interval' or  
        modify_key == 'timeout' or
        modify_key == 'http_status' then  
            local ok = if_num(modify_val)
            if ok then
                say('[ ERR ]: '
                ..'[ '..modify_key
                ..' ] MUST BE SET A NUMBER ! \r\n[ '
                ..modify_val..' ] is NOT NUMBER !')
                return
            end 
        else
			say('[ INFO ]: '
            ..'{ '..health_type..' } DONNOT have the [ '
			..modify_key..' ] key, so cannot SET ! ')			
			return
        end 
	else
		say('[ ERR ]: '
        ..'[ '..health_type
		..' ] not within the scope '
        ..'of HEALTH or UNHEALTH ')
		return
	end
    return "go ahead"
end

-- insert modify key and val
-- 插入要修改的值
local function modify_legal_insert(
    title, 
    health_type, 
    modify_key, 
    modify_val, 
    code_act, 
    batch_execution)
    -- 判断是否是批量执行
    if not batch_execution then
        f_once_execution(
        modify_key, 
        modify_val, 
        title, 
        health_type, 
        code_act)
    else
        f_batch_execution(
        modify_key, 
        modify_val, 
        title, 
        health_type, 
        code_act)
    end
end

-- start healthcheck temp
-- 开启某个title的健康检查
local function start_healthcheck_temp(title)
	local res = exist_title(title)
	if not res then
		say('[ ERR ]: '
        ..'DO NOT find the '
        ..title..', please check!!!')
		return
	end
	local tab = healthcheck_zone:get(title)
	local tab = cj.decode(tab)
    local sec = sec.sec()
    tab['timestamp'] = sec
	tab['status'] = 'running'
	local tab = cj.encode(tab)
	healthcheck_zone:set(title, tab)
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
	say('[ INFO ]: '
    ..'START " '..title
    ..' " Healthcheck Modular Successful')
end

-- stop healthcheck temp
-- 停止某个title的健康检查
local function stop_healthcheck_temp(title)
	local res = exist_title(title)
	if not res then
		say('[ ERR ]: '
        ..'DO NOT find the '..title
        ..', please check!!!')
		return
	end
	local tab = healthcheck_zone:get(title)
	local tab = cj.decode(tab)
    local sec = sec.sec()
    tab['timestamp'] = sec
	tab['status'] = 'stopped'
	local tab = cj.encode(tab)
	healthcheck_zone:set(title, tab)
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
	say('[ INFO ]: '
    ..'STOP " '..title
    ..' " Healthcheck Modular Successful')
end

-- reset healthcheck temp
-- 重置某个title的健康检查模块
local function reset_healthcheck_temp(title)
	local res = exist_title(title)
	if not res then
		say('[ ERR ]: '
        ..'DO NOT find the '
        ..title..', please check!!!')
		return
	end
    local sec = sec.sec()
	local tab = cj.encode(healthcheck_table)
	healthcheck_zone:set(title, tab)
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
	say('[ INFO ]: '
    ..'RESET " '..title
    ..' " Healthcheck Modular Successful')
end

-- start all healthcheck temp
-- 开启所有title健康检查
local function start_all_healthcheck_temp()
	local tab_upstream = get_upstream()
	for _, v in pairs(tab_upstream)do
		local tab = healthcheck_zone:get(v)
		if tab then
			local tab = cj.decode(tab)		
            local sec = sec.sec()
            tab['timestamp'] = sec
			tab['status'] = 'running'
			local tab = cj.encode(tab)
			healthcheck_zone:set(v, tab)
			say('[ INFO ]: '
            ..'START " '..v
            ..' " Healthcheck Modular Successful')
		end
	end
    local sec = sec.sec()
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
end

-- stop all healthcheck temp
-- 停止所有title健康检查
local function stop_all_healthcheck_temp()
	local tab_upstream = get_upstream()
	for _, v in pairs(tab_upstream)do
		local tab = healthcheck_zone:get(v)
		if tab then
			local tab = cj.decode(tab)		
            local sec = sec.sec()
            tab['timestamp'] = sec
			tab['status'] = 'stopped'
			local tab = cj.encode(tab)
			healthcheck_zone:set(v, tab)
			say('[ INFO ]: '
            ..'STOP " '..v
            ..' " Healthcheck Modular Successful')
		end
	end
    local sec = sec.sec()
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
end

-- reset all healthcheck temp
-- 重置所有title健康检查
local function reset_all_healthcheck_temp()
	local tab_upstream = get_upstream()
	for _, v in pairs(tab_upstream)do
		local tab = healthcheck_zone:get(v)
		if tab then

			local tab = cj.encode(healthcheck_table)
			healthcheck_zone:set(v, tab)
			say('[ INFO ]: '
            ..'RESET " '..v
            ..' " Healthcheck Modular Successful')
		end
	end
    local sec = sec.sec()
    healthcheck_zone:set(
    'hc_upstream_list_update_time', 
    sec)
end

-- healthcheck模板修改
-- healthcheck modify model
function _M.healthcheck_modify(
    title, 
    health_type, 
    modify_key, 
    modify_val, 
    code_act, 
    batch_execution)
    -- 判断各个传入的参数是否合法，
    -- 否则后面的插入操作函数就不会执行
	local res = 
    modify_legal_judge(
    title, 
    health_type, 
    modify_key, 
    modify_val,
    code_act, 
    batch_execution)
	if not res then
		return
	end
    -- 开始执行插入操作
	local modify_tab = 
    modify_legal_insert(
    title, 
    health_type, 
    modify_key, 
    modify_val, 
    code_act, 
    batch_execution)	
end

-- healthcheck check model
-- healthcheck模板状态查询
function _M.healthcheck_check(title)
    _exist_healthcheck = nil 
	local tab_upstream = get_upstream()
	for _, v in pairs(tab_upstream)do
		local tab_health_model = 
        healthcheck_zone:get(v)
        -- 查询title是否传入，如果没有，
        -- 将展示全部的title健康检查模板
		if not title or title == '' then
            -- 判断要查询title是否存在
			if not tab_health_model then
				say('[ IFNO ]: '
                ..' [ '..v
                ..' ] is not exist to '
                ..'healthcheck_zone, ')
            -- 展示所有title
			else
				say('[ INFO ]: '
                ..'[ '..v..' ]: ', '\r\n', 
                tab_health_model, '\r\n')
			end
        -- 如果title传入，那么就进行比对筛选
		else
			if v == title then
                _exist_healthcheck = 1
				say('[ INFO ]: '
                ..'[ '..v..' ]: ', '\r\n', 
                tab_health_model, '\r\n')
				return
			end
		end
	end
    if title and not _exist_healthcheck then
        say('[ ERR ]: '
        ..'['..title ..']'
        ..' is not EXIST DICT ！！！')
    end
end

-- healthcheck start stop reset
-- 健康检查停止启动主函数
function _M.healthcheck_model_option(act, title)
    if title then
        if act == 'start' and title then
            start_healthcheck_temp(title)		
        elseif act == 'stop' and title then
            stop_healthcheck_temp(title)		
        elseif act == 'reset' and title then
            reset_healthcheck_temp(title)		
        end
    else
        say('[ INFO ]: '
        ..' TITLE IS NULL ！！！ ')
    end
	if act == 'start-all' then
		start_all_healthcheck_temp()		
	elseif act == 'stop-all' then
		stop_all_healthcheck_temp()		
	elseif act == 'reset-all' then
		reset_all_healthcheck_temp()		
	end
end

return _M

