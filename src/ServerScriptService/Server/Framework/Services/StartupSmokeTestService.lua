--!strict

local StartupSmokeTestService = {
	Name = "StartupSmokeTestService",
}

StartupSmokeTestService._logger = nil
StartupSmokeTestService._services = nil

function StartupSmokeTestService:Init(context)
	self._logger = context.Logger
	self._services = context.Services --拿到 ServiceRegistry._servicesByName 这个字典表，里面有所有服务的引用。
end

function StartupSmokeTestService:Start()
	if self._services.NetService == nil then --如果是 nil，说明 NetService 没有被注册进服务字典。
		error("NetService is missing", 2)
	end

	if self._services.StorageService == nil then
		error("StorageService is missing", 2)
	end

	local testKey = "__startup_check__"
	local data = self._services.StorageService:OpenKey(testKey) --拿到 StorageService._storage 这个 MemoryStorage 对象，调用它的 Open() 方法，返回一个数据表。
	if type(data) ~= "table" or type(data.SchemaVersion) ~= "number" then
		error("StorageService returned invalid data", 2)
	end

	self._services.StorageService:RemoveKey(testKey)

	self._logger.Info(self.Name, "服务端启动冒烟测试通过")
end

return StartupSmokeTestService
