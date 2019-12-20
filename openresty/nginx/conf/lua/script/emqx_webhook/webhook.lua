-- Copyright © (C) Zhendong (DDJ)
-- 2019.07.17 14:06
-- webhook dingding 报警脚本
-- 通过检测发过来的信息，完成信息筛选以及报警给钉钉机器人

local cj                       = require"cjson"
local http                     = require "resty.http"
local emqx_zone                = ngx.shared['emqx_zone']
local exit                     = ngx.exit
local PRINT                    = ngx.print
local log                      = ngx.log
local say                      = ngx.say
local INFO                     = ngx.INFO
local ERR                      = ngx.ERR
local ERR_406                  = ngx.HTTP_NOT_ACCEPTABLE
local POST                     = ngx.HTTP_POST
local GET                      = ngx.HTTP_GET
local location                 = ngx.location.capture
local get_request_uri          = ngx.var.request_uri
local get_request_method       = ngx.var.request_method
local nowtime                  = ngx.localtime()
local read_body                = ngx.req.read_body()
local body_data                = ngx.req.get_body_data()
local sec                      = ngx.time()

-- 详细参数
log(INFO, 'BODY_DATA: ', body_data)
local dingding = "https://oapi.dingtalk.com/robot/send?"
.."access_token=623964a949384905d1bc54f53fa60b9c25312908c3e0415f58304173aad99a82"
-- 合法action列表
local actions = {
		"client_connected",
		"client_disconnected",
		"client_subscribe",
		"client_unsubscribe",
		"session_created",
		"session_subscribed",
		"session_unsubscribed",
		"session_terminated",
		"message_publish",
		"message_delivered",
		"message_acked",
		}
local body_data = cj.decode(body_data)
local action = body_data['action']
local username = body_data['username']
local client_id = body_data['client_id']
local ipaddress = body_data['ipaddress']
local topic = body_data['topic']
local reason = body_data['reason']
local payload = body_data['payload']
local ts = body_data['ts']

-- log(INFO, body_data)
--log(INFO, 'ACTION: ', action)
--log(INFO, ts, '====', nowtime)

-- 通过shell命令来进行钉钉消息通知
local function socket_http(content)
	-- local content = "zhendongzhendong"
	local content = content
	local shell = "curl '"..dingding.."' "
			.."-H 'Content-Type: application/json' "
			.."-d '"..'{"msgtype": "text", '
			..'"text": {'..'"content": "'
			..content
			..'" } }'
			.."'"
	log(INFO, shell)
	os.execute(shell)
end

-- 通过shell命令来进行钉钉消息通知
local function socket_http_markdown(title, content)
	-- local content = "zhendongzhendong"
	local content = content
	local title = title
	local shell = "curl '"..dingding.."' "
			.."-H 'Content-Type: application/json' "
			.."-d '"..'{"msgtype": "markdown", '
			..'"markdown": {'..'"title": "'
			..title
			..'" ,'..'"text": "'
			..content
			..'"} }'
			.."'"
	log(INFO, shell)
	os.execute(shell)
end

-- 上线
local function client_connected()
	if not emqx_zone:get(client_id) then
		log(INFO, '[ ', client_id, ' ] 第一次上线！')
		return
	end
	local title = 'EMQX Client Online !'
	local content = '### 【 检测到客户端上线！】'..'\n'
		..'- **上线时间:** '..nowtime..'\n'
		..'> **client_id:** '..client_id..'\n\n'
		..'> **username:** '..username..'\n\n'
		..'> **ipaddress:** '..ipaddress..'\n\n'
	return title, content
end

-- 下线
local function client_disconnected()
	emqx_zone:set(client_id, sec)
        local title = 'EMQX Client Offline !'
        local content = '### 【 检测到客户端下线！】'..'\n'
                ..'- **下线时间:** '..nowtime..'\n'
		..'- **reason:** '..reason..'\n'
                ..'> **client_id:** '..client_id..'\n\n'
                ..'> **username:** '..username..'\n\n'
        return title, content
end

-- 判断请求的action是否合法，是否存在于actions
local function judge_action()
	local content
	local title
	if action == 'client_connected' then
		title, content = client_connected()
		if not title then
			return
		end
	elseif action == 'client_disconnected' then
		title, content = client_disconnected()
		if not title then
			return
		end
	else
		return
	end
	log(INFO, content)
	socket_http_markdown(title, content)
end

-- 主入口函数
local function main()
	judge_action()
	log(INFO, 'ACTION: ', action)
end

main()
-- socket_http()
