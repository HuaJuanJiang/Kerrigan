-- 获取远程地址
-- get remot
-- 2019.07.04 09:38

-- 经过测试，通过头部信息获取远程地址的方式并不可取，会有误差
-- local ip_headers = ngx.req.get_headers()
-- local get_remote_addr = ip_headers['remote_addr'] or ip_headers['x-real-ip']
-- 将弃用
-- 两个参数分别是“ngx.var.remote_addr”和“ngx.var.http_x_forwarded_for”
-- 函数示例用法：
-- local ri = require"resty.lepai.basic.remote_ip"
-- local remote_ip = ngx.var.remote_addr
-- local x_forwarded_for = ngx.var.http_x_forwarded_for
-- local remote_ip = ri.remote_ip(remote_ip, x_forwarded_for)

-- 2019.08.19 10:43
--      修复bug，没有引用private_ip_judge模块。导致报错

local pij = require"resty.lepai.basic.private_ip_judge"
local log  = ngx.log
local INFO = ngx.INFO
local ERR  = ngx.ERR

local _M = {}
function _M.remote_ip(remote_ip, x_forwarded_for)
    local remote_ip = remote_ip
    local x_forwarded_for = x_forwarded_for
    log(INFO,'[ INFO ]: ',
    ' Remote_ip: { ',remote_ip,
    ' }    X_Forwarded_For: { ',x_forwarded_for,' }')
    if not x_forwarded_for then
        return remote_ip
    end 
    -- 测试数据
    --local x_forwarded_for = '192.168.101.1, 192.168.101.2, 192.168.101.3'
    local len = string.len(x_forwarded_for)
    local point =  string.find(x_forwarded_for, ',' )
    --防止出现x_forwarded_for有多个ip，导致截取ip失败
    if point then
        local forwarded_ip = string.sub(x_forwarded_for, 0, point - 1)
        -- judge ip if private
        if pij.prip(forwarded_ip) then
            return remote_ip
        end 
        return forwarded_ip
    else
        local forwarded_ip = string.sub(x_forwarded_for, 0, len)
        if pij.prip(forwarded_ip) then
            return remote_ip
        end 
        return forwarded_ip
    end 
end

return _M

