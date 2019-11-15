-- Copyright © (C) Zhendong (DDJ)
-- upstream 连接器
-- 所有请求都需要经过
-- 需要注意的是目前ip_hex没有实现，
-- 因此ip_hex会按照rr来进行负载

local ctc           = require"resty.kerri.basic.composite_tab_c"
local rr            = require"resty.kerri.upstream.roundrobin"
local stt           = require"resty.kerri.basic.str_to_table"
local tts           = require"resty.kerri.basic.table_to_str"
local gri           = require"resty.kerri.basic.remote_ip"
local ba            = require"ngx.balancer"
local cj            = require "cjson"
local upstream_zone = ngx.shared['upstream_zone']
local say           = ngx.say
local exit          = ngx.exit
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local pairs         = pairs
local setmetatable  = setmetatable

local _M = { 
    _AUTHOR = 'zhendong 2019.01.02',
    _VERSION = '0.1.2',   
}

local mt = { __index = _M }

function _M.new()
    local self = { 
        _index = table  
    }   
    return setmetatable(self, mt) 
end

-- balancer factory
-- 最终balance 加工函数，通过输入有效的ip:port来使得请求
-- 可以正常传向后端服务器
local function balancer_factory(ip, port)
	ba.set_current_peer(ip, port)
	log(INFO, '[ INFO ]: '
    ..'CURRENT PEER: '
    ..' [ '..ip..':'..port..' ] ')
end

-- judge title
-- 判断title是否存在
local function exist_title(title)
	local upstream_list = 
    upstream_zone:get('upstream_list')
	if not upstream_list then
		log(ERR, '[ INFO ]: '
        ..'upstream_list is not exist in dict, '
        ..'maybe you just start the nginx,'
        ..' please init upstream conf !')
		return 1
	end
	local upstream_list = 
    stt.stt(upstream_list)
    for num = 1, #upstream_list do
        if upstream_list[num] == title then
            return
        end
    end
end

-- the title 
-- 请求处理函数
local function distributor(title)
    -- 不同的算法对应了上面不同的函数
    local upserver =
    upstream_zone:get('up_'..title)
    if not upserver then
        log(INFO, '[ INFO ]: '
        ..' [ '..title..' ] NO UPSERVER, SO 502 ！！！')
        exit(502)
        return
    end
    local upserver = cj.decode(upserver)
    local weight_list = upserver['weight_list']
    local algo = upserver['algo']
    local upserver = upserver['pool']
    -- local remote_ip = ngx.var.remote_addr
    -- local x_forwarded_for = ngx.var.http_x_forwarded_for
    -- -- 考虑到无法获取IP的情况下，如果正好是ip hex算法，
    -- -- 无法做IP的hex，那么可以考虑暂时使用一个指定的IP来访问
    -- if not gri.remote_ip(remote_ip, x_forwarded_for) then
    --     if algo == 'w_ip_hex' or algo == 'ip_hex' then
    --     end
    --     --log(INFO, '[ INFO ]: '
    --     --..' [ '..title..' ] CANNOT GET REMOTE IP, SO 502 ！！！')
    --     --exit(502)
    --     --return
    -- end
    
    -- 具体分配ip port
    local rr = rr:new()
    local ip, port = rr.rr(title, algo, upserver, weight_list)
    balancer_factory(ip, port)
end

-- dict coming
-- dict 执行函数 
local function dict_get(title)
    -- 判断是否存在title
	if exist_title(title) then
		exit(502)
		return
	end
    -- 请求处理
	distributor(title)
end

-- connector main
-- 连接器主函数
function _M.connector(title)
	dict_get(title)
end

return _M
