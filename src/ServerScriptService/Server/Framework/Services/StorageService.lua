--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemoryStorage = require(ReplicatedStorage.Framework.Shared.Storage.MemoryStorage)
local TableUtil = require(ReplicatedStorage.Framework.Shared.Util.TableUtil)
local StorageConfig = require(ReplicatedStorage.Module.Shared.Config.StorageConfig)
local ProfileStoreStorage = require(script.Parent.Parent.Storage.ProfileStoreStorage)

local StorageService = {
	Name = "StorageService",
}

StorageService._logger = nil
StorageService._storage = nil
StorageService._openingByKey = {}
StorageService._cancelOpenByKey = {}
StorageService._playerDataStatusByKey = {}

local PLAYER_DATA_STATUS_LOADING = "LOADING"
local PLAYER_DATA_STATUS_READY = "READY"
local PLAYER_DATA_STATUS_LOAD_FAILED = "LOAD_FAILED"
local PLAYER_DATA_STATUS_SESSION_ENDED = "SESSION_ENDED"

local function getPlayerKey(player)
	return tostring(player.UserId)
end

-- 校验可选的等待超时秒数，nil 表示持续等待直到出现确定结果。
local function assertOptionalTimeout(timeoutSeconds)
	if timeoutSeconds == nil then
		return nil
	end

	if
		type(timeoutSeconds) ~= "number"
		or timeoutSeconds ~= timeoutSeconds
		or timeoutSeconds == math.huge
		or timeoutSeconds == -math.huge
		or timeoutSeconds < 0
	then
		error("timeoutSeconds 必须是大于或等于 0 的有限数字或 nil", 3)
	end

	return timeoutSeconds
end

local function assertModuleName(moduleName)
	if type(moduleName) ~= "string" or moduleName == "" then
		error("moduleName must be a non-empty string", 3)
	end
	return moduleName
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
	self._playerDataStatusByKey = {}
end

function StorageService:_openPlayerSafely(player)
	local key = getPlayerKey(player)
	local ok, data, openError = pcall(self.OpenPlayer, self, player)

	if not ok then
		if player.Parent == Players then
			self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_LOAD_FAILED
		end
		self._logger.Warn(self.Name, "Player data load crashed: " .. player.Name .. " / " .. tostring(data))
	elseif data ~= nil then
		return
	else
		if player.Parent == Players then
			self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_LOAD_FAILED
		end
		self._logger.Warn(self.Name, "Player data load failed: " .. player.Name .. " / " .. tostring(openError))
	end

	if player.Parent == Players then
		player:Kick("Player data could not be loaded. Please rejoin.")
	end
end

-- 关服时不需要在这里额外保存数据：ProfileStore 库自己注册了 game:BindToClose，
-- 会保存并释放所有还开着的 profile，并且真的等保存完成才放行关服。
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

	if player.Parent ~= Players then
		return nil, "PLAYER_LEFT"
	end

	if self:IsKeyOpen(key) then
		self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_READY
		return self:GetKey(key)
	end

	if self._openingByKey[key] ~= nil then
		self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_LOADING

		while self._openingByKey[key] ~= nil do
			if player.Parent ~= Players then
				return nil, "PLAYER_LEFT"
			end

			local status = self._playerDataStatusByKey[key]
			if status == PLAYER_DATA_STATUS_LOAD_FAILED then
				return nil, "DATA_LOAD_FAILED"
			end

			if status == PLAYER_DATA_STATUS_SESSION_ENDED then
				return nil, "DATA_SESSION_ENDED"
			end

			task.wait(StorageConfig.PlayerDataReadyPollSeconds)
		end

		if self:IsKeyOpen(key) then
			self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_READY
			return self:GetKey(key)
		end

		local status = self._playerDataStatusByKey[key]
		if status == PLAYER_DATA_STATUS_LOAD_FAILED then
			return nil, "DATA_LOAD_FAILED"
		end

		if status == PLAYER_DATA_STATUS_SESSION_ENDED then
			return nil, "DATA_SESSION_ENDED"
		end
	end

	local openingToken = {}
	self._openingByKey[key] = openingToken
	self._cancelOpenByKey[key] = nil
	self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_LOADING

	local function finishOpening()
		if self._openingByKey[key] == openingToken then
			self._openingByKey[key] = nil
			self._cancelOpenByKey[key] = nil
		end
	end

	local ok, data, openError = pcall(self.OpenKey, self, key, {
		UserId = player.UserId,
		Cancel = function()
			return self._cancelOpenByKey[key] == true or player.Parent ~= Players
		end,
		OnSessionEnd = function(wasClosed)
			if not wasClosed then
				if player.Parent == Players then
					self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_SESSION_ENDED
				end
				self._logger.Warn(self.Name, "Player data session ended unexpectedly: " .. player.Name)
				if player.Parent == Players then
					player:Kick("Player data session ended. Please rejoin.")
				end
			end
		end,
	})

	if not ok then
		if player.Parent == Players then
			self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_LOAD_FAILED
		end
		finishOpening()
		error(data, 2)
	end

	if data == nil then
		if player.Parent == Players then
			self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_LOAD_FAILED
		end
		finishOpening()
		return nil, openError
	end

	if player.Parent ~= Players then
		local closeOk, closeError = pcall(self.CloseKey, self, key)
		finishOpening()
		if not closeOk then
			error(closeError, 2)
		end
		return nil, "PLAYER_LEFT_DURING_LOAD"
	end

	self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_READY
	finishOpening()
	self._logger.Debug(self.Name, "Player data opened: " .. player.Name)
	return data
end

function StorageService:IsPlayerDataReady(player)
	return self:IsKeyOpen(getPlayerKey(player))
end

-- 等待指定玩家的数据就绪，并把离开、加载失败、会话中断和超时统一为结果码。
function StorageService:WaitForPlayerData(player, timeoutSeconds)
	timeoutSeconds = assertOptionalTimeout(timeoutSeconds)

	local key = getPlayerKey(player)
	local deadline = nil
	if timeoutSeconds ~= nil then
		deadline = os.clock() + timeoutSeconds
	end

	while player.Parent == Players do
		if self:IsKeyOpen(key) then
			self._playerDataStatusByKey[key] = PLAYER_DATA_STATUS_READY
			return true, PLAYER_DATA_STATUS_READY
		end

		local status = self._playerDataStatusByKey[key]
		if status == PLAYER_DATA_STATUS_LOAD_FAILED then
			return false, "DATA_LOAD_FAILED"
		end

		if status == PLAYER_DATA_STATUS_SESSION_ENDED then
			return false, "DATA_SESSION_ENDED"
		end

		if deadline ~= nil and os.clock() >= deadline then
			return false, "DATA_READY_TIMEOUT"
		end

		task.wait(StorageConfig.PlayerDataReadyPollSeconds)
	end

	return false, "PLAYER_LEFT"
end

function StorageService:ClosePlayer(player)
	local key = getPlayerKey(player)
	self._cancelOpenByKey[key] = true

	if self:IsKeyOpen(key) then
		self:CloseKey(key)
		self._logger.Debug(self.Name, "Player data closed: " .. player.Name)
	end

	self._playerDataStatusByKey[key] = nil
end

function StorageService:GetPlayerData(player)
	return self:GetKey(getPlayerKey(player))
end

function StorageService:SetPlayerData(player, data)
	return self:SetKey(getPlayerKey(player), data)
end

-- 将指定已打开玩家的整份存档恢复为当前默认结构。
function StorageService:ResetPlayerData(player)
	if not self:IsPlayerDataReady(player) then
		return false, "DATA_NOT_READY"
	end

	local defaultData = TableUtil.DeepCopy(StorageConfig.DefaultData)
	local ok, dataOrError = pcall(self.SetPlayerData, self, player, defaultData)
	if not ok then
		self._logger.Warn(self.Name, "初始化玩家存档失败: " .. player.Name .. " / " .. tostring(dataOrError))
		return false, "DATA_RESET_FAILED"
	end

	return true, dataOrError
end

function StorageService:UpdatePlayerData(player, updateFn)
	return self:UpdateKey(getPlayerKey(player), updateFn)
end

function StorageService:GetPlayerModuleData(player, moduleName)
	moduleName = assertModuleName(moduleName)
	local data = self:GetPlayerData(player)
	return TableUtil.DeepCopy(data.Modules[moduleName])
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
			moduleData = TableUtil.DeepCopy(defaultModuleData or {})
			data.Modules[moduleName] = moduleData
		end

		local nextModuleData = updateFn(moduleData)
		if nextModuleData ~= nil then
			data.Modules[moduleName] = nextModuleData
		end

		return data
	end)

	return TableUtil.DeepCopy(updatedData.Modules[moduleName])
end

return StorageService
