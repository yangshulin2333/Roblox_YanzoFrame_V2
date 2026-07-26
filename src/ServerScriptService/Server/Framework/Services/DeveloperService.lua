--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DeveloperConfig = require(ReplicatedStorage.Module.Shared.Config.DeveloperConfig)
local _LoggerModule = require(ReplicatedStorage.Framework.Shared.App.Logger)
local NetResult = require(ReplicatedStorage.Framework.Shared.Net.NetResult)
local RemoteNames = require(ReplicatedStorage.Framework.Shared.Net.RemoteNames)

type LoggerType = typeof(_LoggerModule)

type StorageServiceType = {
	ResetPlayerData: (self: any, player: Player) -> (boolean, string),
}

type RequestHandler = (player: Player, payload: unknown) -> unknown

type NetServiceType = {
	RegisterRequest: (self: any, remoteName: string, handler: RequestHandler) -> RemoteFunction,
}

type ServiceDependencies = {
	StorageService: StorageServiceType?,
	NetService: NetServiceType?,
}

type ServiceInitContext = {
	Logger: LoggerType,
	Services: ServiceDependencies,
}

local DeveloperService = {
	Name = "DeveloperService",
}

DeveloperService._logger = nil :: LoggerType?
DeveloperService._services = nil :: ServiceDependencies?

-- 保存框架服务引用，供后续权限校验和数据初始化使用。
function DeveloperService:Init(context: ServiceInitContext)
	self._logger = context.Logger
	self._services = context.Services
end

-- 取得已注入的 Logger；在使用前完成可空值收窄并暴露框架配置错误。
function DeveloperService:_getLogger(): LoggerType
	local logger = self._logger
	if logger == nil then
		error("Logger is missing", 2)
	end

	return logger
end

-- 取得已注册的存档服务，缺失时直接暴露框架配置错误。
function DeveloperService:_getStorageService()
	local services = self._services
	if services == nil then
		error("Service dependencies are missing", 2)
	end

	local storageService = services.StorageService
	if storageService == nil then
		error("StorageService is missing", 2)
	end

	return storageService
end

-- 判断当前玩家是否可使用开发期整档初始化入口。
function DeveloperService:_isDataResetAllowed(player)
	if DeveloperConfig.EnableDataReset ~= true then
		return false, "DEVELOPER_RESET_DISABLED"
	end

	if RunService:IsStudio() then
		if DeveloperConfig.AllowDataResetInStudio == true then
			return true
		end

		return false, "DEVELOPER_RESET_DISABLED"
	end

	if DeveloperConfig.IsUserAllowed(player.UserId) then
		return true
	end

	return false, "DEVELOPER_NOT_ALLOWED"
end

-- 初始化当前玩家整档数据，并安排重新进入以清除所有运行时缓存。
function DeveloperService:ResetCurrentPlayerData(player)
	if player.Parent ~= Players then
		return false, "PLAYER_LEFT"
	end

	local isAllowed, allowCode = self:_isDataResetAllowed(player)
	if not isAllowed then
		return false, allowCode
	end

	local storageService = self:_getStorageService()
	local didReset, resetCode = storageService:ResetPlayerData(player)
	if not didReset then
		return false, resetCode
	end

	local logger = self:_getLogger()
	logger.Warn(
		self.Name,
		"开发者已初始化当前玩家存档: " .. player.Name .. " / " .. tostring(player.UserId)
	)

	-- 让 RemoteFunction 先把成功结果返回给客户端，再触发玩家离开保存默认档案。
	task.defer(function()
		if player.Parent == Players then
			player:Kick("开发者已初始化你的存档，请重新进入游戏。")
		end
	end)

	return true, "DATA_RESET_COMPLETE"
end

-- 注册仅用于开发期的“初始化我自己的数据”请求，不接收目标玩家或数据字段。
function DeveloperService:Start()
	local services = self._services
	if services == nil then
		error("Service dependencies are missing", 2)
	end

	local netService = services.NetService
	if netService == nil then
		error("NetService is missing", 2)
	end

	netService:RegisterRequest(RemoteNames.DeveloperResetMyData, function(player, payload)
		if type(payload) ~= "table" or next(payload) ~= nil then
			return NetResult.Err("INVALID_PAYLOAD", "重置请求不能包含数据字段")
		end

		local didReset, resetCode = self:ResetCurrentPlayerData(player)
		if not didReset then
			return NetResult.Err(resetCode, "初始化当前玩家数据失败")
		end

		return {
			RejoinRequired = true,
		}
	end)

	local logger = self:_getLogger()
	logger.Info(self.Name, "开发者数据初始化入口已就绪")
end

return DeveloperService
