--!strict
local ServiceRegistry = require(script.Parent.Framework.Runtime.ServiceRegistry)
local FrameworkServiceList = require(script.Parent.Framework.Runtime.ServiceList)
local GameServiceList = require(script.Parent.Game.Runtime.GameServiceList)

-- Framework 先加入，Game 后加入；这里的顺序就是后续 Init 和 Start 的顺序。
local services = {}
for _, service in ipairs(FrameworkServiceList) do
	table.insert(services, service)
end
for _, service in ipairs(GameServiceList) do
	table.insert(services, service)
end

local registry = ServiceRegistry.new(services)

registry:Init()
registry:Start()
