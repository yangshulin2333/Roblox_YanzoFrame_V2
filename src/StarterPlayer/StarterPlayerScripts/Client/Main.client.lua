--!strict

local ControllerRegistry = require(script.Parent.Framework.Runtime.ControllerRegistry)
local FrameworkControllerList = require(script.Parent.Framework.Runtime.ControllerList)
local GameControllerList = require(script.Parent.Game.Runtime.GameControllerList)

-- Framework 先加入，Game 后加入；这里的顺序就是后续 Init 和 Start 的顺序。
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
