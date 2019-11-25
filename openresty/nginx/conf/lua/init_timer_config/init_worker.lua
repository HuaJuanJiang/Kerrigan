--[[ 
Copyright © (C) Zhendong (DDJ)
  B版本更新
  2019.02.28
        对定时器模块的功能进行强化，明显区分开定时器主配置文件，库函数，定时器主程序
    之间的区别。2019.02.28
        注意在init_timers阶段是不允许redis连接的，这个是IO阻塞请求，所以通过shell的方式来连接redis ！！！
    由于shell的方式还是有瑕疵，因为会导致Nginx的进程异常退出，
    所以决定采用shell执行location的方式来触发定时器

  C版本更新
  2019.03.21 10:00
        新添加功能，可以添加初始化白名单ip，默认是存在127.0.0.1，这里解决一个问题就是：在kerrigen对外暴露的
    API是受到白名单保护的，这个就需要在公司的IP下可以通过postman执行命令，对于安全来说必不可少
]]
local init_timers                     = require"resty.kerri.init_timers_lib.init_worker_timers"
local stt                             = require"resty.kerri.basic.str_to_table"
local tts                             = require"resty.kerri.basic.table_to_str"
local convert                         = require"resty.kerri.basic.ip_converter"
local cj                              = require "cjson"
local wip_zone                        = ngx.shared['white_ip_zone']
local log                             = ngx.log
local INFO                            = ngx.INFO
local ERR                             = ngx.ERR
local timer                           = ngx.timer.at
local ID                              = ngx.worker.id

-------------------------------- 定时器执行的 nginx 工作进程配置 ----------------------------------------
local ip_worker_num                   = 0 -- 选择第1个worker执行ip timer定时任务 
local upstream_worker_num             = 2 -- 选择第3个worker执行upstream timer定时任务
local healthcheck_worker_num          = 2 -- 选择第3个worker执行healthcheck timer定时任务
local init_upstream_config_num        = 0 -- 选择第1个worker执行init upstream config定时任务
local bip_gain_worker_num             = 1 -- 选择第2个worker执行black ip gain定时任务
local state_sync_worker_num           = 0 -- 选择第1个worker执行state sync定时任务
local node_heartbeat_worker_num       = 1 -- 选择第2个worker执行node heartbeat定时任务
local upserver_sync_worker_num        = 1 -- 选择第2个worker执行upserver sync定时任务


------------------------------------- 定时器事件间隔配置 ------------------------------------------------
-- 建议除了“node heartbeat”和“upserver sync”之外所有定时器的其他定时器的时间间隔大于等于2秒
local main_timer_delay                = 0  -- 主定时器执行间隔，nginx启动后执行其他定时器的间隔，建议为0，立即启动
local wbip_delay                      = 5  -- white ip 定时器执行间隔
local init_upstream_config_delay      = 2  -- init upstream config初始化upstream配置定时器执行间隔
local upstream_delay                  = 10 -- upstream动态拉取配置定时器执行间隔
local healthcheck_delay               = 8  -- healthcheck健康检查定时器执行间隔
local bip_gain_delay                  = 5  -- black ip gain定时器执行间隔
local state_sync_delay                = 5  -- state sync定时器执行间隔
local node_heartbeat_delay            = 1  -- node heartbeat 定时器执行间隔
local upserver_sync_delay             = 1  -- upserver 状态同步定时器执行间隔


-------------------------------------- 定时器文件名配置 ------------------------------------------------
local wbip_timer_file                 = 'wbip_timer.sh' 
local init_upstream_config_timer_file = 'init_upstream_config_timer.sh'
local dynamic_upstream_timer_file     = 'dynamic_upstream_timer.sh'
local healthcheck_timer_file          = 'healthcheck_timer.sh'
local bip_gain_timer_file             = 'bip_gain_timer.sh'
local state_sync_timer_file           = 'state_sync_timer.sh'
local node_heartbeat_timer_file       = 'node_heartbeat_timer.sh'
local upserver_sync_timer_file        = 'upserver_sync_timer.sh'


----------------------------------- 执行定时器脚本路径配置 ---------------------------------------------
-- 定时器拉起location脚本路径
local srcipt_path                     = 
'/home/nginx/openresty/nginx/script/init_timer'


----------------------------------- healthcheck 定时器配置 --------------------------------------------- 
-- nginx upstream conf 路径
local healthcheck_upstream_filepath   =
'/home/nginx/openresty/nginx/conf/conf.d/lepai_balancer.conf'


------------------------------ init upstream conf 定时器配置文件 ---------------------------------------
-- 初始化定时器模式配置：
--      1. cover
--      2. uncover
--      3. down
--      1. 非覆盖模式: 在定时器启动之后，会把初始化upstream文件当中不存在于redis的title更新到redis和dict，
--  已经存在的title_body不会做任何更新操作，期间不会有任何覆盖操作。
--      2. 覆盖模式: 在定时器启动之后，会把初始化upstream文件当中所有的title和对应的title_body更新到
--  redis和dict，有值的话，也是直接覆盖。
--      3. 关闭定时器，定时器将不会执行。
--      说明：在线上生成环境当中，如果只是对nginx进行正常的重启操作，可以选择直接关闭“init upstream conf”定时器，
--  或者直接选择非覆盖模式，因为覆盖模式会把之前修改的好的title_body进行了覆盖，当然要是在关闭nginx之前，
--  将nginx内容持久化下来，作为初始化文件，并且是重置redis，就可以采用直接的“覆盖模式”；以节点的身份加入已有的
--  nginx+redis集群，那么建议直接关闭这个定时器或者采用非覆盖，不过定时器代码当中也有保护机制，在以多节点连接
--  到redis，就直接跳过后面代码了
local init_upstream_config_state = 'uncover' 
-- init upstream conf script path
local init_upstream_config_filepath   =
'/home/nginx/openresty/nginx/script/upstream/init_upstream_conf'
-- init upstream json conf
local init_upstream_config_jsonfile   =
'init_upstream_conf.json'
-- init upstream python script
local init_upstream_config_pythonfile =
'json_format.py'
--python_cmd
local python_cmd                      =
'/usr/bin/python '


--------------------------------- black ip gain 定时器配置文件 ----------------------------------------
-- 日志位置
local bip_gain_timer_logfile          =
'/home/nginx/logs/accesslog/black-ip-access.log'
-- 设置过期时间（单位: 小时）
local bip_gain_timer_exptime          = 
8
-- black ip 出现次数大于多少次，就进行记录，否则视为误访问，并不记录
local bip_gain_timer_count            =
1


----------------------------------- 黑白名单定时器初始白名单 --------------------------------------------
--     由于受到白名单保护，所以定时器启动location，在最初始化的时候无法启动的，
-- 因为dict列表为空，白名单ip无法匹配，因此需要在最开始指定一下ip，随后可以
-- 在 wbip 定时器的帮助下，再对”127.0.0.1“进行设置
--     在定时器启动之前先对白名单进行设置，因为定时器所在的location是受到白名单保护的，
-- 因此对于通过shell进行curl触发访问的操作是需要127.0.0.1的ip是在白名单内的。
wip_zone:set('127.0.0.1', 'reset')

-- 白名单列表，只有下列ip才是可以进行对受保护的特定location进行访问
local init_white_ip_tab = 
{   
    "127.0.0.1",
    "192.168.1.122"
}


---------------------------------- node heartbeat 节点信息 ---------------------------------------------
local node = 'sit-nginx'


----------------------------------------- sockproc配置 ---------------------------------------------------
----注意：在第一次没有启动socket的时候，这个脚本会去将它拉起，但是会有一个弊端
----它随着ngnx进程启动，并且占用和nginx相同的端口，也就是80端口，并且在nginx重启，
----它不会被nginx master进程kill，最后重新启动nginx就会导致端口被占用，需要手动kill
----sockproc，所以建议：手动启动sockproc，./sockproc shell.sock 相对目录启动即可，
----注意和basic的send_message.lua库当中的配置相同，比如socket名称和路径！
--local sockproc_path                   =
--'/home/nginx/openresty/nginx/script/socket'
--local sockproc_file                   =
--'sockproc'
--local sockproc_socketname             =
--'shell.sock'


----------------------------------------- 定时器 -------------------------------------------------------
--启动定时器，但是只执行一次，将通过调用location暴露的定时器接口将定时器脚本拉起。

if ip_worker_num == ID() then
    if not init_white_ip_tab then
        init_white_ip_tab = {}
    end
    local iwip_str = convert.encode(init_white_ip_tab, '-')
	local ok, err = timer(
	main_timer_delay, 
	init_timers.wbip_timer, 
	srcipt_path, 
	wbip_timer_file,
    iwip_str,
	wbip_delay
	)
	if not ok then
		log(ERR, '[ ERR ]: '
		..'[ BLACK&WHITE IP TIMER ] IS NOT OK ！！！ ')
	end
end

if init_upstream_config_num == ID() then
	local ok, err = timer(
	main_timer_delay, 
	init_timers.init_upstream_config_timer, 
	srcipt_path, 
	init_upstream_config_timer_file, 
    init_upstream_config_state,
	init_upstream_config_filepath,
	init_upstream_config_jsonfile,
	init_upstream_config_pythonfile,
	python_cmd,
	init_upstream_config_delay
	)
	if not ok then
		log(ERR, '[ ERR ]: '
		..'[ INIT UPSTREAM CONFIG ] IS NOT OK ！！！ ')
	end
end

if upstream_worker_num == ID() then
	local ok, err = timer(
	main_timer_delay,
	init_timers.dynamic_upstream_timer, 
	srcipt_path, 
	dynamic_upstream_timer_file, 
	upstream_delay
	)
	if not ok then
		log(ERR, '[ ERR ]: '
		..'[ UPSTREAM TIMER ] IS NOT OK ！！！ ')
	end
end

if healthcheck_worker_num == ID() then
	local ok, err = timer(
	main_timer_delay,
	init_timers.healthcheck_timer, 
	srcipt_path,
	healthcheck_timer_file, 
	healthcheck_upstream_filepath, 
	healthcheck_delay
	)
	if not ok then
		log(ERR, '[ ERR ]: '
		..'[ HEALTHCHECK TIMER ] IS NOT OK ！！！ ')
	end
end

--if bip_gain_worker_num == ID() then
--	local ok, err = timer(
--	main_timer_delay,
--	init_timers.bip_gain_timer, 
--	srcipt_path,
--	bip_gain_timer_file, 
--	bip_gain_timer_logfile, 
--    bip_gain_timer_exptime,
--    bip_gain_timer_count,
--	bip_gain_delay
--	)
--	if not ok then
--		log(ERR, '[ ERR ]: '
--		..'[ BLACK IP GAIN TIMER ] IS NOT OK ！！！ ')
--	end
--end

if state_sync_worker_num == ID() then
	local ok, err = timer(
	main_timer_delay,
	init_timers.state_sync_timer, 
	srcipt_path,
    state_sync_timer_file,
    state_sync_delay
	)
	if not ok then
		log(ERR, '[ ERR ]: '
		..'[ STATE SYNC TIMER ] IS NOT OK ！！！ ')
	end
end

if node_heartbeat_worker_num == ID() then
	local ok, err = timer(
	main_timer_delay,
	init_timers.node_heartbeat_timer, 
	srcipt_path,
	node_heartbeat_timer_file, 
    node,
    node_heartbeat_delay
	)
	if not ok then
		log(ERR, '[ ERR ]: '
		..'[ NODE HEARTBEAT TIMER ] IS NOT OK ！！！ ')
	end
end

if upserver_sync_worker_num == ID() then
	local ok, err = timer(
	main_timer_delay,
	init_timers.upserver_sync_timer, 
	srcipt_path,
	upserver_sync_timer_file,
    upserver_sync_delay
	)
	if not ok then
		log(ERR, '[ ERR ]: '
		..'[ UPSERVER SYNC TIMER ] IS NOT OK ！！！ ')
	end
end

