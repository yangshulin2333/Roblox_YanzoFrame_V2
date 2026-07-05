--!strict

local StartupSmokeTestService = {
	Name = "StartupSmokeTestService",
}

StartupSmokeTestService._logger = nil
StartupSmokeTestService._services = nil

function StartupSmokeTestService:Init(context)
	self._logger = context.Logger
	self._services = context.Services
end

function StartupSmokeTestService:Start()
	if self._services.NetService == nil then
		error("NetService is missing", 2)
	end

	if self._services.StorageService == nil then
		error("StorageService is missing", 2)
	end

	local testKey = "__startup_check__"
	local data = self._services.StorageService:OpenKey(testKey)
	if type(data) ~= "table" or type(data.SchemaVersion) ~= "number" then
		error("StorageService returned invalid data", 2)
	end
	self._services.StorageService:RemoveKey(testKey)

	self._logger.Info(self.Name, "服务端启动冒烟测试通过")
end

return StartupSmokeTestService
