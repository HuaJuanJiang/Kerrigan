-- Copyright © (C) Zhendong (DDJ)
--[[2019.11.29
  最近更新：
  2019.03.14 17:54
        注意：在这个功能模块当中，存在一个问题就是redis是否在线的问题，当准备添加一个upstream
    列表，如果redis在线，那么原有列表要以谁为主，并且同步更新到其他的地方，这里选择了以redis
    当中信息为准，因为在redis在线的情况下，定时器会定时向dict推送最新配置，那么意味着redis
    当中的数据是最新的，后面的所有代码都会优先取redis当中值，更新之后反推送到redis和dict，
    并且更新 upstream_list_update_time 数据
    当redis无法连接时，只会在获取get数据做出判断，set的写入数据redis和dict同时写，哪怕redis没有连接

  2019.03.22 09:56
        最新更新，将redis和dynamic upstream 功能完全分开，明确定时器的功能，将redis->dict，dict->redis
    的功能全部交给定时器，使得在没有redis的情况下，动态负载均衡依旧可以使用，也使得下面的代码更加
    简洁，便于维护。

  2019.04.01 11:47
        这次更新的内容是针对定时器新的逻辑，对删除选项进行单独修改，引入“并集”概念，详细
    需要到black&white IP 定时器查看

  2019.04.02 15:18
        今天在定时器的部分又遇到一个问题，那就是无法详细得知一个title体是否已经修改，因此在
    不破坏代码逻辑的i情况下，需要为每个title设计一个时间戳，只要在主定时器执行的过程当中，
    把每个循环到的title进行时间戳进行检查，只要没有或者不相等，就将其进行覆盖，这样即使进行
    了很小的变动，都可以立马通过定时器传递到redis当中
]]

local redis         = require"resty.lepai.basic.redis_conn"
local stt           = require"resty.lepai.basic.str_to_table"
local tts           = require"resty.lepai.basic.table_to_str"
local ctc           = require"resty.lepai.basic.composite_tab_c"
local sm            = require"resty.lepai.basic.send_message"
local sec           = require"resty.lepai.basic.get_ngx_sec"
local rh            = require"resty.lepai.basic.random_hex"
local ji            = require"resty.lepai.basic.judge_ip"
local cj            = require "cjson"
local upstream_zone = ngx.shared['upstream_zone']
local say           = ngx.say
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local pairs         = pairs
local setmetatable  = setmetatable

local _M = {
	_AUTHOR = 'zhendong 2018.11.29',
	_VERSION = '0.11.29',	
}
local mt = { __index = _M }

--继承模块，这里的思想就是，因为它是new方法，
--意味着创建的这个对象可以调用这个模块当中所有的函数
--但是不调用new方法去初始化对象的话，就无法调用其它方法，
--上面的local mt = { __index = _M }，
--意味着这个文件当中的所有函数都被new方法继承了！
function _M.new()
	local self = {
		_index = table	
	}
	return setmetatable(self, mt) 
end

--将获取到信息编码成json格式
local function upstream_module(
    ip_port, 
    weight, 
    algo, 
    status, 
    title)
    local sec = sec.sec()
	local kfc = {}
	local server = {}
	server["ip_port"] = ip_port 
	server["weight"] = weight
	server["status"] = status
	local pool = {}
	pool["server1"] = server
	kfc["title"] = title
	kfc["algo"] = algo 
	kfc["pool"] = pool
	kfc["timestamp"] = sec
	local kfc = cj.encode(kfc)
	--编码成为str
	return kfc
end 

--[[

数据模型I
{
    "algo": [
	"ip_hex",
	"rr"
    ],
    "status": [
	"up",
	"down"
    ],
    "weight": "check"
    "ip_port": "check",
}


数据模型II
{
    "title": "vmims"
    "algo": "ip_hex",
    "timestamp": "135819841851",
    "pool": {
        "server1": {
            "ip_port": "127.0.0.1:8889",
            "status": "down",
            "weight": "1"
        },
        "server2": {
            "ip_port": "127.0.0.1:9999",
            "status": "up",
            "weight": "2"
        },
        "server3": {
            "ip_port": "127.0.0.1:10000",
            "status": "nohc",
            "weight": "3"
        }
    },
}

]]
-- 用于对比已存在的key，将它储存成这个格式，后面方便添加。
-- 当需要对存在的模板进行修改的时候，把标准信息存储在这里
-- 用于对输入数据进行准确性比对
local function modify_compare_template()
	local table = {}
	local table_algo = {}
	local table_status = {}
	table_algo[1] = 'ip_hex'
	table_algo[2] = 'rr'
	table_status[1] = 'up'
	table_status[2] = 'down'
	table_status[2] = 'nohc'
	table['algo'] = table_algo
	table['status'] = table_status
	table['ip_port'] = 'check'
	table['weight'] = 'check'
	return table
end

--数字判断
local function if_num(num)
	local res = tonumber(num)
	if not res then
		say('数字不合法')
		return 1
	end
end

-- 判断key是否在upstream_zone
-- 并get到（返回字符）
local function zone_get(key)
    return upstream_zone:get(key)
end
_M.zone_get = zone_get

--插入 key val 到 upstream_zone
local function zone_set(key, val)
    local ok, err = 
    upstream_zone:set(key, val)
    if not ok then
        pcall(function()
        say('[ INFO ]: '
        ..'upstream zone INTSER ERR: [ ', 
        err, ' ]')
        end)
        return 1
    end
    return 
end
_M.zone_set = zone_set

-- 判断title是否存于 upstream list 和
-- dict 空间（删除，修改，查看）需要同时满足（返回字符）
local function title_exist(title)
    local upstream_list = 
    zone_get('upstream_list')
    if not upstream_list then
        return
    end
    local upstream_list = stt.stt(upstream_list)
    local title_val = zone_get(title)
    if not title_val then
        say('[ INFO ]: '
        ..' [ ', title, 
        ' ] MAYBE NOT EXIST TO upstream dict ')
        return
    end
    for num = 1, #upstream_list do
        if upstream_list[num] == title then
            return title_val
        end
    end
    say('[ INFO ]: '
    ..'title MAYBE NOT EXIST TO "upstream list"')
    return
end

-- 判断参数合法性
-- 是否为空
local function add_parameter_judgment(
    ip_port, 
    weight, 
    algo, 
    status, 
    title)
	--判断空值
	if ip_port == nil 
    or weight == nil 
    or algo == nil 
    or status == nil 
    or title == nil 
	or ip_port == ''
    or weight == '' 
    or algo == ''
    or status == ''
    or title == '' then
		say('[ INFO ]: '
        ..'The parameter CANNOT BE EMPTY ！！！')
		return 1
	end
	--ip
	local len = string.len(ip_port)
	local spear = string.find(ip_port, ':')
	if not spear then
		say('[ INFO ]: '
        ..'spear " '..ip_port..' " ILLEGAL ！！！')
		return 1
	end
	local ip = string.sub(ip_port, 1, spear - 1)
	local port = string.sub(ip_port, spear + 1, len)
	local res = ji.ji_for_other(ip)
	if res then
		say('[ INFO ]: '
        ..'ip " '..ip..' " ILLEGAL ！！！')
		return 1
	end
	--判断数字
	local if_num_port = if_num(port)
	local if_num_weight = if_num(weight)
	if if_num_port 
    or if_num_weight then
		say('[ INFO ]: '
        ..'port " '..port..' " or weight " '
        ..weight..' " is NOT NUMBER ！！！')
		return 1 
	end
	--port
	if tonumber(port) < 1024 
    or tonumber(port) > 65535 then
		say('[ INFO ]: '
        ..'port " '..port
        ..' " RANGE ILLEGAL ！！！'..'\r\n'
        ..'[ INFO ]: '
        ..'port range: 1024 < port < 65535 ')
		return 1
	end
	--weight
	if tonumber(weight) < 1 
    or tonumber(weight) > 10 then
		say('[ INFO ]: '
        ..'weight " '..weight
        ..' " RANGE ILLEGAL ！！！'..'\r\n'
        ..'[ INFO ]: '
        ..'weight range: 1 < weight < 10 ')
	end
	--algo
	if algo ~= 'rr' 
    and algo ~= 'ip_hex' then
		say('[ INFO ]: '
        ..'algo " '..algo
        ..' " ILLEGAL ！！！'..'\r\n'
        ..'[ INFO ]: '
        ..'algo: "rr(round robin)" and "ip_hex"')
		return 1
	end
	--status
	if status ~= 'up' 
    and status ~= 'down' 
    and status ~= 'nohc' then
		say('[ INFO ]: '
        ..'status " '..status
        ..' " ILLEGAL ！！！'..'\r\n'
        ..'[ INFO ]: '
        ..'status: "up" and "down" and "nohc" ')
		return 1 
	end
end

-- 判断设置title
-- 添加title到 upstream list
-- 下面有三种情况
local function title_insert(title)
	local res_get_up_list = 
    zone_get('upstream_list')
    -- upstream list 不存在
    --say(res_get_up_list)
	if not res_get_up_list then
        say('[ INFO ]: '
        ..'CAN NOT  find upstream_list key'
        ..' [ '..title..' ] '
        ..' form dict ！！！ '
        ..'so CREATE')
        local up_list_table = {}
        table.insert(up_list_table, title)
        local str_up_list_table = 
        tts.tts(up_list_table)
        zone_set('upstream_list', 
        str_up_list_table)
        return
	end
    -- upstream list 存在，插入新值
    local table_res_get_up_list = 
    stt.stt(res_get_up_list)
    -- 判断title是否重复存在于upstream_list
    local res = title_exist(title)
    if res then
        return
    end
    table.insert(table_res_get_up_list, title)
    local str_up_list = 
    tts.tts(table_res_get_up_list)
    zone_set('upstream_list',str_up_list)
    say('[ INFO ]: '
    ..' TITLE: [ '..title
    ..' ] SUCCESS ADD to dict ！！！')
    return
end

-- 判断title作为key，ip等信息作为val
-- 将title设置为key，然后对其中的信息进行填充，
-- 可以对比模板进行查看
local function title_insert_dict(
    ip_port, 
    weight, 
    algo, 
    status, 
    title)
	local get_title_key = 
    zone_get(title)
    if not get_title_key then
        -- 因为新建一个title，所以所有的值已经在前面进行判断 
        -- 是符合条件的，现在只需要将它们按照模板配置进行填充
        -- 写入dict
        local up_list = 
        upstream_module(
        ip_port, 
        weight, 
        algo, 
        status, 
        title)
        --say('[ INFO ]: '
        --..'Create title [ '..title..' ]'..'\r\n'
        --..'server list: [ '..up_list..' ] ')
        local sec = sec.sec()
        zone_set(title, up_list)
        zone_set(
        'upstream_list_update_time', 
        sec)
        return
    end
    return 1 
end

-- 插入新server
-- 指的是在添加一个title以后，一个title可以有多个server，那么就需要
-- 在有需求的时候任意添加一个server或者删除某个server 
local function server_insert(
    ip_port, 
    weight, 
    status, 
    title)
    local get_title = zone_get(title)
    if not get_title then
        return
    end
	local table_get_title = 
    cj.decode(get_title)
    local pool = table_get_title['pool']
    for pool_num = 1, ctc.ctco(pool) do
        local server = 'server'..pool_num
        local current_server = pool[server]
        local current_server = cj.encode(current_server)
        local current_server_ip_port = pool[server]['ip_port']
		if current_server_ip_port == ip_port then
			say('[ INFO ]: '
            ..'SORRY  ip_port:'
            ..'[ '..ip_port..' ] is REPET ！！！'..'\r\n'
            ..'Server: '..current_server..'}')
			return
		end	
    end
	-- 开始插入新server
    -- 在经过上面的判断以后，认为输入的数值是符合条件的
    -- 可以进行server添加
    local server = {}
	server["ip_port"] = ip_port 
	server["weight"] = weight
	server["status"] = status
    local server_next = 'server'..ctc.ctco(pool) + 1
    pool[server_next] = server
    local server = cj.encode(server)
    table_get_title['pool'] = pool
    local sec = sec.sec()
    table_get_title['timestamp'] = sec
	local str_set_title = cj.encode(table_get_title)
    zone_set('upstream_list_update_time', sec)
    zone_set(title, str_set_title)
    say('[ INFO ]: '
    ..'TITLE [ '..title
    ..' ] add the NEW SERVER'..'\r\n'
    ..'SERVER: '..server..'}')
end

-- 删除title
-- 从upstream删除一个title
local function title_delete(title)
    local upstream_list = zone_get('upstream_list')
    if not upstream_list then
        return
    end
	local upstream_list = stt.stt(upstream_list)
    -- 判断title
    local res = title_exist(title)
    if not res then
        return
    end
	new_upstream_list = {}
    for num = 1, #upstream_list do
        if upstream_list[num] == title then
            zone_set(title, nil)
        else
            table.insert(
            new_upstream_list, 
            upstream_list[num])
        end
    end
    if #new_upstream_list == #upstream_list then
        say('[ INFO ]: '
        ..'title : [ '..title
        ..' ] NOT EXIST ！！！')
        return
    end
    local upstream_list = tts.tts(new_upstream_list)
	local sec = sec.sec()
	zone_set('upstream_list_update_time', sec)
	zone_set('upstream_list', upstream_list)
    say('[ INFO ]: '
    ..' TITLE: [ '..title
    ..' ] SUCCESS DELETE ！！！')
    pcall(function() 
    local lepai = redis.redis_conn()
    lepai:del(title)
    lepai:set('upstream_list_update_time', sec)
    lepai:set('upstream_list', upstream_list)
    local cluster_state = lepai:get('cluster_state')
    local cluster_state = cj.decode(cluster_state)
    local num = ctc.ctco(cluster_state['node']) - 1
    lepai:set('DEL_upstream_point', num)
    redis.redis_close(lepai)
    end)
end

-- 删除某个server
-- 和刚刚功能相反，这里是要删除一个server，当title有
-- 多个server，但是由于有情况，不想用了，那么就可以通过
-- 这个来移除特定的server，通过server后面的标识来区分
local function server_delete(title, server_code)
    local server_code = tonumber(server_code)
    local upstream_list = zone_get('upstream_list')
    if not upstream_list then
        return
    end
    local upstream_list = stt.stt(upstream_list)
    -- 判断title
    local get_title = title_exist(title)
    if not get_title then
        return
    end
    local get_title = cj.decode(get_title)
    local pool = get_title['pool'] 
    local delete_server = 'server'..server_code
    local delete_server_body = pool[delete_server]
    if not delete_server_body then
		say('[ INFO ]:'
        ..'Server [ '..delete_server
        ..' ] is NOT EXIST ！！！')
		return
    end
    -- 删除server前提条件是至少有两个server
    -- 不支持将所有server删除，否则title就没有意义
    if ctc.ctco(pool) == 1 then
        --local server1 = cj.encode(pool['server1'])
        local server1 = pool['server1']
        local server1 = cj.encode(server1)
		say('[ INFO ]: '
        ..'The title [ '..title
        ..' ] has a server at LEASTE '
        ..'\r\n[ INFO ]: '
        ..' FAILED TO DELETE " server 1 " : '
        ..' '..server1..'} ')
        return
    end
    -- 删除server，并且重新排序，倘若有5个server，
    -- 当删除server3以后，需要原先后面的server4
    -- 挪到前面变成server3，也就是对名称进行重新的
    -- 定义，因此称之为重新排序
    new_pool = {}
    for num = 1, ctc.ctco(pool) do
        local pool_server = 'server'..num
        if num > server_code then
            local old_pool_server = 'server'..num
            local pool_server = 'server'..num - 1
            new_pool[pool_server] = 
            pool[old_pool_server]
        elseif num < server_code then
            new_pool[pool_server] = 
            pool[pool_server]
        end
    end
    local delete_server_body = 
    cj.encode(delete_server_body)
    say('[ INFO ]: '
    ..'SUCCESS DELETE SERVER "'..'\r\n'
    ..delete_server..'" : [ '
    .. delete_server_body..'} ')
    get_title['pool'] = new_pool
    local sec = sec.sec()
    get_title['timestamp'] = sec
    local get_title = cj.encode(get_title)
	zone_set('upstream_list_update_time', sec)
	zone_set(title, get_title)
    pcall(function() 
        local lepai = redis.redis_conn()
        lepai:set('upstream_list_update_time', sec)
        lepai:set(title, get_title)
        redis.redis_close(lepai)
    end)
end

-- 判断修改key的合法性
-- 这个就用到了modify_compare_template() 函数
-- 将需要修改的值和模板信息列表的标准值进行比对，
-- 只要没有出现，就认为是非法的
local function modify_parameter_judgment(
    modify_key, 
    modify_val, 
    title, 
    server)
	--获得比值列表
	local template = modify_compare_template()	
    --判断空值
    if not title 
    or not server 
    or title == '' 
    or server == '' then
        say('[ INFO ]: '
        ..'The server [ ', server, ' ]  or title [ '
        ..title..' ] CANNOT BE EMPTY ！！！')
        return 1 
    end 
    if not modify_key 
    or not modify_val 
    or modify_key == '' 
    or modify_val == '' then
        say('[ INFO ]: '
        ..'modify_key [ ', modify_key, ' ], '
        ..'modify_val [ ', modify_val, ' ] '..'\r\n'
        ..'The parameter CANNOT BE EMPTY ！！！')
        return 1
    end 
	-- 检测status algo两个参数
    -- 逐个检测，因为无法判断用户到底是改什么数据
	--status and algo
    if modify_key == 'status' 
    or modify_key == 'algo' then
        local template_status = template['status']
        local template_algo = template['algo']
        --local template_status = tts.tts(template_status)
        --local template_algo = tts.tts(template_algo)
        --say(template_status, template_algo)
        -- 判断status
        for num = 1, #template_status do
            if template_status[num] == modify_val then
                return
            end
        end
        -- 判断algo
        for num = 1, #template_algo do
            if template_algo[num] == modify_val then
                return
            end
        end
        -- modify_key 为 “status” 或者 “algo” 但是显然
        -- modify_val 一条规则都没有撞上，说明不合法
        say('[ INFO ]: '
        ..'The parameter ILLEGAL ！！！'..'\r\n'
        ..'[ INFO ]: EXP: '..'status maybe "up"'
        ..', "down", "nohc"'..'\r\n'
        ..'[ INFO ]: EXP: '
        ..'algo maybe "rr", "ip_hex" ')
        return 1
    -- ip:port
    elseif modify_key == 'ip_port' then
		-- ip
		local len = string.len(modify_val)
		local spear = string.find(modify_val, ':')
		if not spear then
            say('[ INFO ]: '
            ..'IP:PORT [ '..modify_val..' ] '
            ..' DONOT HAVE SPEAR ！！！'..'\r\n'
            ..'[ INFO ]: '..'EXP: " 127.0.0.1:80 "')
			return 1
		end
		local ip = string.sub(modify_val, 1, spear - 1)
		local res = ji.ji_for_other(ip)
		if res then
            return 1
		end
        -- port 
		local port = string.sub(modify_val, spear + 1, len)
        local res = if_num(port) 
        if res then
            return 1
        end
        -- port range
        if tonumber(port) < 1024 
        or tonumber(port) > 65535 then
            say('[ INFO ]: '
            ..'port: " '..port
            ..' " is OUT RANGE ！！！'..'\r\n'
            ..'[ INFO ]: '..'port range : '
            ..'"1024 < ip < 65535 " ')
            return 1
        end
        -- 全部符合条件才可以执行到这一步
        return
	--weight
    elseif modify_key == 'weight' then
        local res = if_num(modify_val)
        if res then
            return 1
        end
        if tonumber(modify_val) < 1 
            or tonumber(modify_val) > 10 then
            say('[ INFO ]: '
            ..'weight: " '..modify_val
            ..' " is OUT RANGE ！！！'..'\r\n'
            ..'[ INFO ]: '..'weight range '
            ..': "1 <= weight <= 10" ')
            return 1
        end
        return
    end
    say('[ INFO ]: '
    ..'modify key [ ', modify_key, ' ] '
    ..' IS NOT EXIST ！！！')
    return 1
end

-- 修改server args
-- 修改server参数（需要经过上面的函数进行合法性判断）
local function server_modify(
    title, 
    server, 
    modify_key, 
    modify_val)
	local title_modify = 
    zone_get(title)
	if not title_modify then
		return
	end
    local title_modify = 
    cj.decode(title_modify)
    pool = title_modify['pool']
    -- algo 修改
    if modify_key == 'algo' then
        local old_modify = title_modify['algo']
        title_modify['algo'] = modify_val
        local sec = sec.sec()
        title_modify['timestamp'] = sec
        local title_modify = cj.encode(title_modify)
        zone_set('upstream_list_update_time', sec)
        zone_set(title, title_modify)
        say('[ INFO ]: '
        ..'Title has changed : '..'\r\n'
        ..'[ INFO ]: '..'Change "'..modify_key..'" from ['
        ..old_modify..'] ===> ['..modify_val..']')
    elseif modify_key == 'weight' 
    or modify_key == 'status' 
    or modify_key == 'ip_port' then
        -- 判断server存在
        local server_body = pool[server]
        if not server_body then
            say('[ INFO ]: '
            ..'Server [ '..server
            ..' ] is NOT EXIST ！！！'..'\r\n'
            ..'[ INFO ]: '..'EXP: "server1",'
            ..' "server2", "server3"....')
            return
        end
        local old_modify = server_body[modify_key]
        local old_server = cj.encode(server_body)
        server_body[modify_key] = modify_val
        pool[server] = server_body
        title_modify['pool'] = pool
        local sec = sec.sec()
        title_modify['timestamp'] = sec
        local new_serevr = cj.encode(server_body)
        local title_modify = cj.encode(title_modify)
        zone_set('upstream_list_update_time', sec)
        zone_set(title, title_modify)
        say('[ INFO ]: '
        ..'Server has changed : '..'\r\n'
        ..'[ INFO ]: '..'Old Server: '..old_server..'\r\n'
        ..'[ INFO ]: '..'New Server: '..new_serevr..'\r\n'
        ..'[ INFO ]: '..'Change "'..modify_key..'" from ['
        ..old_modify..'] ===> ['..modify_val..']')
    end
end

-- check server
-- 用来检查，一个或者多个
local function server_check(title)
    -- title 分成不同的情况
    -- title = upstream list
    local upstream_list = 
    zone_get('upstream_list')
    if not upstream_list then
        return
    end
    -- 做标记位
    -- 如果输入的 tilte 在 upstream list 当中找不到
    -- 无论输入的是什么，都会直接打印 upstream list
    local upstream_list = 
    stt.stt(upstream_list)
    postion = nil
    for num = 1, #upstream_list do
        if upstream_list[num] == title then
            postion = 1
        end
    end 
    -- 单个输出
    if postion then
        local title_body = 
        zone_get(title)
        if title_body then
            say('[ INFO ]: '
            ..' TITLE: "'..title..'"'..'\r\n'
            ..'[ INFO ]: '..title_body)
        end
        return
    end
    -- 循环upstream list 当中的title
    say('[ INFO ]: '
    ..'Upstream list : \r\n')
    for num = 1, #upstream_list do
        local title_body = 
        zone_get(upstream_list[num])
        if title_body then
            say('[ INFO ]: '
            ..' TITLE: "'..upstream_list[num]..'"'
            ..'\r\n'..title_body..'\r\n')
        end
    end
end

-- 添加server操作
-- 倘若server对应的title不存在，就进行创建
function _M.add_upstream(
    ip_port, 
    weight, 
    algo, 
    status, 
    title)
	--参数合法性判断
	local res = 
    add_parameter_judgment(
    ip_port, 
    weight, 
    algo, 
    status, 
    title)	
	--参数非法，退出！
	if res then
		return
	end
    -- 插入title到upstream list
    title_insert(title)
    --插入title到dict，title作为key
    local title_insert_dict_res = 
    title_insert_dict(
    ip_port, 
    weight, 
    algo, 
    status, 
    title)
    --说明title作为key已经存在，那么add就是在相同的title当中添加server
    if title_insert_dict_res then
        server_insert(
        ip_port, 
        weight, 
        status, 
        title)
    end
end

-- 删除server
function _M.del_upstream(
    title, 
    server_code, 
    from)
	if from == 'server' 
    or from == '' then
		server_delete(title, server_code)
	elseif from == 'title' then
		title_delete(title)
	else
		say('[ ERR ]: '
        ..'The ARGS : "'..from
        ..'" is NOT RIGHT ！！！'
        ..'\r\n'..' from ONLY BE'
        ..' "server" or "title" ')		
	end
end

--修改server
function _M.modify_upstream(
    title, 
    server, 
    modify_key, 
    modify_val)
	--判断要修改的key和val是否合法
	local res = 
    modify_parameter_judgment(
    modify_key, 
    modify_val, 
    title, 
    server)
	if res then
		return
	end
	--判断title是否存在
	local res = title_exist(title)	
	if not res then
		return
	end
	server_modify(
    title, server, 
    modify_key, 
    modify_val)
end

--查看server
function _M.check_upstream(title)
	server_check(title)	
end

return _M

