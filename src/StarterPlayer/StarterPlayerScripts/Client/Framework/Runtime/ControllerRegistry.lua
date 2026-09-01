--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Framework.Shared.App.Logger)
local Lifecycle = require(ReplicatedStorage.Framework.Shared.App.Lifecycle)
local NetClient = require(ReplicatedStorage.Framework.Shared.Net.NetClient)

local ControllerRegistry = {}
ControllerRegistry.__index = ControllerRegistry

--创建一张self实例表并返回这张表
function ControllerRegistry.new(controllers)
	if type(controllers) ~= "table" then
		error("controllers must be a table", 2)
	end

	local self = setmetatable({}, ControllerRegistry)
	self._controllers = controllers
	self._controllersByName = {}
	self._initialized = false
	self._started = false
	self._context = {
		Logger = Logger,
		Net = NetClient,
		Controllers = self._controllersByName,
	}
	return self
end

function ControllerRegistry:GetController(name)
	return self._controllersByName[name]
end

function ControllerRegistry:Init()
	if self._initialized then
		error("ControllerRegistry:Init() 已经被调用过了", 2)
	end

	Logger.Debug("ControllerRegistry", "初始化开始")

	--按顺序遍历ControllerList 数组表，存入 _controllersByName 字典表，键是控制器的 Name，值是控制器本身
	for _, controller in ipairs(self._controllers) do
		Lifecycle.AssertModule(controller, "Controller")

		if self._controllersByName[controller.Name] ~= nil then
			error("Duplicate controller name: " .. controller.Name, 2)
		end

		self._controllersByName[controller.Name] = controller
		Logger.Debug("ControllerRegistry", "已注册控制器: " .. controller.Name)
	end

	--按顺序继续遍历数据表，调用每个控制器的 Init 方法，传入上下文
	--self._context 是写在 ControllerRegistry:Init() 里，即self = registry。
	for _, controller in ipairs(self._controllers) do
		if controller.Init ~= nil then
			Logger.Debug("ControllerRegistry", "正在初始化: " .. controller.Name)
			controller:Init(self._context) --调用各个控制器的Init方法，传入上下文
		end
	end

	self._initialized = true
	Logger.Info("ControllerRegistry", "初始化完成: " .. tostring(#self._controllers) .. " controllers")
end

function ControllerRegistry:Start()
	if not self._initialized then
		error("ControllerRegistry:Start() was called before Init()", 2)
	end

	if self._started then
		error("ControllerRegistry:Start() was called more than once", 2)
	end

	Logger.Debug("ControllerRegistry", "Start begin")

	for _, controller in ipairs(self._controllers) do
		if controller.Start ~= nil then
			Logger.Debug("ControllerRegistry", "Start " .. controller.Name)
			controller:Start()
		end
	end

	self._started = true
	Logger.Info("ControllerRegistry", "Start complete: " .. tostring(#self._controllers) .. " controllers")
end

return ControllerRegistry
