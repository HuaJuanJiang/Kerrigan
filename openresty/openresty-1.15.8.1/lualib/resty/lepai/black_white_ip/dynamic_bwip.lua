-- Copyright © (C) Zhendong (DDJ)
-- 0.2.26开发日期：2019.02.26 14:31
-- 0.3.06开发日期：2019.03.06 14:07
-- 功能简介：
--    动态黑白名单库函数，此为白名单库函数，调用函数在conf/lua/white_ip下的文件来实现
--    同步到dict和redis，同时有定时器更新，这里同样用到时间戳
-- 2019.03.28 16:33
--      上次更新还是去redis，但是这次需要增加redis的部分同步功能了
--   因为在最新的黑白名单定时器设计当中，加入了并集的概念，导致黑白名单
--   的删除功能受到了限制，因为单单删除了dict当中的ip，会导致定时器从redis
--   当中拉取数据，最后导致删除的ip会由于并集代码设计思路的原因，再次加入回
--   到 list ，因此现在需要增加同步redis的删除功能，也因此只针对删除功能，添加
--   功能和并集设计概念重叠，不做修改

local redis         = require"resty.lepai.basic.redis_conn"
local ctc           = require"resty.lepai.basic.composite_tab_c"
local stt           = require"resty.lepai.basic.str_to_table"
local tts           = require"resty.lepai.basic.table_to_str"
local sm            = require"resty.lepai.basic.send_message"
local sec           = require"resty.lepai.basic.get_ngx_sec"
local ji            = require"resty.lepai.basic.judge_ip"
local cj            = require "cjson"
local wip_zone      = ngx.shared['white_ip_zone']
local bip_zone      = ngx.shared['black_ip_zone']
local say           = ngx.say
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local pairs         = pairs
local setmetatable  = setmetatable

local _M = { 
    _AUTHOR = 'zhendong 2019.03.06',
    _VERSION = '0.3.06', 
}
local mt = { __index = _M }

--占位符“_”
function _M.new()
    local self = { 
        _index = table  
    }   
    return setmetatable(self, mt) 
end

--数字判断
local function if_num(num)
	local res = tonumber(num)
	if res == nil then
		say('[ ERR ]: '
		..'数字不合法')
		return 1	
	end
end

--判断IP合法性
local function judge_ip(ip)
	--say('[ INFO ]: '
	--..'get ip: ', ip)
	if ip == '' or not ip then
		pcall(function() say('[ ERR ]: '
		..'ip is null, please !!!')end)
		return 1
	end
	local res = ji.ji_for_other(ip)
	if res then
		pcall(function() say('[ ERR ]: '
		..'ip is illage, please !!!')end)
		return 1 
	end
end

-- white ip add
-- 添加白名单ip
local function white_ip_add(white_ip)
	local white_ip_list = wip_zone:get('wip_list')
	if not white_ip_list then
		say('[ INFO ]: '
		..'white ip list not exist, so create !')
		tab = {}
	else
		local res = wip_zone:get(white_ip)
		tab = stt.stt(white_ip_list)	
		if res then
			say('[ ERR ]: '..'the ip is repeat !')
			return
		end
		say('[ INFO ]: '
		..'white ip list has update...\r\n'
		..' IP: " '..white_ip..' "')
	end
	table.insert(tab, white_ip)
	local str_wip_list = tts.tts(tab)
	local sec = sec.sec()
	wip_zone:set('wip_list_update_time', sec)
	wip_zone:set('wip_list', str_wip_list)
	wip_zone:set(white_ip, sec)	
end

-- white ip del
-- 删除白名单ip
local function white_ip_del(white_ip)
	local white_ip_list = wip_zone:get('wip_list')
	local res = wip_zone:get(white_ip)
	if not white_ip_list then
		say('[ INFO ]: '
		..'white ip list not exist !')
		return
	end
	if not res then
		say('[ ERR ]: '
		..'" '..white_ip..' " is NOT IN DICT !'
		..'please check it ')
		return
	end
	local tab_wip_list = stt.stt(white_ip_list)
	tab = {}
	for k, v in pairs(tab_wip_list) do
		if v ~= white_ip then
			table.insert(tab, v)
		end
	end
	say('[ INFO ]: '
	..'white ip list has delete...\r\n'
	..' IP: " '..white_ip..' "')
	local str_wip_list = tts.tts(tab)
	local sec = sec.sec()
	wip_zone:set('wip_list_update_time', sec)
	wip_zone:set('wip_list', str_wip_list)
	wip_zone:delete(white_ip)
    -- redis 删除
    pcall(function()
    local lepai = redis.redis_conn()
    lepai:set('wip_list_update_time', sec)
    lepai:set('wip_list', str_wip_list)
    local cluster_state = lepai:get('cluster_state')
    local cluster_state = cj.decode(cluster_state)
    local num = ctc.ctco(cluster_state['node']) - 1
    lepai:set('DEL_wip_point', num)
    redis.redis_close(lepai)
    end)
end

-- black ip add
-- 添加ip到黑名单当中
local function black_ip_add(black_ip, exptime)
	-- exptime 作为可选项
	if exptime then
		local res = if_num(exptime)
		if res then
			return	
		end
	else
        -- 默认8小时
		exptime = 8
	end
	local black_ip_list = bip_zone:get('bip_list')
	if not black_ip_list then
		pcall ( function() say('[ INFO ]: '
		..'black ip list not exist, so create !') end )
		log(INFO, '[ INFO ]: '
		..'black ip list not exist, so create !')
		tab = {}
		table.insert(tab, black_ip)
	else
		--考虑到ip会过期，但是bip_list不会更新，导致
		--重复添加ip，但不提斯重复的错误信息，现在依旧
		--不会提示，但是会保证bip_list不会出现重复ip
		local res = bip_zone:get(black_ip)
		if res then
			pcall ( function() say('[ ERR ]: '
            ..'the ip is repeat !') end)
			log(INFO, '[ ERR ]: '..'the ip is repeat !')
			return
		end
		tab = stt.stt(black_ip_list)	
		exist_intab = 1
		for k, v in pairs(tab) do
			if v == black_ip then
				exist_intab = nil
			end	
		end
		if exist_intab then
			table.insert(tab, black_ip)
		end
		pcall ( function() say('[ INFO ]: '
		..'black ip list has update...\r\n'
		..' IP: " '..black_ip..' "') end)
		log(INFO, '[ INFO ]: '
		..'black ip list has update...\r\n'
		..' IP: " '..black_ip..' "')
	end
	local str_bip_list = tts.tts(tab)
	local exptime = exptime * 3600
	local sec = sec.sec()
	local res = bip_zone:set('bip_list_update_time', sec)
	local res = bip_zone:set('bip_list', str_bip_list)
	local res = bip_zone:set(black_ip, sec, exptime)
	exptime = nil
end

-- black ip del
-- 将ip从黑名单当中删除
local function black_ip_del(black_ip, status)
    local res = bip_zone:get(black_ip)
    local black_ip_list = bip_zone:get('bip_list')
    tab = {}
    -- 意味着要清除黑名单全部的ip
    if status == 'all' then
        if not black_ip_list then
            pcall ( function() say('[ INFO ]: '
            ..'black ip list not exist !')
            end)
            return
        end
        local tab_bip_list = stt.stt(black_ip_list)
        for k, v in pairs(tab_bip_list) do
            local res = bip_zone:delete(v)
        end
        pcall ( function()
        say('[ INFO ]: '
        ..'black ip has been deleted ALL ！')
        end)
    else
        if not black_ip_list then
            pcall ( function()
            say('[ INFO ]: '
            ..'black ip list not exist !')
            end)
            return
        end
        local tab_bip_list = stt.stt(black_ip_list)
        exist_intab = nil
        for k, v in pairs(tab_bip_list) do
            if v ~= black_ip then
                table.insert(tab, v)
            else
                exist_intab = 1
            end
        end
        -- 同样删除ip，不能因为ip不存在于dict当中，就认为ip确实不存在，
        -- 它有可能只是过期了，在bip_list当中还存在的。
        if not res and not exist_intab then
            pcall ( function()
            say('[ ERR ]: '
            ..'" '..black_ip..' " is NOT IN DICT ！！！'
            ..'\r\n'..'please check it ')
            end)
            return
        end
        pcall ( function()
        say('[ INFO ]: '
        ..'black ip list has delete...\r\n'
        ..' IP: " '..black_ip..' "')
        end)
    end
    local str_bip_list = tts.tts(tab)
    local sec = sec.sec()
    bip_zone:set('bip_list_update_time', sec)
    bip_zone:set('bip_list', str_bip_list)
    bip_zone:delete(black_ip )
    pcall(function()
    local lepai = redis.redis_conn()
    lepai:set('bip_list_update_time', sec)
    lepai:set('bip_list', str_bip_list)
    local cluster_state = lepai:get('cluster_state')
    local cluster_state = cj.decode(cluster_state)
    local num = ctc.ctco(cluster_state['node']) - 1
    lepai:set('DEL_bip_point', num)
    redis.redis_close(lepai)
    end)
end

-- black white ip check
-- 黑白名单检查
local function check_ip(from, ip)
	if from == nil or from == '' then
		say('[ ERR ]: '
		..'from args is NULL')
		return
	end
    -- 白名单
	if from == 'white' then
		--为了配合from=list，查询整个wip_list
		if ip then
			local res = wip_zone:get(ip)
			if not res then
				say('[ ERR ]: '
				..'IP: " '..ip
                ..' " NOT EXIST IN DICT ', from)
				return
			end
			say('[ INFO ]: '
			..from..' IP is here: '..'\r\n'
			..ip..': ', res)
			return
		end
		local wip_list = wip_zone:get('wip_list')
		local tab_wip_list  = stt.stt(wip_list)
		if not wip_list then
			say('[ INFO ]: '
			..'wip_list is NOT EXIST ！！！')
			return
		end
		say('[ INFO ]: '
		..'White ip list')
		for k, v in pairs(tab_wip_list) do
			say('IP: "'..v..'"')
		end
		return
    -- 黑名单
	elseif from == 'black' then
		if ip then
			local res = bip_zone:get(ip)
			if not res then
				local bip_list = bip_zone:get('bip_list')
				local bip_list = stt.stt(bip_list) 
				-- 查询一个ip，但是已经过期，bip_list依旧存在
				-- 不能认为这个就是不存在的。
				exist = nil
				for k, v in pairs(bip_list) do
					if v == ip then
						exist = 1
					end	
				end
				if exist then
					say('[ ERR ]: '
					..'IP: '..ip..' have expired ！！！'
					..'\r\n'..'But bip_list still have it')
					return
				end
				say('[ ERR ]: '
				..'IP: " '..ip
				..' " NOT EXIST IN DICT ', from)
				return
			end
			say('[ INFO ]: '
			..from..' IP is here: '..'\r\n'
			..ip..': ', res)
			return
		end
		local bip_list = bip_zone:get('bip_list')
		local tab_bip_list = stt.stt(bip_list)
		if not bip_list then
			say('[ INFO ]: '
			..'bip_list is NOT EXIST ！！！')
			return
		end
		say('[ INFO ]: '
		..'Black ip list')
		for k, v in pairs(tab_bip_list) do
			say('IP: "'..v..'"')
		end
		return
	else
		say('[ ERR ]: '
		..'from args is NOT RIGHT')
	end
end

-- white black modify ip
-- 黑白名单ip状态修改
local function modify_ip(ip, from, to, exptime)
	say('from:', from, ' to: ', to)
	if from == nil or from == '' 
	or to == nil or to == '' then
		say('[ ERR ]: '
		..' " from " or " to " args is NULL')
		return
	end
	local res = if_num(exptime)
	if res then
		return	
	end
    --判断from
	if from == 'white' and to == 'black' then
		local res = wip_zone:get(ip)
		if not res then
			say('[ ERR ]: '
			..'modify IP from white to black, but '
			..'" '..ip..' " is not EXIST')
			return
		end
		--从白名单删除
		white_ip_del(ip)
		--添加到黑名单
		black_ip_add(ip, exptime)
	elseif from == 'black' and to == 'white' then
		local res = bip_zone:get(ip)
		if not res then
			say('[ ERR ]: '
			..'modify IP from black to white, but '
			..'" '..ip..' " is not EXIST')
			return
		end
		--从黑名单删除
		black_ip_del(ip)
		--添加到白名单
		white_ip_add(ip)
	else
		say('[ ERR ]: '
		..'from where to where ? ? ? ')	
	end
end

-- modify location
-- 更改location黑白名单状态
local function modify_location(domain, location, status)
	-- 判断是否存在
	if domain == '' or not domain then
		say('[ ERR ]: '
		..'DOMAIN is nul or something ? ')
		return	
	elseif location == '' or not location then
		say('[ ERR ]: '
		..'LOCATION is nul or something ? ')
		return
	elseif status == '' or not status then
		say('[ ERR ]: '
		..'STATUS is nul or something ? ')
		return
	end
	local res = wip_zone:get(domain)
	if not res then
		say('[ ERR ]: '
		..'" '..domain..' " is not EXIST ！！！')
		return
	end
	local tab_domain = cj.decode(res)
	local res = tab_domain[location] 
	if not res then
		say('[ ERR ]: '
		..'" '..location..' " is not EXIST '
		..'IN '..domain..' ！！！')
		return
	end
	if status ~= 'w' and status ~= 'b' then
		say('[ ERR ]: '
		..'" '..status..' " is not w or b ！！！')
		return
	end
	local old = tab_domain[location]
    local sec = sec.sec()
	tab_domain[location] = status
    tab_domain['timestamp'] = sec
	local str_domain = cj.encode(tab_domain)
	wip_zone:set(domain, cj.encode(tab_domain))
    wip_zone:set('domain_list_update_time', sec)
	say('[ INFO ]: '
	..'" '..domain..' " has been UPDATE... '..'\r\n'
	..'"'..location..'" from "'
	..old..'" to "'..status..'"')
end

-- check location 
-- 检查location黑白名单状态
local function check_location(domain, location)
	if domain ~= nil and domain ~= '' then
		local str_domain = wip_zone:get(domain)	
		--判断存在
		if str_domain then
			--判断location存在
			if location then
				local tab_domain = cj.decode(str_domain)
				local res = tab_domain[location]
				--判断location是否可以取到
				if res then
					say('[ INFO ]: '
					.."Domain ["..domain.."]'s location ["
					..location.."]'s status is "
					..'"'..res..'"')
					return
				end
				say('[ INFO ]: '
				.."Domain ["..domain.."]'s location"
				..'["'..location..'"] NOT EXIST ！！！')
				return
			end
			say('[ INFO ]: '
			..'Domain ['..domain..']: '
			..str_domain)
			return
		end
		say('[ ERR ]: '
		..'"'..domain..'" is NOT EXIST ！！！')
		return	
	end
    -- 指定domain后，直接从dict中获取来查找
	local domain_list = wip_zone:get('domain_list')	
	if not domain_list then
		say('[ INFO ]: '
		..'" domain_list " is NOT EXIST, '
		..'maybe there is no website traffic here ? ? ?')
		return
	end
	local domain_list = stt.stt(domain_list)
	for k, domain in pairs(domain_list) do
		local str_domain = wip_zone:get(domain)
		say('\r\n'..'[ INFO ]: '
		..'Domain ['..domain..']: ')
		local tab_domain = cj.decode(str_domain)
		for k, v in pairs(tab_domain) do
			say('location: ['..k..'] ----> '
			..' status: "'..v..'"')
		end
	end
end


-------------------black&white ip-------------------

-- white ip add main
-- 添加白名单ip主函数
function _M.add_wip(white_ip)
	local res = judge_ip(white_ip)
	if res then
		return
	end
	white_ip_add(white_ip)
end

-- white ip del main
-- 删除白名单ip主函数
function _M.del_wip(white_ip)
	local res = judge_ip(white_ip)
	if res then
		return
	end
	white_ip_del(white_ip)
end

-- black ip add main
-- 添加黑名单ip主函数
function _M.add_bip(black_ip, exptime)
	local res = judge_ip(black_ip)
	if res then
		return
	end
	black_ip_add(black_ip, exptime)
end

-- black ip del main
-- 删除黑名单ip主函数
function _M.del_bip(black_ip, status)
	local res = judge_ip(black_ip)
	if res then
		return
	end
	black_ip_del(black_ip, status)
end

-- modify black white ip
-- 修改黑名单ip状态主函数
function _M.modify_ip(ip, from, to, exptime)
	local res = judge_ip(ip)
	if res then
		return
	end
	modify_ip(ip, from, to, exptime)	
end

-- check black white ip
-- 检查黑白名单ip状态主函数
function _M.check_ip(ip, from)
	if ip == 'list' then
		check_ip(from)
		return
	end
	local res = judge_ip(ip)
	if res then
		return
	end
	check_ip(from, ip)
end

-------------------location---------------------

-- modify domain
-- 更改location黑白名单状态主函数
function _M.modify_location(domain, location, status)
	modify_location(domain, location, status)
end

-- check domain
-- 检查location黑白名单状态主函数
function _M.check_location(domain, location)
	check_location(domain, location)
end

return _M

