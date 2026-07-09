--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StorageConfig = require(ReplicatedStorage.Module.Shared.Config.StorageConfig)

local PlayerSettingsService = {
	Name = "PlayerSettingsService",
}

PlayerSettingsService._logger = nil
PlayerSettingsService._services = nil

function PlayerSettingsService:Init(context)
	self._logger = context.Logger
	self._services = context.Services
end

function PlayerSettingsService:_getStorageService()
	local storageService = self._services.StorageService
	if storageService == nil then
		error("StorageService is missing", 2)
	end
	return storageService
end

function PlayerSettingsService:GetLanguage(player)
	local data = self:_getStorageService():GetPlayerData(player)
	return data.Settings.Language
end

function PlayerSettingsService:SetLanguage(player, language)
	if not StorageConfig.IsSupportedLanguage(language) then
		return false, "UNSUPPORTED_LANGUAGE"
	end

	self:_getStorageService():UpdatePlayerData(player, function(data)
		data.Settings.Language = language
		return data
	end)

	return true
end

return PlayerSettingsService
