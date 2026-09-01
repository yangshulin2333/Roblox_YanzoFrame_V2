--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Framework.Shared.App.Logger)
local Lifecycle = require(ReplicatedStorage.Framework.Shared.App.Lifecycle)

local ServiceRegistry = {}
ServiceRegistry.__index = ServiceRegistry

function ServiceRegistry.new(services)
	if type(services) ~= "table" then
		error("services must be a table", 2)
	end

	local self = setmetatable({}, ServiceRegistry)
	self._services = services

	self._servicesByName = {}
	self._initialized = false
	self._started = false
	self._context = {
		Logger = Logger,
		Services = self._servicesByName,
	}
	return self
end

function ServiceRegistry:GetService(name)
	return self._servicesByName[name]
end

function ServiceRegistry:Init()
	if self._initialized then
		error("ServiceRegistry:Init() was called more than once", 2)
	end

	Logger.Debug("ServiceRegistry", "初始化开始")

	-- 必须先注册所有服务，否则在调用 Init 时，服务之间的依赖关系可能无法满足。所以，先注册服务，再调用 Init 方法。
	for _, service in ipairs(self._services) do
		Lifecycle.AssertModule(service, "Service")

		if self._servicesByName[service.Name] ~= nil then
			error("Duplicate service name: " .. service.Name, 2)
		end

		self._servicesByName[service.Name] = service --用 service.Name 作为 key，service 这张服务表作为 value，存进 registry._servicesByName service 就是服务表，ServiceList 里 require 的每个服务模块返回的表。
		Logger.Debug("ServiceRegistry", "注册了 " .. service.Name)
	end

	--第二轮，调用每个服务的 Init 方法，传入 context 上下文表。
	for _, service in ipairs(self._services) do
		if service.Init ~= nil then
			Logger.Debug("ServiceRegistry", "初始化 " .. service.Name)
			service:Init(self._context)
		end
	end

	self._initialized = true
	Logger.Info("ServiceRegistry", "初始化完成: " .. tostring(#self._services) .. " services")
end

function ServiceRegistry:Start()
	if not self._initialized then
		error("ServiceRegistry:Start() was called before Init()", 2)
	end

	if self._started then
		error("ServiceRegistry:Start() was called more than once", 2)
	end

	Logger.Debug("ServiceRegistry", "启动开始")

	for _, service in ipairs(self._services) do
		if service.Start ~= nil then
			Logger.Debug("ServiceRegistry", "启动 " .. service.Name)
			service:Start() --循环调用每个服务的 Start 方法，启动服务。
		end
	end

	self._started = true
	Logger.Info("ServiceRegistry", "启动完成: " .. tostring(#self._services) .. " services")
end

return ServiceRegistry
