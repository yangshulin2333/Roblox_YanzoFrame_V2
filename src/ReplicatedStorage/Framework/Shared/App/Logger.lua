--!strict

local Logger = {}

local function formatMessage(level, scope, message)
	return string.format("[模块开发][%s][%s] %s", level, scope, message)
end

function Logger.Debug(scope, message)
	print(formatMessage("调试", scope, message))
end

function Logger.Info(scope, message)
	print(formatMessage("信息", scope, message))
end

function Logger.Warn(scope, message)
	warn(formatMessage("警告", scope, message))
end

function Logger.Error(scope, message)
	error(formatMessage("错误", scope, message), 2)
end

return Logger
