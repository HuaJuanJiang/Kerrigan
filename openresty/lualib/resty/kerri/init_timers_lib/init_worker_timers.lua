-- Copyright © (C) Zhendong (DDJ)
-- 更新日期：2019.02.28 11.25
-- 定时器主配置文件调用的库函数，和conf/lua/init_worker.lua
-- 配合使用
local _M            = {} 
local sm            = require"resty.kerri.basic.send_message"
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR

-- black&white ip timer
-- 黑白名单定时器驱动函数
function _M.wbip_timer(
    premature, 
	srcipt_path, 
	timer_file, 
    iwip_str,
	delay)
	log(INFO, '[ INFO ]: '
	..'BLACK WHITE IP TIMER '
    ..'with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
    ..' '..'iwip_str='..iwip_str
	..' '..'delay='..delay
	local wip_cmd = cmd	
	local cmd_res = 
    sm.sh(wip_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'BLACK WHITE IP TIMER '
        ..'script execute failed ! ! !')
	end	
end

-- init upstream config timer ( once time )
-- 初始化upstream定时器驱动函数
function _M.init_upstream_config_timer(
    premature, 
	srcipt_path, 
	timer_file,
    state,
	config_filepath, 
	config_jsonfile, 
	config_pythonfile, 
	python_cmd,
	delay)
	log(INFO, '[ INFO ]: '
	..'INIT UPSTREAM CONFIG TIMER '
    ..'with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
    log(INFO, srcipt_path, timer_file)
    local cmd = string.format(
    '%s/%s state=%s config_path=%s '
    ..'json_file=%s python_file=%s '
    ..'python_cmd=%s delay=%s', 
    srcipt_path,
    timer_file,
    state,
    config_filepath,
    config_jsonfile, 
    config_pythonfile,
    python_cmd, 
    delay)
	local init_upstream_config_cmd = cmd	
	local cmd_res = 
    os.execute(init_upstream_config_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'INIT UPSTREAM CONFIG TIMER'
        ..' script execute failed ! ! !')
	end	
end

-- dynamic upstream timer
-- 动态负载均衡同步驱动函数
function _M.dynamic_upstream_timer(
    premature, 
	srcipt_path, 
	timer_file, 
	delay)
	log(INFO, '[ INFO ]: '
	..'DYNAMIC UPSTREAM TIMER '
    ..'with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
	..' '..'delay='..delay
	local dynamic_upstream_cmd = cmd 	
	local cmd_res = 
    sm.sh(dynamic_upstream_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'DYNAMIC UPSTREAM TIMER'
        ..' script execute failed ! ! !')
	end	
end 

-- healthcheck timer
-- 健康检查驱动函数
function _M.healthcheck_timer(
    premature, 
	srcipt_path, 
	timer_file,
	upstream_file_path, 
	delay)
	log(INFO, '[ INFO ]: '
	..'HEALTHCHECK TIMER'
    ..' with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
	..' '..'delay='..delay
	..' '..'upstream_file_path='
    ..upstream_file_path
	local healthcheck_cmd = cmd 	
	local cmd_res = 
    sm.sh(healthcheck_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'HEALTHCHECK TIMER'
        ..' script execute failed ! ! !')
	end	
end

-- black ip gain timer
-- 黑名单日志检查驱动函数
function _M.bip_gain_timer(
    premature, 
	srcipt_path, 
	timer_file,
    logfile, 
    exptime,
    count,
	delay)
	log(INFO, '[ INFO ]: '
	..'BIP GAIN TIMER '
    ..'with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
	..' '..'logfile='..logfile
	..' '..'exptime='..exptime
	..' '..'count='..count
	..' '..'delay='..delay
	local bip_gain_cmd = cmd 	
	local cmd_res = 
    sm.sh(bip_gain_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'BIP GAIN TIMER '
        ..'script execute failed ！！！')
	end	
end

-- state sync timer
-- hc&lc状态同步驱动函数
function _M.state_sync_timer(
    premature, 
	srcipt_path, 
	timer_file,
	delay)
	log(INFO, '[ INFO ]: '
	..'STATE SYNC TIMER'
    ..' with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
	..' '..'delay='..delay
	local state_sync_cmd = cmd 	
	local cmd_res = 
    sm.sh(state_sync_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'STATE SYNC TIMER'
        ..' script execute failed ！！！')
	end	
end

-- node heartbeat timer
-- nginx节点心跳状态同步驱动函数
function _M.node_heartbeat_timer(
    premature, 
	srcipt_path, 
	timer_file,
    node,
	delay)
	log(INFO, '[ INFO ]: '
	..'NODE HEARTBEAT TIMER'
    ..' with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
	..' '..'node='..node
	..' '..'delay='..delay
	local node_heartbeat_cmd = cmd 	
	local cmd_res = 
    sm.sh(node_heartbeat_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'NODE HEARTBEAT TIMER'
        ..' script execute failed ！！！')
	end	
end

-- upserver sync timer
-- upserver状态同步驱动函数
function _M.upserver_sync_timer(
    premature,
	srcipt_path, 
	timer_file,
	delay)
	log(INFO, '[ INFO ]: '
	..'UPSERVER SYNC TIMER'
    ..' with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
	..' '..'delay='..delay
	local upserver_sync_cmd = cmd 	
	local cmd_res = 
    sm.sh(upserver_sync_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'UPSERVER SYNC TIMER'
        ..' script execute failed ！！！')
	end	
end

-- sockproc timer ( once time )
-- sockproc驱动函数
function _M.sockproc_timer(
    premature, 
	srcipt_path,
	timer_file,
	sockproc_path, 
	sockproc_file, 
	sockproc_socketname, 
	delay)
	log(INFO, '[ INFO ]: '
	..'SOCKPROC TIMER'
    ..' with nginx work id: [ '
	..ngx.worker.id()
	..' ] start up ! ! ! ')
	local cmd = srcipt_path..'/'
	..timer_file
	..' '..sockproc_path
	..' '..sockproc_file
	..' '..sockproc_socketname
	local sockproc_cmd = cmd 	
	local cmd_res = 
    os.execute(sockproc_cmd)
	--local cmd_res = io.popen(sockproc_cmd)
	if not cmd_res then
		log(ERR, '[ ERR ]: '
		..'SOCKPROC TIMER'
        ..' script execute failed ! ! !')
	end	
end 

return _M

