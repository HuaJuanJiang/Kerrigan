-- Copyright © (C) Zhendong (DDJ)
-- 轮询算法
-- 更新日期：
--    2019.04.16 15:20
--          轮询算法，分为普通的轮询和加权轮询
--          其中普通轮询算法还是比较简单的，可以通过对server的数量对
--      递增数字进行取余，来确定转发的后端服务器。
--          加权轮询算法设计的比较复杂，这参考了nginx自带的平滑加权轮询
--      算法的方法，这里我把算法的核心部分放在定时器上，因为要做很多的
--      for循环，所以对于追求速度的连接器connector来说，省去这部分功能

local ctc           = require"resty.lepai.basic.composite_tab_c"
local stt           = require"resty.lepai.basic.str_to_table"
local tts           = require"resty.lepai.basic.table_to_str"
local ba            = require"ngx.balancer"
local cj            = require "cjson"
local ups_zone      = ngx.shared['upstream_zone']
local say           = ngx.say
local exit          = ngx.exit
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local pairs         = pairs
local setmetatable  = setmetatable

local _M = { 
    _AUTHOR = 'zhendong 2019.04.13',
    _VERSION = '0.4.13',   
}

local mt = { __index = _M }

function _M.new()
    local self = { 
        _index = table  
    }   
    return setmetatable(self, mt) 
end

-- round robin
-- 轮询算法
-- the_table: {"{'192.168.211.130', '6666', '1'}", "{'192.168.211.131', '8888', '2'}"} 
-- num: server的数量
-- title: title名字
local function rr(title, upserver)
    --log(INFO, 'rr', cj.encode(upserver))
    local mark = 'rr_mark_'..title
    local mark_p =
    ups_zone:get(mark)
    if not mark_p then
        ups_zone:set(mark, 0)
        mark_p = 0
    end
    -- 进行选择，是第一个server还是第二个server
    local the_num = (mark_p % ctc.ctco(upserver)) + 1
    local ip = upserver[the_num][1]
    local port = upserver[the_num][2]
    local mark_p = mark_p + 1
    ups_zone:set(mark, mark_p)
    return ip, port
end

-- 加权轮询列表，真正的加权轮询算法实现是在
-- upserver_sync_timer定时器当中实现的，
-- 这里只是把列表进行记录以及循环
-- 例如下面
-- "weight_list":[["127.0.0.1","5022","7"],["127.0.0.1","5022","7"],["127.0.0.1","9633","2"],
-- ["127.0.0.1","5022","7"],["127.0.0.1","5022","7"],["127.0.0.1","5022","7"],["127.0.0.1","9633","2"],
-- ["127.0.0.1","5022","7"],["127.0.0.1","5022","7"]]}
local function rr_weight(title, weight_list)
    local mark = 'w_rr_mark_'..title
    local list_num =
    ups_zone:get(mark)
    if not ups_zone:get(mark) then
        list_num = 1
        ups_zone:set(mark, list_num)
    else
        if list_num == ctc.ctco(weight_list) then
            list_num = 1
            ups_zone:set(mark, list_num)
        else
            list_num = list_num + 1
            ups_zone:set(mark, list_num)
        end
    end
    local ip = weight_list[list_num][1]
    local port = weight_list[list_num][2]
    return ip, port
end

-- 入口函数
function _M.rr(title, algo, upserver, weight_list)
    local title = title
    if algo == 'rr' or algo == 'ip_hex' then
        return rr(title, upserver)
    else
        return rr_weight(title, weight_list)
    end
end

return _M
