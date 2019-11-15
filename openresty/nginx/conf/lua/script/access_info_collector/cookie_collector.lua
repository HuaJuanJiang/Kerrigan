-- Copyright © (C) Zhendong (DDJ)
-- 2019.08.13 11:00
-- 埋点数据处理，cookie获取

local cj                       = require"cjson"
local ck                       = require"resty.kerri.basic.cookie"
local cc_zone                  = ngx.shared['cookie_collector_zone']
local sm                       = require"resty.kerri.basic.send_message"
local exit                     = ngx.exit
local say                      = ngx.say
local PRINT                    = ngx.print
local log                      = ngx.log
local INFO                     = ngx.INFO
local ERR                      = ngx.ERR
local ERR_406                  = ngx.HTTP_NOT_ACCEPTABLE
local POST                     = ngx.HTTP_POST
local GET                      = ngx.HTTP_GET
local thread                   = ngx.thread.spawn
local location                 = ngx.location.capture
local get_request_uri          = ngx.var.request_uri
local get_request_method       = ngx.var.request_method
local headers                  = ngx.req.get_headers()
local id                       = ngx.req.get_headers()['id']
local ngx_header               = ngx.header

-- cookie keys
local bury_key =
{
    "bury_point"
}

-- interval for shell command
local interval = 1000

-- logs size (MB)
local size = 50

-- cookie_file
local cookie_file_home = "/home/nginx/bury_cookie"

-- shell command
local function shell()
    size = size * 1000000
    local shell = "file=$(ls "..cookie_file_home.."$(date +/%Y/%m/%d) -lt 2>/dev/null| grep -v total |head -1);"
                .." file_size=$(echo $file |awk '{print $5}');"
                .." if [[ $file_size < "..size.." ]] && [[ ! -z $file_size ]]; "
                .."then echo -n $(date +/%Y/%m/%d)/$(echo $file| awk '{print $NF}') "
                .."; else echo -n $(date +/%Y/%m/%d)/$(date +%Y%m%d%H%M).log; "
                .."mkdir "..cookie_file_home.."$(date +/%Y/%m/%d) -p ; "
                .."touch "..cookie_file_home.."$(date +/%Y/%m/%d)/$(date +%Y%m%d%H%M).log; fi;"
    local file_name = sm.sh(shell)
    log(INFO, 'SHELL: { ', shell, ' }')
    if not file_name then
        return
    end
    -- log(INFO, 'return: [ ',cookie_file_home, file_name, ' ]')
    return cookie_file_home..file_name
end

-- set cookie file to dict
local function set_cookie_filename()
    local ok = shell()
    if not ok then
        cc_zone:set('cookie_file_name', 'bury.log')
    else
        cc_zone:set('cookie_file_name', ok)
    end
end

-- add cookies to file or other 
local function add_to_file(bury_cookie, file)
    -- say('add_to_file: ', bury_cookie)
    --使用io.open()函数，以添加模式打开文件
    log(INFO, 'Write Cookies: [ ', bury_cookie, ' ] To File: [ ', file, ' ]')
    local f = io.open(file, "a")
    --使用file:open()函数，在文件的最后添加一行内容
    f:write(bury_cookie..'\n')
    f:close()
end

-- judge cookie weather bury_key
local function weather_bury_key(cookie)
    for num = 1, #bury_key do
        if cookie == bury_key[num] then
            return 1
        end
    end
end

-- del cookies from the request
local function del_cookies()
    local cookie = ck:new()
    -- 这里获取到所有的cookie,是一个table,如果不存在则返回nil
    local all_cookies = cookie:get_all()
    for the_cookie, cookie_values in pairs(all_cookies) do
        if weather_bury_key(the_cookie) then
            local ok, err = cookie:set({
                key = the_cookie, value = '',
            })
        end
    end
end

-- Obtain the cookies
local function cookie_filter(bury_cookie_key, file)
    local cookie, err = ck:new()
    if not cookie then
        return
    end
    local bury_cookie, err = cookie:get(bury_cookie_key)
    if not bury_cookie then
        log(INFO,'\r\n'..
        '       [ THIS REQUEST NO BURY COOKIE ]'
        ..'\r\n')
        return
    end
    -- cookies 
    -- log(INFO, 'get bury cookies: ', bury_cookie_key, " ==> ", bury_cookie)
    if bury_cookie and bury_cookie ~= '' then
        thread(add_to_file, bury_cookie, file)
    end
end

-- main func
local function main()
    --shell()
    local cookie_number = cc_zone:get('cookie_number')
    local cookie_file_name = cc_zone:get('cookie_file_name')
    if not cookie_file_name then
        set_cookie_filename()
    end
    if not cookie_number then
        cc_zone:set('cookie_number', 1)
    else
        if tonumber(cookie_number) >= interval then
            set_cookie_filename()
            cc_zone:set('cookie_number', 1)
        else
            cc_zone:set('cookie_number', cookie_number + 1)
        end
    end
    local cookie_file_name = cc_zone:get('cookie_file_name')
    for num = 1, #bury_key do
        thread(cookie_filter, bury_key[num], cookie_file_name)
    end
    -- 获取cookie写入文件和删除cookie继续请求异步任务
    -- 两者并不影响，即使写入cookies失败，但是请求还会继续
    thread(del_cookies)
end

main()
