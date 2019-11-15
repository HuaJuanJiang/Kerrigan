-- redis连接模块
-- 需要注意：
--   redis基础连接配置需要在这里进行
local _M = {}
local redis       = require"resty.redis"
local cj          = require"cjson"
local redis_host  = "127.0.0.1"
local redis_port  = "16161"
local redis_auth  = "asdfFWEFNn"
local redis_alive = 300 
local dict_alive  = 300 
local INFO        = ngx.INFO
local ERR         = ngx.ERR
local log         = ngx.log
--redis:set_timeout(1000)

--连接redis
function _M.redis_conn()
    local redis_obj = redis:new()
    local conn_res, _ = redis_obj:connect(redis_host,redis_port)
    if not conn_res then
        return
    end 
    local auth_res, _ = redis_obj:auth(redis_auth)
    if not auth_res then
        return
    end 
    return redis_obj
end

--断开redis
function _M.redis_close(redis_obj)
    pcall(function() redis_obj:close()end)
end
return _M
