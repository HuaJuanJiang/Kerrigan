--ip合法性判断模块
local _M = {}

-- 第二种IP合法判断方式
function _M.ji(f_white_ip)
    local white_ip_table = {}
    local a, b, c, d = 
    string.match(f_white_ip, 
    '(%d+)%.(%d+)%.(%d+)%.(%w+)')
    local fin_the_ip = tonumber(d)
    if not a 
    or not fin_the_ip then
        return 1
    end
    local white_ip_new = 
    a..'-'..b..'-'..c..'-'..d
    table.insert(white_ip_table, white_ip_new)
    local white_ip_first_num = 
    string.find(f_white_ip, '%.', 1)
    local white_ip_first = 
    string.sub(f_white_ip, 1, 
    white_ip_first_num - 1 )
    local if_white_ip = tonumber(white_ip_first)
    if not if_white_ip then
        return 1
    end
    local judge_ip = split(white_ip_new, '-')
    if tonumber(a) == 0 
    or tonumber(a) >= 255 
    or tonumber(b) >= 255 
    or tonumber(c) >= 255 
    or tonumber(d) >= 255 then
        return 1
    end
    if not judge_ip then
        return 1
    end
end

-- 第一种IP合法判断方式
function _M.ji_for_other(ip)
    local white_ip_table = {}
    local a, b, c, d = 
    string.match(ip, 
    '(%d+)%.(%d+)%.(%d+)%.(%w+)')
    local fin_the_ip = tonumber(d)
    if not a
    or not fin_the_ip then
        return 1
    end
    local white_ip_new = 
    a..'-'..b..'-'..c..'-'..d
    table.insert(white_ip_table, white_ip_new)
    local white_ip_first_num = 
    string.find(ip, '%.', 1)
    local white_ip_first = 
    string.sub(ip, 1, 
    white_ip_first_num - 1 )
    local if_white_ip = 
    tonumber(white_ip_first)
    if not if_white_ip then
        return 1
    end
    if tonumber(a) == 0 
    or tonumber(a) >= 255 
    or tonumber(b) >= 255 
    or tonumber(c) >= 255 
    or tonumber(d) >= 255 then
        return 1
    end
end

return _M
