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
		local language, getError = self:GetLanguage(player)
		if language == nil then
			return NetResult.Err(tostring(getError), "Player data is not ready")
		end

		return {
			Language = language,
		}
	end, 0.5)

	netService:RegisterRequest(RemoteNames.PlayerSettingsSetLanguage, function(player, payload)
		if type(payload) ~= "table" or type(payload.Language) ~= "string" then
			return NetResult.Err("INVALID_PAYLOAD", "Language payload is invalid")
		end

		local ok, err = self:SetLanguage(player, payload.Language)
		if not ok then
			local message = err == "DATA_NOT_READY" and "Player data is not ready" or "Language is not supported"
			return NetResult.Err(tostring(err), message)
		end

		return {
			Language = self:GetLanguage(player),
		}
	end, 1)
end

function PlayerSettingsService:_getStorageService()
	local storageService = self._services.StorageService
	if storageService == nil then
		error("StorageService is missing", 2)
	end
	return storageService
end

function PlayerSettingsService:GetLanguage(player)
	local storageService = self:_getStorageService()
	if not storageService:IsPlayerDataReady(player) then
		return nil, "DATA_NOT_READY"
	end

	local data = storageService:GetPlayerData(player)
	return data.Settings.Language
end

function PlayerSettingsService:SetLanguage(player, language)
	if not StorageConfig.IsSupportedLanguage(language) then
		return false, "UNSUPPORTED_LANGUAGE"
	end

	local storageService = self:_getStorageService()
	if not storageService:IsPlayerDataReady(player) then
		return false, "DATA_NOT_READY"
	end

	storageService:UpdatePlayerData(player, function(data)
		data.Settings.Language = language
		return data
	end)

	return true
end

return PlayerSettingsService
