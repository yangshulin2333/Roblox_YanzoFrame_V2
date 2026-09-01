--!strict

local ControllerRegistry = require(script.Parent.Framework.Runtime.ControllerRegistry)
local FrameworkControllerList = require(script.Parent.Framework.Runtime.ControllerList)
local GameControllerList = require(script.Parent.Game.Runtime.GameControllerList)

local controllers = {}
for _, controller in ipairs(FrameworkControllerList) do
	table.insert(controllers, controller)
end
for _, controller in ipairs(GameControllerList) do
	table.insert(controllers, controller)
end

local registry = ControllerRegistry.new(controllers)
registry:Init()
registry:Start()
