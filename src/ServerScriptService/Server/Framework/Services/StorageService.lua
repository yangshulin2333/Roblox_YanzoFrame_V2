--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemoryStorage = require(ReplicatedStorage.Framework.Shared.Storage.MemoryStorage)
local StorageConfig = require(ReplicatedStorage.Module.Shared.Config.StorageConfig)

local StorageService = {
	Name = "StorageService",
}

StorageService._logger = nil
StorageService._storage = nil

local function getPlayerKey(player)
	return tostring(player.UserId)
end

function StorageService:Init(context)
	self._logger = context.Logger
	self._storage = MemoryStorage.new(StorageConfig.DefaultData, StorageConfig.Validate)
end

function StorageService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:OpenPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ClosePlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:OpenPlayer(player)
	end

	self._logger.Info(self.Name, "Memory storage ready")
end

function StorageService:_getStorage()
	if self._storage == nil then
		error("StorageService is not initialized", 2)
	end
	return self._storage
end

function StorageService:OpenKey(key)
	return self:_getStorage():Open(key)
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

function StorageService:RemoveKey(key)
	self:_getStorage():Remove(key)
end

function StorageService:OpenPlayer(player)
	local data = self:OpenKey(getPlayerKey(player))
	self._logger.Info(self.Name, "Opened data for " .. player.Name)
	return data
end

function StorageService:ClosePlayer(player)
	self:RemoveKey(getPlayerKey(player))
	self._logger.Info(self.Name, "Closed data for " .. player.Name)
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

return StorageService
