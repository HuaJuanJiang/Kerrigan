-- Copyright © (C) Zhendong (DDJ)
--[[ init_bip_gain_timer:是日志黑名单ip收集器，也属于定时器，
但是它和redis没有交互，只需要定期将指定日志当中的非法请求ip
过滤出来，然后进行筛选，并且写入black ip zone共享空间，
实现将受到黑名单保护的location路径避免被这些ip再次访问
  更新日期：
    2019.03.27 11:48
  shell命令的过滤规则是：
  间隔时间：与定时器执行间隔相同
  会过滤出访问次数默认大于等于三次的非法ip，小于三次的，
  会认为可能是用户误访问。
]]

--local shell         = require"resty.lepai.basic.shell"
local redis         = require"resty.lepai.basic.redis_conn"
local tts           = require"resty.lepai.basic.table_to_str"
local stt           = require"resty.lepai.basic.str_to_table"
local sm            = require"resty.lepai.basic.send_message"
local sec           = require"resty.lepai.basic.get_ngx_sec"
local wbip          = require"resty.lepai.black_white_ip.dynamic_bwip"
local cj            = require"cjson"
local black_ip_zone = ngx.shared['black_ip_zone']
local logfile       = ngx.req.get_uri_args()["logfile"]
local exptime       = ngx.req.get_uri_args()["exptime"]
local count         = ngx.req.get_uri_args()["count"]
local delay         = ngx.req.get_uri_args()["delay"]
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local say           = ngx.say
local timer         = ngx.timer.at
local timers        = ngx.timer.every
local pairs         = pairs
local setmetatable  = setmetatable

-- 白名单，即使被检测出来的ip，但是存在于这个列表当中，那么就不写入dict
local black_ip_white_list = {
    "127.0.0.1"
}

-- 初始化函数，调用dynamic_bwip库当中的函数，来添加黑名单ip
local wb            = wbip:new()
local insert        = wb.add_bip
local del           = wb.del_bip

-- write black ip to dict
local function write_black_ip(read_ip)
    local read_ip = stt.stt(read_ip)
    for num = 1, #read_ip do
        -- 白名单检测
        for bnum = 1, #black_ip_white_list do
            if black_ip_white_list[bnum] ~= read_ip[num] then
                insert(read_ip[num], exptime)
            else
                del(read_ip[num], 'one')
            end
        end
    end
end

-- read logfile
-- 读取日志文件，将非法ip读出来
local function read_logfile()
    --     下面是一条完整的shell命令，用来统计当前指定阈值的ip出现次数最多的（折行）
    -- before="["`date -d "-2440 minute" +%d/%b/%Y:%H:%M:%S`;now="["`date  +%d/%b/%Y:%H:%M:%S`;cat black-ip-access.log | 
    -- awk '"'"$before"'"<$4 && "'"$now"'">$4 {{status[$1]++}}END{for( i in status){print i,status[i]}}'|sort -k2rn  |uniq | 
    -- awk ' $2>= 3 {print $1}' |awk 'BEGIN{ORS="\", \""}{print $0}'
    
    --     当第一次执行的时候，dict表为空，那么需要将之前的ip一次性导入
    -- 因此需要考虑到一种情况，就是不依赖redis的black名单，每次重启
    -- nginx都是无状态的
    -- cat black-ip-access.log| awk '{{status[$1]++}}END{for( i in status){print i,status[i]}}'|sort -k2rn  |uniq | 
    -- awk ' $2>= 3 {print $1}' |awk 'BEGIN{ORS="\", \""}{print $0}'

    --local logfile = '/home/nginx/log/errorlog/black-ip-access.log'
    --local second = 266000
    --local count = 3
    local logfile = logfile
    local second = delay
    local count = count
    local cmd = 'before="["`date -d "-'..second..' second" +%d/%b/%Y:%H:%M:%S`;'
                ..'now="["`date  +%d/%b/%Y:%H:%M:%S`;cat '..logfile..'| '
                .."awk '"..'"'.."'"..'"$before"'.."'"..'"<$4 && "'.."'"..'"$now"'
                .."'"..'">$4 {{status[$1]++}}END{for( i in status){print i,status[i]}}'
                .."'|sort -k2rn  |uniq |".."awk ' $2>= "..count.." {print $1}' "
                .."|awk 'BEGIN{ORS="..'"\\", \\""}{print $0}'.."'"
    local init_cmd = "cat "..logfile.." | "
                .."awk '{{status[$1]++}}END{for( i in status)"
                .."{print i,status[i]}}'|sort -k2rn  |uniq |" 
                .."awk ' $2>= "..count.." {print $1}' "
                .."|awk 'BEGIN{ORS="..'"\\", \\""}{print $0}'.."'"
    --local args = {
    --    socket = "unix:/home/nginx/openresty/nginx/script/socket/shell.sock",
    --}
    --local status, out, err = shell.execute(cmd, args)
    --say(out)
    -- 查看标记是否存在，通过这个判断，这个定时器是不是第一次执行
    local ok, err = 
    black_ip_zone:get('read_point')
    if not ok then
        ok = sm.sh(init_cmd)
        black_ip_zone:set('read_point', '1')
    else
        ok = sm.sh(cmd)
    end
    if ok == 0 then
        log(INFO, '[ INFO ]: '
        ..'BIP GAIN read ip'
        ..' current IS NULL......')
        return
    end
    local read_ip = ok
    local len = string.len(read_ip)
    local read_ip = string.sub(read_ip, 0, len - 3)
    local read_ip = '{"'..read_ip..'}'
    log(INFO, '[ INFO ]: '
    ..'READ BLACK IP: '..read_ip)
    return read_ip
end

-- 日志非法ip收集主函数
function gain_main()
    local read_ip = read_logfile()
    if read_ip then
        write_black_ip(read_ip)
    end
end

timer(2, gain_main)
timers(delay, gain_main)
