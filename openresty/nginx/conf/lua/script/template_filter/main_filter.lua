-- Copyright © (C) Zhendong (DDJ)
-- 2019.04.03 13:56
--     模板过滤器，简历页面的请求先经过过滤器，然后过滤器将主请求
-- 先以子请求的方式访问一个location，本地的静态文件存储节点，倘若
-- 找到就返回这个页面，如果没有找到，就会返回非200的请求，那么就把
-- 这个请求再次以子请求的方式访问另一个location，让后端应用渲染这个
-- 页面，并将结果返回给用户，所以顺序是：
--                                      (no)
--  请求 ---> /template_filter --- 本地资源 --- 后端应用
--                                  \          \
--                               返回结果   返回结果

-- 2019.05.28 13:49
--     更新的内容: 增加中英文切换页面

-- 2019.05.31 14:32
--     更新的内容: 增加对详情页跳转页面的权限管控
--  设置权限列表

--[[
location /temp_filter {
    content_by_lua_file 
    "/home/sc_nginx/openresty/nginx/conf/lua/script/template_filter.lua";
}
]]
-- 2019.07.22 09:23
--      更新内容：对全局变量的更新，将其改写成为局部变量
--

local cj                       = require"cjson"
local ck                       = require"resty.kerri.basic.cookie"
local exit                     = ngx.exit
local say                      = ngx.say
local PRINT                    = ngx.print
local log                      = ngx.log
local INFO                     = ngx.INFO
local ERR                      = ngx.ERR
local ERR_406                  = ngx.HTTP_NOT_ACCEPTABLE
local POST                     = ngx.HTTP_POST
local GET                      = ngx.HTTP_GET
local location                 = ngx.location.capture
local get_request_uri          = ngx.var.request_uri
local get_request_method       = ngx.var.request_method
local headers                  = ngx.req.get_headers()
local id                       = ngx.req.get_headers()['id']

-- 权限认证location
local permissions_location = '/userSession/valid'
-- local permissions_location = '/test_cookie'

-- 出现权限不足，选择跳转页面，这里选择login.html
local permissions_jump_page = 'login.html'

-- cookies name
local cookies_language = 'language'

-- 本地资源location正则匹配地址
--local local_resource_location  = '/detail'
-- 远程资源应用location正则匹配地址
local remote_resource_location = '/remote'

-- 权限管控列表
-- 凡是在管理列表内的html页面，都会对访问页面用户进行
-- 认证，如果不合格，默认转到permissions_jump_page配置
-- 也就是 “login.html”
local permissions_control_list =
{
    'positionList',
    'teacherList'
}

-- 错误状态列表
local illegal_status =
{
    401, 404, 403,
    406, 500, 501,
    502, 503, 504
}

-- 语言列表
local language =
{
    'zh-CN',
    'en-US'
}

-- 返回406
local function go_406()
    ngx.exit(ERR_406)
end

-- 新的获取方式是通过浏览器首先确定中英文
-- 将获取到的值植入到cookie

-- 第二次请求
-- （第一次请求失败，本地没有文件的情况下）
local function remote_resource(joint)
    log(INFO, '[ INFO ]: '
    ..'\r\n'..'\r\n'..' HTML: [ ', joint, ' ]：'
    ..'Second Forward: LOCAL RESPONSE DOWN ！！！'
    ..'\r\n'..'\r\n')
    local remote_uri =remote_resource_location..joint
    local remote_response
    if get_request_method == 'GET' then
        remote_response = location(
        remote_uri,
        { method = GET })
    else
        remote_response = location(
        remote_uri,
        { method = POST })
    end
    local body = remote_response.body
    local status = remote_response.status
    local remote_encode_response =
    cj.encode(remote_response)
    log(INFO, '[ INFO ]: '
    ..'REMOTE response: ', remote_encode_response)
    for num = 1, #illegal_status do
        if illegal_status[num] == status then
            log(INFO, 'REMOTE response: ',
            remote_encode_response,
            ', realserver donot handle it ' )
            return go_406()
        end
    end
    PRINT(body)
end

-- 第一次请求路径
local function location_resource(joint)
    -- 根据前端不同的请求方式，进行不同的请求
    local local_response
    if get_request_method == 'GET' then
        local_response =
        location(
        joint,
        { method = GET })
    else
        local_response =
        location(
        joint,
        { method = POST })
    end
    local body = local_response.body
    local status = local_response.status
    local local_encode_response =
    cj.encode(local_response)
    log(INFO, '[ INFO ]: '
    ..'LOCAL response: ', local_encode_response)
    -- 如果返回的状态码为非法进行第二次转发
    -- 到后端服务器上
    for num = 1, #illegal_status do
        if illegal_status[num] == status then
            return 1
        end
    end
    --PRINT(body)
    PRINT(local_response.body)
end

-- 语言判断
local function judge_language()
    if not headers['accept-language'] then
        return 'en'
    end
    for num = 1, #language do
        if string.sub(headers['accept-language'], 1, 5)
        == language[num] then
            local len = string.len(language[num])
            local spear = string.find(language[num], '-')
            local a = string.sub(language[num], 1, spear - 1)
            log(INFO,'accept-language: ',a)
            return string.sub(language[num], 1, spear - 1)
        end
    end
    -- 默认其他国家的都是英文
    return 'en'
end

-- get cookies
local function cookie_filter()
    local cookie, err = ck:new()
    if not cookie then
        return
    end
    -- get single cookie
    local get_cookies, err = cookie:get(cookies_language)
    if not get_cookies then
        return
    end
    -- cookies 
    log(INFO, 'get cookies: ', cookies_language, " ==> ", get_cookies)
    for num = 1, #language do
        local len = string.len(language[num])
        local spear = string.find(language[num], '-')
        local language_path = string.sub(language[num], 1, spear - 1)
        if get_cookies == language_path then
            log(INFO, get_cookies,'==',language_path)
            return language_path
        end
    end
    log(INFO, 'return')
    return 'en'
end

-- set cookies
local function set_cookies(language_path)
    local cookie, err = ck:new()
    local ok, err = cookie:set({
        key = cookies_language, value = language_path, path = "/",
    })

end

-- 权限后端访问
local function permissions()
    -- 根据前端不同的请求方式，进行不同的请求
    local local_response
    if get_request_method == 'GET' then
        local_response =
        location(
        permissions_location,
        { method = GET })
    else
        local_response =
        location(
        permissions_location,
        { method = POST })
    end
    local body = local_response.body
    local status = local_response.status
    local local_encode_response =
    cj.encode(local_response)
    log(INFO, '[ INFO ]: '
    ..'PERMISSIONS response: ', local_encode_response)
    -- 如果返回的状态码为非法进行第二次转发
    -- 到后端服务器上
    for num = 1, #illegal_status do
        if illegal_status[num] == status then
            return 1
        end
    end
end

-- 权限list过滤
local function permissions_list(language_path)
    for num = 1, #permissions_control_list do
        -- 抓取到list
        local point= string.find(get_request_uri,
        permissions_control_list[num])
        if point then
            if permissions() then
                log(INFO, 'Page is not for this user')
                local joint = '/'..language_path..'/'
                ..permissions_jump_page
                location_resource(joint)
                -- 说明已经因为权限不足，
                -- 跳转到permissions_jump_page
                return 1
            end
        end
    end
end

-- 主函数入口
local function main()
    -- 判断cookies是否存在
    log(INFO, "cookies_ok: ", cookies_ok)
    local cookies_ok = cookie_filter()
    -- 不存在，除了从accept-language获取之外，
    -- 还需要将其设置到cookies当中
    local language_path
    if not cookies_ok then
        language_path = judge_language()
        set_cookies(language_path)
    else
        language_path = cookies_ok
    end
    -- 权限判断
    -- 如果存在说明匹配到权限管控列表
    -- 并且用户未登录
    if permissions_list(language_path) then
        return
    end
    -- 详情页拼接路径
    local joint = '/'..language_path..get_request_uri
    log(INFO, 'HTML: ', joint)
    if location_resource(joint) then
        remote_resource(joint)
    end
end

log(INFO, 'THE REQUEST HEADERS: ', cj.encode(headers))
-- log(INFO, cj.encode(headers))
main()

