--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Framework.Shared.App.Logger)
local Lifecycle = require(ReplicatedStorage.Framework.Shared.App.Lifecycle)

local ServiceRegistry = {}
ServiceRegistry.__index = ServiceRegistry

-- Registry 只接收 Main 组合好的显式列表，不负责扫描目录。
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

	-- 先注册全部服务，再按顺序 Init，保证服务初始化时能查到彼此。
	for _, service in ipairs(self._services) do
		Lifecycle.AssertModule(service, "Service")

		if self._servicesByName[service.Name] ~= nil then
			error("Duplicate service name: " .. service.Name, 2)
		end

		self._servicesByName[service.Name] = service
		Logger.Debug("ServiceRegistry", "注册了 " .. service.Name)
	end

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

	-- Start 保持 Main 传入的显式顺序。
	for _, service in ipairs(self._services) do
		if service.Start ~= nil then
			Logger.Debug("ServiceRegistry", "启动 " .. service.Name)
			service:Start()
		end
	end

	self._started = true
	Logger.Info("ServiceRegistry", "启动完成: " .. tostring(#self._services) .. " services")
end

return ServiceRegistry
