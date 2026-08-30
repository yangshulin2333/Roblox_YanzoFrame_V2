--!strict

-- 默认 Warn：正常启动只显示警告和错误，避免 Roblox 输出窗口被启动流程刷屏。
-- 调试时可改成 "Info" 或 "Debug"；也可以只打开某个 scope 的日志。
local LogConfig = {
	DefaultLevel = "Warn",
	ScopeLevels = {
		-- NetService = "Debug",
		-- ServiceRegistry = "Info",
	},
}

return LogConfig
