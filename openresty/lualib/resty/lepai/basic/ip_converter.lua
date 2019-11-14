-- ip转换器
-- 2019.03.21 16:34
local _M = {}

-- 例如：{'192.168.101.59','192.168.101.61'} --> 192.168.101.59-192.168.101.61
-- 解码器
function _M.encode(tab, delim)
    local str = table.concat(tab, delim)
    return str
end

-- 例如：'192.168.101.59-192.168.101.61' --> {'192.168.101.59','192.168.101.61'}
-- 编码器
function _M.decode(str_tab, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end 
    local start = 1 
    local t = {}
    while true do
        local pos = string.find (str_tab, delim, start, true) 
        if not pos then
          break
        end 
        table.insert (t, string.sub (str_tab, start, pos - 1)) 
        start = pos + string.len (delim)
    end 
    table.insert (t, string.sub (str_tab, start))
    return t
end

return _M
