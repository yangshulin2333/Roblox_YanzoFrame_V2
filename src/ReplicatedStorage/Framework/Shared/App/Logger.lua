--!strict
--统一输出格式，方便以后看日志、排错。
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LogConfig = require(ReplicatedStorage.Module.Shared.Config.LogConfig)

local Logger = {}

local LEVEL_VALUES = {
	Debug = 10,
	Info = 20,
	Warn = 30,
	Error = 40,
}

local currentLevel = LogConfig.DefaultLevel or "Warn"
local scopeLevels = LogConfig.ScopeLevels or {}

--[[
	level   日志等级，比如 信息 / 警告 / 错误
	scope   日志来源，比如 ServiceRegistry / NetService
	message 具体日志内容
]]
-- 统一拼接日志文本；调用来源存在时附带脚本与行号，方便从 Output 反查业务调用点。
local function formatMessage(level, scope, message, source, line)
	local callerSuffix = ""
	if type(source) == "string" and type(line) == "number" then
		callerSuffix = string.format(" [%s:%d]", source, line)
	end

	return string.format("[YanzoFrame_V1_StorageModule][%s][%s] %s%s", level, scope, message, callerSuffix)
end

local function getLevelValue(level)
	local value = LEVEL_VALUES[level]
	if value == nil then
		return LEVEL_VALUES.Warn
	end
	return value
end

--[[
	判断是否应该输出日志
	level   日志等级，比如 信息 / 警告 / 错误
	scope   日志来源，比如 ServiceRegistry / NetService
]]
local function shouldLog(level, scope)
	local scopeLevel = scopeLevels[scope]
	local minLevel = currentLevel

	if scopeLevel ~= nil then
		minLevel = scopeLevel
	end

	return getLevelValue(level) >= getLevelValue(minLevel)
end

function Logger.SetLevel(level)
	if LEVEL_VALUES[level] == nil then
		error("Unknown log level: " .. tostring(level), 2)
	end

	currentLevel = level
end

function Logger.SetScopeLevel(scope, level)
	if LEVEL_VALUES[level] == nil then
		error("Unknown log level: " .. tostring(level), 2)
	end

	scopeLevels[scope] = level
end

function Logger.IsEnabled(level, scope)
	if LEVEL_VALUES[level] == nil then
		return false
	end

	return shouldLog(level, scope)
end

function Logger.Debug(scope, message)
	if not shouldLog("Debug", scope) then
		return
	end

	-- 第 2 层是调用 Logger.Debug 的业务代码；第 1 层仍会指向 Logger 自己。
	local source, line = debug.info(2, "sl")
	print(formatMessage("Debug", scope, message, source, line))
end

function Logger.Info(scope, message)
	if not shouldLog("Info", scope) then
		return
	end

	-- 第 2 层是调用 Logger.Info 的业务代码；第 1 层仍会指向 Logger 自己。
	local source, line = debug.info(2, "sl")
	print(formatMessage("Info", scope, message, source, line))
end

function Logger.Warn(scope, message)
	if not shouldLog("Warn", scope) then
		return
	end

	-- 第 2 层是调用 Logger.Warn 的业务代码；第 1 层仍会指向 Logger 自己。
	local source, line = debug.info(2, "sl")
	warn(formatMessage("Warn", scope, message, source, line))
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
