#1/usr/bin/env bash
IP_SUBJECT="                    IP 白名单消息提醒"
BASIC_AUTH_SUBJECT='                    Basic Auth 消息提醒'
AUTH_SUBJECT='                          Auth 消息提醒'
SEND_TO='zhendongran@dingtalk.com'
SCRIPT_HOME='$SCRIPT_HOME/openresty/openresty-1.15.8.1/nginx/script/send_message'
if [[ $1 == 'ip' ]];then
	if [[ $2 == 'add' ]];then
		$SCRIPT_HOME/dingding.py "$IP_SUBJECT" "成功将IP：${3} 添加到白名单列表"
		$SCRIPT_HOME/wechat.py "$IP_SUBJECT" "成功将IP：${3} 添加到白名单列表"
	elif [[ $2 == 'del' ]];then
		$SCRIPT_HOME/dingding.py "$IP_SUBJECT" "成功将IP：${3} 从白名单列表删除"
		$SCRIPT_HOME/wechat.py "$IP_SUBJECT" "成功将IP:：${3} 从白名单列表删除"
	elif [[ $2 == 'reset' ]];then
		$SCRIPT_HOME/dingding.py "$IP_SUBJECT" "                 成功将白名单列表重置                 "
		$SCRIPT_HOME/wechat.py "$IP_SUBJECT" "                 成功将白名单列表重置                 "
	fi
elif [[ $1 == 'basic_auth' ]];then
	if [[ $2 == 'add' ]];then
		$SCRIPT_HOME/dingding.py "$BASIC_AUTH_SUBJECT" "成功将用户：${3}添加到basic auth列表"
		$SCRIPT_HOME/wechat.py "$BASIC_AUTH_SUBJECT" "成功将用户：${3}添加到basic auth列表"
	elif [[ $2 == 'del' ]];then
                $SCRIPT_HOME/dingding.py "$BASIC_AUTH_SUBJECT" "成功将用户：${3}从basic auth列表删除"
                $SCRIPT_HOME/wechat.py "$BASIC_AUTH_SUBJECT" "成功将用户：${3}从basic auth列表删除"
	elif [[ $2 == 'reset' && $3 == 'random' ]];then
                $SCRIPT_HOME/send_email.py "$SEND_TO" "Basic Auth Information" "成功将basic auth列表重置 用户：${4} 密码：${5}"
	elif [[ $2 == 'reset' ]];then
		$SCRIPT_HOME/dingding.py "$BASIC_AUTH_SUBJECT" "                 成功将basic auth列表重置                 "
		$SCRIPT_HOME/wechat.py "$BASIC_AUTH_SUBJECT" "                 成功将basic auth列表重置                 "
		$SCRIPT_HOME/send_email.py "$SEND_TO" "Basic Auth Information" "成功将用户 ${3} 密码重置，新密码为：${4}"
	fi
elif [[ $1 == 'auth' ]];then
	if [[ $2 == 'add' && $5 != 'nil' ]];then
		$SCRIPT_HOME/send_email.py "$5" "Auth Information" "成功将用户 ${3} 添加到redis当中，密码为：${4}"
        elif [[ $2 == 'add' && $5 == 'nil' ]];then
		$SCRIPT_HOME/send_email.py "$SEND_TO" "Auth Information" "成功将用户 ${3} 添加到redis当中，密码为：${4}"
	elif [[ $2 == 'info' ]];then
		if [[ $3 == 'admin' ]];then
			$SCRIPT_HOME/send_email.py "$SEND_TO" "auth定时器预警" "$4" 
		elif [[ $3 == 'java' ]];then
			$SCRIPT_HOME/send_email.py "$SEND_TO" "auth定时器预警" "$4"
		elif [[ $3 == 'admin_hex' ]];then
			$SCRIPT_HOME/send_email.py "$SEND_TO" "auth定时器重置更新${4}密码" "用户名：${4}；密码：$5"
		elif [[ $3 == 'java_hex' ]];then
			$SCRIPT_HOME/send_email.py "$SEND_TO" "auth定时器重置更新${4}密码" "用户名：${4}；密码：$5"
		fi
	elif [[ $2 == 'reset' ]];then
                $SCRIPT_HOME/dingding.py "$AUTH_SUBJECT" "                 成功将auth列表重置                 "
                $SCRIPT_HOME/wechat.py "$AUTH_SUBJECT" "                 成功将auth列表重置                 "
                $SCRIPT_HOME/send_email.py "$SEND_TO" "Auth Information" "auth全部重置"
	fi
fi

