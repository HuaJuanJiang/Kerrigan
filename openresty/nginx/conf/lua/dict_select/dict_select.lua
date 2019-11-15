-- copyright © (C) Zhendong (DDJ)
-- dict共享空间查询接口
-- 因为本身空间是不对外开放的，也没有公共的查询平台
-- 因此需要一个接口可以实时查看空间当中某些值是否正确
-- 方便调试
-- 2019.03.06 09:18
-- 最近更新
--   2019.03.15 16:10

local stt           = require"resty.kerri.basic.str_to_table"
local tts           = require"resty.kerri.basic.table_to_str"
local cj            = require "cjson"
local wip_zone      = ngx.shared['white_ip_zone']
local bip_zone      = ngx.shared['black_ip_zone']
local auth_zone     = ngx.shared['auth_zone']
local upstream_zone = ngx.shared['upstream_zone']
local hc_zone       = ngx.shared['healthcheck_zone']
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local say           = ngx.say

local function abc()
    local a = 1
    local b = 3
    for num = 0, 3 do
        a = a + 1
        say(a)
        if b == 3 then
            a = 1000
        end
    end
    say('aaaa:',a)
end

local function abcd()
    say(a)
end
abc()
abcd()

----获取参数
--ngx.req.read_body()
--local res, err = ngx.req.get_post_args()
--if not res then
--    log(INFO1,'failed to get body ！！！')
--    return
--end
--
--local dict          = res['dict']
--local val           = res['val']
--
--if not val or val == '' then
--	say('[ ERR ]: '
--	..'val can not be EMPTY ! ')
--	return
--end
--
--if dict == 'ups' then
--	local res = upstream_zone:get(val)
--	if not res then
--		say('[ ERR ]: '
--		..'upstream DICT has not key " '
--		..val..' "')
--		return
--	end
--	say('[ INFO ]: '
--	..'\r\n'
--	..'val: '..res)
--elseif dict == 'hc' then
--	local res = hc_zone:get(val)
--	if not res then
--		say('[ ERR ]: '
--		..'healthcheck DICT has not key " '
--		..val..' "')
--		return
--	end
--	say('[ INFO ]: '
--	..'\r\n'
--	..'val: '..res)
--elseif dict == 'wip' then
--	local res = wip_zone:get(val)
--	if not res then
--		say('[ ERR ]: '
--		..'white ip DICT has not key " '
--		..val..' "')
--		return
--	end
--	say('[ INFO ]: '
--	..'\r\n'
--	..'val: '..res)
--elseif dict == 'bip' then
--	local res = bip_zone:get(val)
--	if not res then
--		say('[ ERR ]: '
--		..'black ip DICT has not key " '
--		..val..' "')
--		return
--	end
--	say('[ INFO ]: '
--	..'\r\n'
--	..'val: '..res)
--elseif dict == 'auth' then
--	local res = auth_zone:get(val)
--	if not res then
--		say('[ ERR ]: '
--		..'auth DICT has not key " '
--		..val..' "')
--		return
--	end
--	say('[ INFO ]: '
--	..'\r\n'
--	..'val: '..res)
--else
--	say('[ ERR ]: '
--	..'" '..dict..' " dict is not EXIST ! ')
--end

