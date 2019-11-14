-- Copyright © (C) Zhendong (DDJ)
-- 开发日期：2019.02.26 14:31

local wbip          = require"resty.lepai.black_white_ip.dynamic_bwip"
local log           = ngx.log
local INFO          = ngx.INFO
local ERR           = ngx.ERR
local say           = ngx.say
local pairs         = pairs
local setmetatable  = setmetatable

--获取参数
ngx.req.read_body()
local res, err = 
ngx.req.get_post_args()
if not res then
    say('[ INFO ]: '
    ..'failed to get body ！！！')
    log(INFO, '[ INFO ]: '
    ..'failed to get body ！！！')
    return
end

-- 获取参数
local act            = res['act']
local white_ip       = res['white_ip']
local black_ip       = res['black_ip']
local from           = res['from']
local status         = res['status'] 
local exptime        = res['exptime'] 
local ip             = res['ip'] 
local to             = res['to'] 
local domain         = res['domain']
local location       = res['location']

--模块信息简介
local a = wbip._VERSION
local b = wbip._AUTHOR
say(a)
say(b)
say('')
local wb = wbip:new()

-- 调用函数库
if act == 'add' then
	if white_ip then
        wb.add_wip(white_ip)
	else
		wb.add_bip(black_ip, exptime)
	end
elseif act == 'del' then
	if white_ip then
        wb.del_wip(white_ip)
	else
		wb.del_bip(black_ip, status)
	end
elseif act == 'check' then
	if ip and from then
       	wb.check_ip(ip, from)
	else
		wb.check_location(domain, location)
	end
elseif act == 'modify' then
	if not domain then
		wb.modify_ip(ip, from, to, exptime)
	else
		wb.modify_location(domain, location, status)
	end
else
	say('[ ERR ]: '..'ACT ERROR ')
end

