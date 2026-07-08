--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Framework.Shared.Net.RemoteNames)

local StartupSmokeTestController = {
	Name = "StartupSmokeTestController",
}

StartupSmokeTestController._logger = nil
StartupSmokeTestController._net = nil

--被ControllerRegistry调用，接收的参数是registry._context
function StartupSmokeTestController:Init(context)
	--等价于StartupSmokeTestController._logger = registry._context.Logger
	self._logger = context.Logger
	self._net = context.Net --为了在客户端进行启动烟雾测试，我们需要使用Net模块来发送请求到服务器端的RemoteEvent或RemoteFunction。
end

function StartupSmokeTestController:Start()
	--task.defer 里的函数会记住当前的 self。 会等待服务端返回结果，如果直接同步执行，可能让客户端启动流程被网络请求卡住。
	task.defer(function()
		--核心代码，客户端向服务端发起 Framework.Ping 请求，不带 payload。
		local result = self._net.Request(RemoteNames.FrameworkPing, {})

		if result.Ok then
			self._logger.Info(self.Name, "客户端启动冒烟测试通过")
		else
			self._logger.Warn(self.Name, "客户端启动冒烟测试失败: " .. tostring(result.Code))
		end
	end)
end

return StartupSmokeTestController
