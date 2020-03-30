-- Copyright © (C) Zhendong (DDJ)
-- 2020.03.30 10:18
-- rewrite判断
-- 区分内部重定向和内部location并行请求的区别：
--  - ngx.location.capture: 在跳转到其他location之后，原来请求的location
--      还会同步执行，这是ngx_lua特有。
--  - ngx.exec：就是nginx内部的break或者latest内部重定向的lua实现。

local log                      = ngx.log
local INFO                     = ngx.INFO
local ERR                      = ngx.ERR
local POST                     = ngx.HTTP_POST
local GET                      = ngx.HTTP_GET
local exec                     = ngx.exec
local url_args                 = ngx.req.get_uri_args
local get_request_uri          = ngx.var.request_uri

-- key and value for member
local member_center_key = 'state'
local member_center_val = 'member'
-- member location api 
local api_member_center = '/api_member_center'

-- the enter
local args = url_args()
for k,v in pairs(args) do
    -- if uri args is match
    if k == member_center_key and v == member_center_val then
        rewrite_uri = api_member_center..get_request_uri
        log(INFO, '[ INFO ] The Request Uri Args Include: {', k, ' == ', v, '}, So Rewrite To "', rewrite_uri, '"')
        exec(rewrite_uri)
    end
end

