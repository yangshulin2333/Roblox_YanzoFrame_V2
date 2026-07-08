--!strict
--统一输出格式，方便以后看日志、排错。
local Logger = {}

--[[
	level   日志等级，比如 信息 / 警告 / 错误
	scope   日志来源，比如 ServiceRegistry / NetService
	message 具体日志内容
]]
local function formatMessage(level, scope, message)
	return string.format("[YanzoFrame_V0][%s][%s] %s", level, scope, message)
end

function Logger.Debug(scope, message)
	print(formatMessage("Debug", scope, message))
end

function Logger.Info(scope, message)
	print(formatMessage("Info", scope, message))
end

function Logger.Warn(scope, message)
	warn(formatMessage("Warn", scope, message))
end

--抛出错误，中断当前执行线程 / 当前调用流程。 Logger.Error 用的是 error()
function Logger.Error(scope, message)
	--2 是为了让报错的堆栈信息指向调用 Logger.Error 的地方，而不是 Logger.lua 里。
	error(formatMessage("Error", scope, message), 2)
	--[[
		1 = 当前 error 所在位置
		2 = 调用当前函数的位置
		3 = 再上一层调用者
	]]
end

return Logger
