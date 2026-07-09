--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Framework.Shared.Net.RemoteNames)
local NetResult = require(ReplicatedStorage.Framework.Shared.Net.NetResult)
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

function PlayerSettingsService:Start()
	local netService = self._services.NetService
	if netService == nil then
		error("NetService is missing", 2)
	end

	netService:RegisterRequest(RemoteNames.PlayerSettingsGetLanguage, function(player, _payload)
		return {
			Language = self:GetLanguage(player),
		}
	end)

	netService:RegisterRequest(RemoteNames.PlayerSettingsSetLanguage, function(player, payload)
		if type(payload) ~= "table" or type(payload.Language) ~= "string" then
			return NetResult.Err("INVALID_PAYLOAD", "Language payload is invalid")
		end

		local ok, err = self:SetLanguage(player, payload.Language)
		if not ok then
			return NetResult.Err(tostring(err), "Language is not supported")
		end

		return {
			Language = self:GetLanguage(player),
		}
	end)
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
