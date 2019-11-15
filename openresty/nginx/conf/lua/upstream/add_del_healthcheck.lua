-- Copyright © (C) Zhendong (DDJ)
--  开发日期
--      2019.04.11 16:27 (补)
local stt  = require"resty.kerri.basic.str_to_table"
local tts  = require"resty.kerri.basic.table_to_str"
local sm   = require"resty.kerri.basic.send_message"
local ji   = require"resty.kerri.basic.judge_ip"
local rh   = require"resty.kerri.basic.random_hex"
local hdu  = require"resty.kerri.healthcheck.dynamic_healthcheck"
local cj   = require "cjson"
local log  = ngx.log
local info = ngx.INFO
local err  = ngx.ERR
local say  = ngx.say

--获取参数
ngx.req.read_body()
local res, err = 
ngx.req.get_post_args()
if not res then
	log(info,'failed to get body ！！！')
	return
end

local act		      = res['act']
local title		      = res['title']
local health_type	  = res['health_type']
local code_act		  = res['code_act']
local modify_key	  = res['modify_key']
local modify_val	  = res['modify_val']
local batch_execution = res['batch_execution']

--模块信息简介
local a = hdu._VERSION
local b = hdu._AUTHOR
say(a, '\r\n', b, '\r\n')
local hlp = hdu:new()

if act == 'modify' then
	hlp.healthcheck_modify(
    title, 
    health_type, 
    modify_key, 
    modify_val, 
    code_act, 
    batch_execution)
elseif act == 'check' then
	hlp.healthcheck_check(title)
elseif act == 'start' 
or act == 'stop' 
or act == 'reset' 
or act == 'start-all' 
or act == 'stop-all' 
or act == 'reset-all' then
    hlp.healthcheck_model_option(act, title)
end


