-- Copyright © (C) Zhendong (DDJ)
-- 2018.12.11
-- 最近更新：
--   2019.03.15 11:32
-- 持久化函数库
--     持久化：顾明思议就是将数据从临时存储的状态，转换成永久存储的方式
-- 存储到磁盘上，这个词用的最多就是内存数据库redis，而它的作用也非常
-- 明显，将重要的数据存储到磁盘，当redis重启，内存数据丢失，将持久化
-- 数据加载回去，尽量减小损失，其实也是变相的备份。
--     我在这里套用它的概念，因为对应nginx来说，dict是一个共享型的内存数据库，
-- 其中的数据包含了我们在前面定义的upstream list、healthcheck module和各种时间戳。
-- 那么在重启以后这些数据都会消失，拥有持久化这个功能就显得特别重要了，虽然
-- 可能会说有redis可以做实时定时器备份，但是无法否认的是，要是没有redis的存在，
-- 也希望这套系统可以同样正常运转，不能过度依赖某个应用。
--
--  2019.03.25 15:25
--     重构函数，进行功能优化;
--     现在持久化upstream list文件支持作为初始化upstream list文件启动了;
--
--  2019.04.04 10:08
--          增加了timestamp，在考虑多nginx情况下，需要将持久化到dict的动作加入时间戳，
--      就可以以触发定时器的形式将信息同步到其他nginx。
--          注意：在这种情况下，将配置文件load到dict是有风险的，因为这里会直接覆盖原先的
--      upstream list，而不是以“补集”的形式去添加，因此定义了这个功能一般用于在dict和redis
--      是完全没有数据的情况下使用。

local du            = require"resty.lepai.upstream.dynamic_upstream"
local stt           = require"resty.lepai.basic.str_to_table"
local tts           = require"resty.lepai.basic.table_to_str"
local sm            = require"resty.lepai.basic.send_message"
local sec           = require"resty.lepai.basic.get_ngx_sec"
local cj            = require "cjson"
local upstream_zone = ngx.shared['upstream_zone']
local say           = ngx.say
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local pairs         = pairs
local setmetatable  = setmetatable
local file_path     = 
'/home/nginx/openresty/openresty-1.15.8.1/nginx/script/upstream/persis_file'

local _M = {
	_AUTHOR = 'zhendong 2018.12.11',
	_VERSION = '0.12.11',	
}

local mt = { __index = _M }

function _M.new()
	local self = {
		_index = table	
	}
	return setmetatable(self, mt) 
end

--时钟0.01s
local function sleeper()
    ngx.sleep(0.01)
end

--格式化输出时间戳2018.12.11.21.26.25
local function time_stamp()
	local time = ngx.localtime()
    say(time)
	local time = string.gsub(time, ":", "-")
	local time = string.gsub(time, "-", ".")
	local time = string.gsub(time, " ", ".")
	return time
end

-- 初始化模块，引用当中set get 函数，
-- 默认将key存于upstream list，如果
-- 需求有变更，需要自己重写
du = du:new()
zone_get = du.zone_get
zone_set = du.zone_set

--执行命令函数
--1: 指向tmp文件
--2: 将列表重定向到tmp文件
--3: 删除tmp文件
local function cmd(cmd_num)
    -- ls -lt | grep "rw" | awk '{print $6"--"$7"--"$8"   "$9}'
    -- 过滤rw是因为避免有totle为0这样的情况
	local tmp_file = file_path..'/tmp'
	local ls_file = 
	'ls -lt '..file_path.." | grep ".."'rw'"
    .." | awk '"..'{print $6"--"$7"--"$8"   "$9}'
    .."'"..' > '..tmp_file
	local rm_tmp = 'rm '..tmp_file
    -- 返回路径
	if cmd_num == 1 then
		return tmp_file	
    -- 将persis的持久化文件列表重定向到临时文件当中 
	elseif cmd_num == 2 then
		return ls_file
    -- 删除临时文件
	elseif cmd_num == 3 then
		return rm_tmp
	else
		return
	end
end

--将 upstream list 的所有元素对应的信息都持久化到file
local function persis_conf(conf, file_name)
	local time = time_stamp()
	local file_name = 'persis-'
    ..file_name..'-'..time
    ..'-upstream-conf.json'
	local file_path = file_path
    ..'/'..file_name
	f = io.open(file_path, 'w')
	f:write(conf)
	f:close()
    say('[ INFO ]: '
    ..'" '..file_name..' " has create，'
    ..'SUCCESS persis upstream ！！！')
end

--从dict持久化数据
local function persis_grab(file_name)
	local upstream_list = 
    zone_get('upstream_list')
    if not upstream_list then
        say('[ INFO ]: '
        ..'upstream list is  NOT EXIST ！！！')
        return
    end
	local upstream_list = 
    stt.stt(upstream_list)
	conf = {}
    for num = 1, #upstream_list do
        local title_body = 
        zone_get(upstream_list[num])
        if title_body then
            local title_body = 
            cj.decode(title_body)
            conf[upstream_list[num]] = 
            title_body
        end
    end
	--准备写入文件的类型，str
	local conf = cj.encode(conf)
	--写入文件
	persis_conf(conf, file_name)
end

--简单模式查看持久化文件列表
local function check_persis_file_simple()
	local get_tmp_file = cmd(1)
	local ls_file = cmd(2)
	local rm_tmp = cmd(3)
	sm.cr(ls_file)
	sleeper()
    say('[ INFO ]: '
    ..'持久化配置文件列表: '..'\r\n')
	num_line = 1
	for line in io.lines(get_tmp_file) do
		-- 去除tmp杂质
        -- 由于在命令执行的时候，会有一行是tmp，因此
        -- 需要进行去重
		local get_you = string.find(line, 'tmp')
		if not get_you then
			say('[ INFO ]: '
            ..'编号：'..num_line.."  "..line)
		    num_line = num_line + 1
		end
	end
	io.popen(rm_tmp)
end

--复杂模式读取文件
local function check_persis_file_complex()
	local get_tmp_file = cmd(1)
	local ls_file = cmd(2)
	local rm_tmp = cmd(3)
    sm.cr(ls_file)
    sleeper()
    say('[ INFO ]: '
    ..'持久化配置文件列表：'..'\r\n')
    num_line = 1
    for line in io.lines(get_tmp_file)do
        --去除tmp杂质
        local get_you = string.find(line, 'tmp')
        if not get_you then
            say('[ INFO ]: '
            ..'编号：'..num_line.."  "..line)
    		--截取出文件
            local space = string.find(line, 'persis')	
            local len = string.len(line)
            local file = string.sub(line, space, len)
            local cat_the_file = 'cat '
            ..file_path..'/'..file
            --读取内容
            local res = io.popen(cat_the_file)
            local read_res = res:read()
            say(read_res..'\r\n')
            num_line = num_line + 1 
        end 
    end 
    io.popen(rm_tmp)
end

-- 持久化 load
-- 只持久化到dict，在重启nginx的时候，dict
-- 当中肯定是空的
local function load_persis_todict(name, conf)
    --读取配置的方式
    local conf = cj.decode(conf)
	upstream_list = {}
    for title, title_body in pairs(conf) do
        --dict重载
        local sec = sec.sec()
        title_body['timestamp'] = sec
        local title_body = 
        cj.encode(title_body)
      	zone_set(title, title_body)
	    table.insert(upstream_list, title)
        say('[ INFO ]: '
        ..'TITLE: "'..title
        ..'" has SET TO DICT ！！！'
        ..'\r\n'..''..title_body..'\r\n')
    end
	local upstream_list = 
    tts.tts(upstream_list)
    --时间同步upstream_list_update_time
    local sec = sec.sec()
    zone_set('upstream_list', upstream_list)
    zone_set('upstream_list_update_time', sec)
	say('[ INFO ]: '
    ..'SUCCESS persis upstream list '
    ..'" '..name..' " to dict ！！！')
end

-- 持久化 load 
-- 匹配到文件，读取到内容（读取内容）
local function load_persis_file(name)
    local get_tmp_file = cmd(1)
    local ls_file = cmd(2)
    local rm_tmp = cmd(3)
    sm.cr(ls_file)
    sleeper()
    num_line = 1 
    for line in io.lines(get_tmp_file)do
        --去除tmp杂质
        local get_you = 
        string.find(line, 'tmp')
        if not get_you then
            --截取出文件
            local space = string.find(line, 'persis')
            local len = string.len(line)
            local file = string.sub(line, space, len)
		    if file == name then
               	--读取内容
               	local cat_the_file = 'cat '
                ..file_path..'/'..file
                local res = io.popen(cat_the_file)
                local read_res = res:read()
                -- 将读取到内容写入dict
                load_persis_todict(name, read_res)
		    end
            num_line = num_line + 1 
        end 
    end
    io.popen(rm_tmp)
end

-- 持久化 load
-- 重载配置文件，判断输入编号对应的文件名（做判断）
local function load_persis_judge(file_num, file_name)
    local get_tmp_file = cmd(1)
    local ls_file = cmd(2)
    local rm_tmp = cmd(3)
    sm.cr(ls_file)
    sleeper()
	say('[ INFO ]: '
    ..'持久化配置文件匹配结果以及内容：')
    num_line = 1 
    for line in io.lines(get_tmp_file)do
        --去除tmp杂质
        local get_you = string.find(line, 'tmp')
        if not get_you then
            if num_line == tonumber(file_num) then 
                --截取出文件
                local space = string.find(line, 'persis')    
                local len = string.len(line)
                local file = string.sub(line, space, len)
                find_file_name = file
                -- 找到
                if find_file_name == file_name then
                    load_persis_file(find_file_name)
                else
                    say('[ INFO ]: '
                    ..'file_num and file_name is NOT MATCH ！！！'
                    ..'\r\n'..'[ INFO ]: '
                    ..'LOAD CONF_FILE NUM: [ '
                    ..file_num..' ] '
                    ..'MATCH RELOAD CONF_FILE [ '
                    ..find_file_name..' ] ')
                end
            end
        num_line = num_line + 1 
        end 
    end 
    io.popen(rm_tmp)
end

--持久化upstream文件
function _M.conf_persis(file_name)
    persis_grab(file_name)
end

--查看持久化upstream文件
function _M.conf_check(model)
	if model == 'simple' then
	    check_persis_file_simple()
	elseif model == 'complex' then
	    check_persis_file_complex()
	end
end

--重载持久化upstream文件
function _M.conf_load(file_num, file_name)
	load_persis_judge(file_num, file_name)
end

return _M
