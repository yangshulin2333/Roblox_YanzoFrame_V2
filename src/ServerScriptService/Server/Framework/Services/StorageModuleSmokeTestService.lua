--!strict

local StorageModuleSmokeTestService = {
	Name = "StorageModuleSmokeTestService",
}

StorageModuleSmokeTestService._logger = nil
StorageModuleSmokeTestService._services = nil

local TEST_KEY = "__storage_module_smoke_test__"
local TEST_VALUE = 1
local DIRTY_VALUE = 999
local TEST_MODULE_NAME = "__SmokeTest__"

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

	if type(openedData.Settings) ~= "table" or openedData.Settings.Language ~= "zh-CN" then
		error("OpenKey returned invalid settings data", 2)
	end

	if type(openedData.Modules) ~= "table" then
		error("OpenKey returned invalid modules data", 2)
	end

	local updatedData = storageService:UpdateKey(TEST_KEY, function(data)
		data.Modules[TEST_MODULE_NAME] = {
			Value = TEST_VALUE,
		}
		return data
	end)
	if updatedData.Modules[TEST_MODULE_NAME].Value ~= TEST_VALUE then
		error("UpdateKey did not write smoke test value", 2)
	end

	local copiedData = storageService:GetKey(TEST_KEY)
	copiedData.Modules[TEST_MODULE_NAME].Value = DIRTY_VALUE

	local currentData = storageService:GetKey(TEST_KEY)
	if currentData.Modules[TEST_MODULE_NAME].Value ~= TEST_VALUE then
		error("GetKey returned mutable internal storage data", 2)
	end

	storageService:RemoveKey(TEST_KEY)

	local reopenedData = storageService:OpenKey(TEST_KEY)
	if reopenedData.Modules[TEST_MODULE_NAME] ~= nil then
		error("RemoveKey did not clear smoke test data", 2)
	end

	local fakePlayer = {
		UserId = -1,
		Name = "StorageModuleSmokeTest",
	}

	storageService:RemoveKey(tostring(fakePlayer.UserId))
	storageService:OpenPlayer(fakePlayer)

	storageService:UpdatePlayerModuleData(fakePlayer, TEST_MODULE_NAME, {
		Value = 0,
	}, function(moduleData)
		moduleData.Value = TEST_VALUE
		return moduleData
	end)

	local moduleData = storageService:GetPlayerModuleData(fakePlayer, TEST_MODULE_NAME)
	if moduleData.Value ~= TEST_VALUE then
		error("Player module data API did not write smoke test value", 2)
	end

	moduleData.Value = DIRTY_VALUE
	local freshModuleData = storageService:GetPlayerModuleData(fakePlayer, TEST_MODULE_NAME)
	if freshModuleData.Value ~= TEST_VALUE then
		error("GetPlayerModuleData returned mutable internal module data", 2)
	end

	storageService:ClosePlayer(fakePlayer)

	storageService:RemoveKey(TEST_KEY)
	self._logger.Info(self.Name, "StorageModule 冒烟测试通过")
end

return StorageModuleSmokeTestService
