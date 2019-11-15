-- 对于复合型table进行元素统计，例如：
--[[
"pool": {
    "server1": {
        "ip_port": "127.0.0.1:8889",
        "status": "down",
        "weight": "1"
    },
    "server2": {
        "ip_port": "127.0.0.1:9999",
        "status": "up",
        "weight": "1"
    },
    "server3": {
        "ip_port": "192.168.211.134:8081",
        "status": "down",
        "weight": "1"
    },
    "server4": {
        "ip_port": "192.168.211.132:8080",
        "status": "up",
        "weight": "1"
    }
]]
-- 统计pool当中的server数量，因为lua自带的一个属性 “#pool”
-- 经过坑爹测试之后，发现它只能统计普通数组元素个数，
-- 也就是没有递归的深层次数组，想现在的pool，直接导致无法统计
-- 个数，所以这个基础函数就是为了统计复合数组总共有多少元素和
-- 复合数组最外层元素的个数，例如现在的需求就是统计pool当中server
-- 的个数，其实server下面有多少元素我目前这个场景是不关心的，但是
-- 不能保证后面的场景不会用到这个功能，因此对外将提供两个函数：
-- 统计复合数组最外层元素个数
-- 统计复合数组全部已有元素个数
local _M = {}
local cj = require "cjson"

-- 最外层元素统计
function _M.ctco(tab)
    if not tab then
        return
    end
    if type(tab) ~= 'table' then
        return
    end
    local tabs = cj.encode(tab) 
    local num = 0
    for k, v in pairs(tab) do
        num = num + 1
    end
    return num
end

-- 全部元素统计
function _M.ctca(table)
end

return _M
