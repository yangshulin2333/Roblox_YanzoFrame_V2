--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemoryStorage = require(ReplicatedStorage.Framework.Shared.Storage.MemoryStorage)
local StorageConfig = require(ReplicatedStorage.Module.Shared.Config.StorageConfig)
local ProfileStoreStorage = require(script.Parent.Parent.Storage.ProfileStoreStorage)

local StorageService = {
	Name = "StorageService",
}

StorageService._logger = nil
StorageService._storage = nil
StorageService._openingByKey = {}
StorageService._cancelOpenByKey = {}

local function getPlayerKey(player)
	return tostring(player.UserId)
end

local function assertModuleName(moduleName)
	if type(moduleName) ~= "string" or moduleName == "" then
		error("moduleName must be a non-empty string", 3)
	end
	return moduleName
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[deepCopy(key)] = deepCopy(item)
	end
	return copy
end

local function createStorageBackend()
	if StorageConfig.Backend == "Memory" then
		return MemoryStorage.new(StorageConfig.DefaultData, StorageConfig.Validate)
	end

	if StorageConfig.Backend == "ProfileStore" then
		return ProfileStoreStorage.new(
			StorageConfig.ProfileStoreName,
			StorageConfig.DefaultData,
			StorageConfig.Validate
		)
	end

	error("Unsupported storage backend: " .. tostring(StorageConfig.Backend), 2)
end

function StorageService:Init(context)
	self._logger = context.Logger
	self._storage = createStorageBackend()
	self._openingByKey = {}
	self._cancelOpenByKey = {}
end

function StorageService:_openPlayerSafely(player)
	local ok, data, openError = pcall(self.OpenPlayer, self, player)

	if not ok then
		self._logger.Warn(self.Name, "Player data load crashed: " .. player.Name .. " / " .. tostring(data))
	elseif data ~= nil then
		return
	else
		self._logger.Warn(self.Name, "Player data load failed: " .. player.Name .. " / " .. tostring(openError))
	end

	if player.Parent == Players then
		player:Kick("Player data could not be loaded. Please rejoin.")
	end
end

function StorageService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:_openPlayerSafely(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ClosePlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_openPlayerSafely(player)
		end)
	end

	self._logger.Info(self.Name, "Storage service started with backend: " .. StorageConfig.Backend)
end

function StorageService:_getStorage()
	if self._storage == nil then
		error("StorageService is not initialized", 2)
	end
	return self._storage
end

function StorageService:IsKeyOpen(key)
	return self:_getStorage():IsOpen(key)
end

function StorageService:OpenKey(key, options)
	return self:_getStorage():Open(key, options)
end

function StorageService:GetKey(key)
	return self:_getStorage():Get(key)
end

function StorageService:SetKey(key, data)
	return self:_getStorage():Set(key, data)
end

function StorageService:UpdateKey(key, updateFn)
	return self:_getStorage():Update(key, updateFn)
end

function StorageService:CloseKey(key)
	self:_getStorage():Close(key)
end

function StorageService:OpenPlayer(player)
	local key = getPlayerKey(player)

	if self:IsKeyOpen(key) then
		return self:GetKey(key)
	end

	if self._openingByKey[key] then
		return nil, "PLAYER_DATA_ALREADY_LOADING"
	end

	self._openingByKey[key] = true
	self._cancelOpenByKey[key] = nil

	local ok, data, openError = pcall(self.OpenKey, self, key, {
		UserId = player.UserId,
		Cancel = function()
			return self._cancelOpenByKey[key] == true or player.Parent ~= Players
		end,
		OnSessionEnd = function(wasClosed)
			if not wasClosed then
				self._logger.Warn(self.Name, "Player data session ended unexpectedly: " .. player.Name)
				if player.Parent == Players then
					player:Kick("Player data session ended. Please rejoin.")
				end
			end
		end,
	})

	self._openingByKey[key] = nil
	self._cancelOpenByKey[key] = nil

	if not ok then
		error(data, 2)
	end

	if data == nil then
		return nil, openError
	end

	if player.Parent ~= Players then
		self:CloseKey(key)
		return nil, "PLAYER_LEFT_DURING_LOAD"
	end

	self._logger.Debug(self.Name, "Player data opened: " .. player.Name)
	return data
end

function StorageService:IsPlayerDataReady(player)
	return self:IsKeyOpen(getPlayerKey(player))
end

function StorageService:ClosePlayer(player)
	local key = getPlayerKey(player)
	self._cancelOpenByKey[key] = true

	if self:IsKeyOpen(key) then
		self:CloseKey(key)
		self._logger.Debug(self.Name, "Player data closed: " .. player.Name)
	end
end

function StorageService:GetPlayerData(player)
	return self:GetKey(getPlayerKey(player))
end

function StorageService:SetPlayerData(player, data)
	return self:SetKey(getPlayerKey(player), data)
end

function StorageService:UpdatePlayerData(player, updateFn)
	return self:UpdateKey(getPlayerKey(player), updateFn)
end

function StorageService:GetPlayerModuleData(player, moduleName)
	moduleName = assertModuleName(moduleName)
	local data = self:GetPlayerData(player)
	return deepCopy(data.Modules[moduleName])
end

function StorageService:UpdatePlayerModuleData(player, moduleName, defaultModuleData, updateFn)
	moduleName = assertModuleName(moduleName)

	if defaultModuleData ~= nil and type(defaultModuleData) ~= "table" then
		error("defaultModuleData must be a table or nil", 2)
	end

	if type(updateFn) ~= "function" then
		error("updateFn must be a function", 2)
	end

	local updatedData = self:UpdatePlayerData(player, function(data)
		local moduleData = data.Modules[moduleName]
		if moduleData == nil then
			moduleData = deepCopy(defaultModuleData or {})
			data.Modules[moduleName] = moduleData
		end

		local nextModuleData = updateFn(moduleData)
		if nextModuleData ~= nil then
			data.Modules[moduleName] = nextModuleData
		end

		return data
	end)

	return deepCopy(updatedData.Modules[moduleName])
end

return StorageService
