-- Copyright © (C) Zhendong (DDJ)
-- 2019.03.05 14:13
-- 白名单连接器
local stt           = require"resty.kerri.basic.str_to_table"
local tts           = require"resty.kerri.basic.table_to_str"
local sm            = require"resty.kerri.basic.send_message"
local sec           = require"resty.kerri.basic.get_ngx_sec"
local ri            = require"resty.kerri.basic.remote_ip"
local ji            = require"resty.kerri.basic.judge_ip"
local cj            = require "cjson"
local wip_zone      = ngx.shared['white_ip_zone']
local bip_zone      = ngx.shared['black_ip_zone']
local exit          = ngx.exit
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local ERR_403       = ngx.HTTP_FORBIDDEN
local pairs         = pairs
local setmetatable  = setmetatable

local _M = { 
    _AUTHOR = 'zhendong 2019.03.05',
    _VERSION = '0.3.5',
}

local mt = { __index = _M }

function _M.new()
    local self = { 
        _index = table  
    }
    return setmetatable(self, mt) 
end

-- 返回403
local function go_403()
	ngx.exit(ERR_403)	
end

-- 白名单查询
-- 不存在返回403
local function wip_get(remote_ip)
	if not wip_zone:get(remote_ip) then
		log(INFO,'[ INFO ]: '
		..'{ '..remote_ip..' } is NOT IN WHITE IP')
		go_403()
	end
end

-- 黑名单查询
-- 存在返回403
local function bip_get(remote_ip)
	if bip_zone:get(remote_ip) then
		log(INFO,'[ INFO ]: '
		..'{ '..remote_ip..' } is BLACK IP')
		go_403()
	end
end

-- 注册：domain到白名单当中，作为key
-- 同时维护一个列表，当中存储domain，以便后面查找
-- 只在第一次会进行创建，后面不会，减小性能上的消耗
-- 数据模型：
-- domain_list:  {'localhost','9999.eguagua.cn'}
-- localhost: {
--              "timestamp": "1554316035",
--              "/option_bwip": "w",
--              "/dynamic_upstream_timer": "w",
--              "/healthcheck_timer": "w",
--              "/wip_timer": "b"
--          }
local function storage_domain(domain, location, status)
	if status ~= 'w' and status ~= 'b' then
		return
	end
    local tab = {}
    local domain_tab = {}
	local domains = wip_zone:get(domain)
	if not domains then
		local domain_list = wip_zone:get('domain_list')
		if domain_list then
			tab = stt.stt(domain_list)
		end
		table.insert(tab, domain)
		local str_domain_list = tts.tts(tab)
		local sec = sec.sec()
        domain_tab['timestamp'] = sec
		domain_tab[location] = status
		local enc_domain = cj.encode(domain_tab)
		wip_zone:set('domain_list_update_time', sec)
		wip_zone:set('domain_list', str_domain_list)
		wip_zone:set(domain, enc_domain) 
		return
	end
	local dec_domain = cj.decode(domains)
	if not dec_domain[location] then
        local sec = sec.sec()
        dec_domain['timestamp'] = sec
		dec_domain[location] = status
		local enc_domain = cj.encode(dec_domain)
		wip_zone:set(domain, enc_domain)
	end 
end

-- 用来真正处理当前请求ip的合法性
local function factory(domain, location, remote_ip)
	local dict_domain = wip_zone:get(domain)
	local dict_domain = cj.decode(dict_domain)
	local status = dict_domain[location] 
	if status == 'w' then
		wip_get(remote_ip)
	elseif status == 'b' then
		bip_get(remote_ip)
	end
	log(INFO, '[ INFO ]: '
	..'IP: { '..remote_ip..' } is pass ! ')
	return
end

-- connector main
-- domain作为可选参数，但是不希望添加，尤其是添加了
-- localhost和一个ip作为参数，很有可能和其他的server产生
-- 冲突，因此要是必须添加，可以是非以上的域名，或者直接
-- 由我来获取，这样更安全.
-- 最近更新的由一个问题就是：
--   倘若不填第三个参数，脚本里会去自动获取，当
function _M.connector(location, status, domain)
    local domain = domain
	if domain then
		if domain == 'localhost' 
        or ji.ji_for_other(domain) then	
			log(ERR, '[ ERR ]: '
			..'[ domain ] can not be " '
			..domain..' " ip or localhost ！！！'
			..'\r\n'..'if domain args is a real domain'
			..', you do not have to add the args, you can'
			..'empty it ！！！')
			return
		end
        domain = domain
	else
        domain = 
        (ngx.var.server_name == '127.0.0.1' 
        and {'localhost'} or {ngx.var.server_name})[1]
	end
	storage_domain(domain, location, status)
    local remote_ip = ngx.var.remote_addr
    local x_forwarded_for = ngx.var.http_x_forwarded_for
    local remote_ip = ri.remote_ip(remote_ip, x_forwarded_for)
	if not remote_ip then
		log(ERR, '[ ERR: '
		..'CAN NOT get remote_ip, so it is pass')
		return
	end
    if not factory(domain, location, remote_ip) then
        return
    end
end

return _M

