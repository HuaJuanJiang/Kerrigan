-- 执行shell命令模块
-- 需要配合sockproc来进行
local _M = {}
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local log           = ngx.log
local shell         = require "resty.shell"
local shells        = require "resty.kerri.basic.shell"
local sock = 
'unix:/home/nginx/openresty/nginx/script/socket/shell.sock'    -- sockproc监听的socket
local main_script = 
'/home/nginx/openresty/nginx/script/main.sh'

-- 执行消息推送shell命令，需要配合nginx下的script函数进行消息推送
function _M.sm(ide, act, w_ip, user, auth)
    if not w_ip then
        local w_ip = '127.0.0.1'
    end
    local py_shell = shell.new()
    if not py_shell then
        log(ERR,'[ ERR ]: '
    	..'shell_new is not success')
	    return 1
    end
    local sock_res, sock_err = 
    py_shell:connect(sock)
    if not sock_res then
        log(ERR,'[ ERR ]: '
    	..'sock is not connect')
	    return 1
    end
    local send_ip_cmd =
    string.format(main_script
    ..' %s %s %s %s %s', 
    ide, act, w_ip, user, auth)
    local comm_res, comm_err = 
    py_shell:send_command({
    cmd = send_ip_cmd,
    })
    if not comm_res then
        log(ERR, '[ ERR ]: '
	    ..'files is not found ')
	    return 1
    end
    local comm_status ,comm_out ,comm_err = 
    py_shell:read_response()
    if comm_status ~= '0' then
        log(ERR,'[ ERR ]: '
	    .."command can't be executablesd")
	    return 1
    end
end

-- 单纯执行一个shell命令，同样需要sockproc配合
function _M.cr(cmd)
    if not w_ip then
        local w_ip = '127.0.0.1'
    end
    local shell = shell.new()
    if not shell then
        log(ERR,'[ ERR ]: '
    	..'shell_new is not success')
	    return
    end
    local sock_res, sock_err = 
    shell:connect(sock) 
    if not sock_res then
        log(ERR,'[ ERR ]: '
	    ..'sock is not connect')
	    return
    end
    --local conn_cmd = string.format(cmd)
    local comm_res, comm_err = 
    shell:send_command({
    cmd = cmd,
    })
    if not comm_res then
        log(ERR, '[ ERR ]: '
	    ..'files is not found ')
	    return
    end
    local comm_status ,comm_out ,comm_err = 
    shell:read_response()
    if comm_status ~= '0' then
        log(ERR,'[ ERR ]: '
	    .."command can't be executablesd")
	    return
    end
    return comm_out
end

-- 更高效的shell执行方式
-- 推荐这个
function _M.sh(cmd)
    local args = { 
        socket = sock,
    }
    local status, out, err = shells.execute(cmd, args)
    --log(INFO, status, '--', out, '--', err)
    if status == 0 and out then
        return out
    elseif status == 0 and not out then
        return status
    end
end

return _M 
