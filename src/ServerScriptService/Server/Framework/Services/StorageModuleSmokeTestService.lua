--!strict

local StorageModuleSmokeTestService = {
	Name = "StorageModuleSmokeTestService",
}

StorageModuleSmokeTestService._logger = nil
StorageModuleSmokeTestService._services = nil

local TEST_KEY = "__storage_module_smoke_test__"
local TEST_VALUE = 1
local DIRTY_VALUE = 999

function StorageModuleSmokeTestService:Init(context)
	self._logger = context.Logger
	self._services = context.Services
end

function StorageModuleSmokeTestService:Start()
	local storageService = self._services.StorageService
	if storageService == nil then
		error("StorageService is missing", 2)
	end

	storageService:RemoveKey(TEST_KEY)

	local openedData = storageService:OpenKey(TEST_KEY)
	if type(openedData) ~= "table" or type(openedData.SchemaVersion) ~= "number" then
		error("OpenKey returned invalid storage data", 2)
	end

	local updatedData = storageService:UpdateKey(TEST_KEY, function(data)
		data.SmokeValue = TEST_VALUE
		return data
	end)
	if updatedData.SmokeValue ~= TEST_VALUE then
		error("UpdateKey did not write smoke test value", 2)
	end

	local copiedData = storageService:GetKey(TEST_KEY)
	copiedData.SmokeValue = DIRTY_VALUE

	local currentData = storageService:GetKey(TEST_KEY)
	if currentData.SmokeValue ~= TEST_VALUE then
		error("GetKey returned mutable internal storage data", 2)
	end

	storageService:RemoveKey(TEST_KEY)

	local reopenedData = storageService:OpenKey(TEST_KEY)
	if reopenedData.SmokeValue ~= nil then
		error("RemoveKey did not clear smoke test data", 2)
	end

	storageService:RemoveKey(TEST_KEY)
	self._logger.Info(self.Name, "StorageModule 冒烟测试通过")
end

return StorageModuleSmokeTestService
