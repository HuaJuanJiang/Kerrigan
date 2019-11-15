-- str to table ，支持将字符串转换成table类型，需要注意的是
-- 非数值型的str才可以转换为table，可以通过另外一个模块tts
-- table to str 来进行验证，两者是可以相互转换的，一般数值型
-- table都是通过cjson模块来转换的。
local _M = {}

function _M.stt(str)
    if str == nil or type(str) ~= "string" then
        return
    end
    return loadstring("return " .. str)()
end

return _M
