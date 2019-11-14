-- Copyright © (C) Zhendong (DDJ)
-- up serevr 节点状态同步定时器
--
-- 更新日期
--  2019.04.12 11:47
--          “up server sync”定时器的作用是将每个title当中存在的upstream list
--      当中的“status=up”的server挑选出来，通过拼接成类似下面的数据类型：
--      up_vmims: {"w_rr", "{'192.168.211.130', '6666', '1'}", "{'192.168.211.131', '8888', '2'}"}
--      其中第一个参数是algo，就是负载均衡算法，轮询：“rr”；加权轮询：“w_rr”；ip-hex：“ip_hex”；加权ip-hex：“w_ip_hex”
--      但是需要注意的是，在定时器内部会根据已经为“up”状态的server的权重是否为一样，
--      如果一样那么就标记“w_rr”，因为在upstream connector连接器当中，加权轮询和普通的
--      轮询算法是不一样的，现在只需要获取到列表直接进行不同算法的分配就好了，
--      所做的一切都是减轻upstream connector连接器的负载，提高单次访问的性能。
--
--  2019.04.13 16:56
--    三目运算符
--    (a and {b} or {c})[1]
--    a = ture  ---> b
--    a = false ---> c
--    对应Lua中的a and b or c
--        b = true
--            a = true
--                a and b –> true
--                b or c –> b
--            a = false
--                a and b –> false
--                b or c –> c
--        b = false
--            a = true
--                a and b –> false
--                b or c –> c
--            a = false
--                a and b –> false
--                b or c –> c 
--        可以看到当b = false时，Lua模拟的a and b or c始终返回c并不能还原三目运算符的原貌。
--    如何能保证a and b or c中b为真或者b不产生歧义呢？
--      1.nd的运算优先级高于or，简单的改变运算顺序并没有用。
--      2.这时就想到了lua中万能的table，能不能把a,b,c都放到table中来改变b的存在呢？要注意{nil}也是一个为true的对象。
--    a,b,c都替换为table：{a} and {b} or {c}。
--      3.三目运算中a是条件，结果是b或者c。其实a并不需要放入table中，否则{a}就始终为true了，失去了条件的意义。而{b} or
--    {c}的结果也必然是一个table，该table只有一个元素。那么通过[1]即可访问。
--      4.综上所述，更一般化的Lua三目运算为：(a and {b} or {c})[1]
--
--  2019.04.16 16:46
--  数据类型: {
--                "pool": [
--                    [
--                        "127.0.0.1",
--                        "8889",
--                        "1"
--                    ],
--                    [
--                        "192.168.211.134",
--                        "8081",
--                        "1"
--                    ]
--                ],
--                "algo": "ip_hex"
--            }
--          这次的更新是针对加权轮询算法，基于nginx的平滑加权轮询算法，这个算法的基本原理是：
--
-- 　　每个服务器都有两个权重变量：
--
--    a：weight，配置文件中指定的该服务器的权重，这个值是固定不变的；
--    b：current_weight，服务器目前的权重。一开始为0，之后会动态调整。
--
--        每次当请求到来，选取服务器时，会遍历数组中所有服务器。对于每个服务器，
--    让它的current_weight增加它的weight；同时累加所有服务器的weight，并保存为total。
--    遍历完所有服务器之后，如果该服务器的current_weight是最大的，就选择这个服务器处理
--    本次请求。最后把该服务器的current_weight减去total。
--          upstream cluster {    
--                server a weight=4;    
--                server b weight=2;    
--                server c weight=1;    
--          }    
--        按照这个配置，每7个客户端请求中，a会被选中4次、b会被选中2次、c会被选中1次，
--    且分布平滑。
--    通过上述过程，可得以下结论：
--    a：7个请求中，a、b、c分别被选取了4、2、1次，符合它们的权重值。
--    b：7个请求中，a、b、c被选取的顺序为a, b,a, c, a, b, a，分布均匀，权重大的后端a没有被连续选取。
--    c：每经过7个请求后，a、b、c的current_weight又回到初始值{0, 0,0}，因此上述流程是不断循环的。
--    注：切换每个加上自己权重，选中的减去总的权重
--
--  更新日期
--      2019.07.03 18:43
--          全局变量的修改
--          去除了之前的写法，现在改用正常的局部变量调用方法，但是之前的方法会做备份


local ctc           = require"resty.lepai.basic.composite_tab_c"
local stt           = require"resty.lepai.basic.str_to_table"
local tts           = require"resty.lepai.basic.table_to_str"
local sec           = require"resty.lepai.basic.get_ngx_sec"
local cj            = require "cjson"
local delay         = ngx.req.get_uri_args()["delay"]
local ups_zone      = ngx.shared['upstream_zone']
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local null          = ngx.null
local env           = setfenv
local timer         = ngx.timer.at
local timers        = ngx.timer.every
local wait          = ngx.thread.wait
local thread        = ngx.thread.spawn
local pairs         = pairs
local setmetatable  = setmetatable

local _, delay = 
pcall(function()
    if tonumber(delay) ~= 1 then 
        return 1
    end
    return tonumber(delay) 
end)

-- 加权处理函数，依据nginx自身的C语言实现的加权server列表
-- 处理方法的实现
local function w_list_factory(w_totle, pools, pool_number)
    local list = {}
    local init = {}
    local table = table
    local pools = pools
    local w_totle = w_totle
    local pool_number = pool_number
    for num = 1, w_totle do
        -- 设置初始值
        if num == 1 then
            for i = 1, pool_number do
                table.insert(init, 0)
            end
        end
        -- 增加权重到初始值
        for n = 1, pool_number do
            init[n] = pools[n][3] + init[n]
        end
        -- 比对大小
        local max = init[1]
        local max_num
        for nu = 1, pool_number do
            if max < init[nu] then
                max = init[nu]
                max_num = nu
            end
        end
        -- 确认最大值
        for nums = 1, pool_number do
            if init[nums] == max then
                max_num = nums
            end
        end
        init[max_num] = init[max_num] - w_totle
        table.insert(list, pools[max_num])
    end
    log(INFO, 'after weight list: ', cj.encode(list))
    return list
end

local function upserver(upstream)
    local upstreams = ups_zone:get(upstream)
    if not upstreams then
        log(INFO, '[ INFO ]: '
        ..'[ '..upstream..' ] '
        ..'NOT EXIST IN UPS ZONE ！！！')
        return
    end
    -- 提取upstream的status=up的server
    local upstreams =cj.decode(upstreams)    
    local algo = upstreams['algo']
    local pool = upstreams['pool']
    local w_totle = 0 
    local up_tab = {}
    local pools = {}
    for num = 1, ctc.ctco(pool) do
        local server = 'server'..num
        local ip_port = pool[server]['ip_port']
        local status = pool[server]['status']
        local weight = pool[server]['weight']
        if status ~= 'down' then
            local len = string.len(ip_port)
            local spear = string.find(ip_port, ':')
            local ip = string.sub(ip_port, 1, spear - 1)
            local port = string.sub(ip_port, spear + 1, len)
            local new_table = {}
            table.insert(new_table, ip) 
            table.insert(new_table, port)
            table.insert(new_table, weight)
            table.insert(pools, new_table)
            w_totle = w_totle + tonumber(weight)
        end 
    end 
    up_tab['pool'] = pools
    local pool_number
    pool_number = ctc.ctco(pools)
    local pool = pools
    if pool_number == 0 then
        log(INFO, '[ INFO ]: '
        ..'[ '..upstream
        ..' ] DONOT HAVA UP SERVER ！！！')
        return
    end
    if pool_number == 1 then
        algo = 'rr'
    elseif pool_number == 2 then
        if pool[1][3] == pool[2][3] then
            algo = (algo == 'rr' and {'rr'} 
            or {'ip_hex'})[1]
        else
            algo = (algo == 'rr' and {'w_rr'} 
            or {'w_ip_hex'})[1]
        end
    else
        local standard = pool[1][3]
        for num = 1, pool_number do
            local nums = (standard == pool[num][3] 
            and {} or {'1'})[1]
        end
        if nums then
            algo = (algo == 'rr' and {'w_rr'} 
            or {'w_ip_hex'})[1]
        else
            algo = (algo == 'rr' and {'rr'} 
            or {'ip_hex'})[1]
        end
    end
    up_tab['algo'] = algo
    if algo == 'w_rr' or algo == 'w_ip_hex' then
        -- 对于有加权的server列表，一般会经过处理得到一个server完全列表
        -- 并且添加到up_tab当中，例如 
        -- 加权server:
        -- ew_10: {"algo":"w_rr","pool":[["127.0.0.1","5022","7"],["127.0.0.1","9633","2"]],
        -- 加权后的完整访问列表:
        -- 分布水平很均衡
        -- "weight_list":[["127.0.0.1","5022","7"],["127.0.0.1","5022","7"],["127.0.0.1","9633","2"],
        -- ["127.0.0.1","5022","7"],["127.0.0.1","5022","7"],["127.0.0.1","5022","7"],["127.0.0.1","9633","2"],
        -- ["127.0.0.1","5022","7"],["127.0.0.1","5022","7"]]}
        up_tab['weight_list'] =
        w_list_factory(w_totle, pools, pool_number)
    end
    local up_tab = cj.encode(up_tab)
    log(INFO, upstream, ': ', up_tab)
    ups_zone:set('up_'..upstream, up_tab)
    -- log(ERR, 'ERR: ', info)
end

-- upserver收集主函数
local function upserver_sync()
    local upstream_list = 
    ups_zone:get('upstream_list')
    -- log(INFO, 'upstream_list: ', upstream_list)
    if upstream_list then
        local upstream_list = stt.stt(upstream_list)
        if #upstream_list >= 1 then
            for num = 1, #upstream_list do
                thread(upserver, upstream_list[num])
            end
        end
    else
        log(INFO, '[ INFO ]: '
        ..'UPSERVER SYNC TIMER: '
        ..'upstream list is NILL ！！！')
    end
end

--upserver_sync()
timers(delay, upserver_sync)

