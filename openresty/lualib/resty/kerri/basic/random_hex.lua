--随机数以及hex模块

local _M = {}
local aes = require"resty.aes"
local str = require"resty.string"
local random = require"resty.random"

function _M.rh(len,strong)
    local aes_salt = aes:new('lepai')
    local auth_random = str.to_hex(random.bytes(len,strong)) --产生随机数
    local auth_random_encrypt = aes_salt:encrypt(auth_random) --将随机数进行盐加密
    local hex_auth_random_encrypt = str.to_hex(auth_random_encrypt) --进行哈希
	return hex_auth_random_encrypt
end

return _M

