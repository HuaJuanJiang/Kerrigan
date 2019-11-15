-- 私网ip判断模块
-- 包含对特殊地址的判断
local _M = {}
local special_ip={
    "127.0.0.1",
    "0.0.0.0",
    "localhost"
}

function _M.prip(ip)
    local a, b, c, d = string.match(ip, '(%d+)%.(%d+)%.(%d+)%.(%w+)')
    --ngx.log(ngx.INFO,'a:',a,'b:',b,'c:',c,'d:',d)
    local a = tonumber(a)
    local b = tonumber(b)
    local c = tonumber(c)
    local d = tonumber(d)
    -- A类地址：10.0.0.0～10.255.255.255
    if a == 10 then
        return 1
    end
    -- B类地址：172.16.0.0 ～172.31.255.255
    if a == 172 then
        if 16 <= b and b <= 31 then
            return 1
        end
    end
    -- C类地址：192.168.0.0～192.168.255.255
    if a == 192 and b == 168 then
        return 1
    end
    -- special_ip
    for num = 1, #special_ip do
        if special_ip[num] == ip then
            return 1
        end
    end
end
return _M

