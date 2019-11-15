--获取unix时间戳模块
local _M = {}
function _M.sec()
	local sec = ngx.time()
	return sec
end
return _M
