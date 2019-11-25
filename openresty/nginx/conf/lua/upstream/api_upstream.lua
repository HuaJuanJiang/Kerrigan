-- Copyright © (C) Zhendong (DDJ)
--  更新日期
--      2019.04.11 16:28
local redis = require"resty.kerri.basic.redis_conn"
local stt = require"resty.kerri.basic.str_to_table"
local tts = require"resty.kerri.basic.table_to_str"
local sm = require"resty.kerri.basic.send_message"
local ji = require"resty.kerri.basic.judge_ip"
local rh = require"resty.kerri.basic.random_hex"
local du = require"resty.kerri.upstream.dynamic_upstream"
local pu = require"resty.kerri.upstream.persis_upstream_conf"
local cj = require "cjson"
local upstream_zone = ngx.shared['upstream_zone']
local log = ngx.log
local info = ngx.INFO
local err = ngx.ERR
local say = ngx.say

--获取参数
ngx.req.read_body()
local res, err = 
ngx.req.get_post_args()
if not res then
	log(info,'failed to get body ！！！')
	return
end

local act		    = res['act']
local ip_port		= res['ip_port']
local weight		= res['weight']
local algo		    = res['algo']
local status		= res['status']
local title		    = res['title']
local from		    = res['from']
local server_code	= res['server_code']
local server		= res['server']
local modify_key	= res['modify_key']
local modify_val	= res['modify_val']
local form		    = res['form']
local file_name		= res['file_name']
local model		    = res['model']
local file_num		= res['file_num']
local file_name		= res['file_name']

--模块信息简介
local a = du._VERSION
local b = du._AUTHOR
say(a, '\r\n',
    b, '\r\n',
    '\r\n')
local dlp = du:new()
local plp = pu:new()

if act == 'add' then
	dlp.add_upstream(
    ip_port, 
    weight, 
    algo, 
    status, 
    title)
elseif act == 'del' then
	dlp.del_upstream(
    title, 
    server_code, 
    from)
elseif act == 'modify' then
	dlp.modify_upstream(
    title, 
    server, 
    modify_key, 
    modify_val)
elseif act == 'check' then
	dlp.check_upstream(title)
elseif act == 'conf_persis' then
	plp.conf_persis(file_name)
elseif act == 'conf_check' then
	plp.conf_check(model, format)
elseif act == 'conf_load' then
	plp.conf_load(file_num, file_name)
end


