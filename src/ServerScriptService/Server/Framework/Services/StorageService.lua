--!strict

--StorageConfig 管规则，MemoryStorage 管数据容器，StorageService 管服务器入口和玩家接口。
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemoryStorage = require(ReplicatedStorage.Framework.Shared.Storage.MemoryStorage)
local StorageConfig = require(ReplicatedStorage.Module.Shared.Config.StorageConfig)

local StorageService = {
	Name = "StorageService", --被 ServiceRegistry 使用
}

StorageService._logger = nil
StorageService._storage = nil --后面Init(context)时会保存真正的 MemoryStorage 对象

local function getPlayerKey(player)
	return tostring(player.UserId)
end

local function assertModuleName(moduleName)
	if type(moduleName) ~= "string" or moduleName == "" then
		error("moduleName必须是非空字符串", 3)
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

function StorageService:Init(context)
	self._logger = context.Logger
	-- self._services = context.Services
	--StorageService._storage 指向 MemoryStorage.new() 返回的 MemoryStorage 实例表。
	self._storage = MemoryStorage.new(StorageConfig.DefaultData, StorageConfig.Validate)
	--[[
		StorageService._storage = {
		_defaultData = {
			SchemaVersion = 1,
		},
		_validate = StorageConfig.Validate,
		_dataByKey = {},
		}
	]]
end

function StorageService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:OpenPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ClosePlayer(player)
	end)

	--返回一个数组表，里面是当前所有在线玩家的对象。
	for _, player in ipairs(Players:GetPlayers()) do
		self:OpenPlayer(player)
	end

	self._logger.Info(self.Name, "存储服务已启动")
end

--拿到内部 MemoryStorage 对象，如果还没初始化，就报错。
function StorageService:_getStorage()
	if self._storage == nil then
		error("StorageService没有初始化", 2)
	end
	return self._storage
end

--打开一个键，如果不存在就创建默认数据的副本，并返回它。
function StorageService:OpenKey(key)
	return self:_getStorage():Open(key) --return storage:Open(key)
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

--打开某个玩家的数据。
function StorageService:OpenPlayer(player)
	local data = self:OpenKey(getPlayerKey(player))
	self._logger.Debug(self.Name, "已打开玩家数据： " .. player.Name)
	return data
end

function StorageService:ClosePlayer(player)
	self:RemoveKey(getPlayerKey(player))
	self._logger.Debug(self.Name, "已关闭玩家数据： " .. player.Name)
end

function StorageService:GetPlayerData(player)
	--玩家数据用 UserId 当 key，非玩家数据可以用自定义字符串 key。
	--当前基础框架为了学习和简单，把 Get 也做成“没有就创建”。
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
	return data.Modules[moduleName]
end

function StorageService:UpdatePlayerModuleData(player, moduleName, defaultModuleData, updateFn)
	moduleName = assertModuleName(moduleName)

	if defaultModuleData ~= nil and type(defaultModuleData) ~= "table" then
		error("defaultModuleData必须是table类型或nil", 2)
	end

	if type(updateFn) ~= "function" then
		error("updateFn必须是function类型", 2)
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

	return updatedData.Modules[moduleName]
end

return StorageService
