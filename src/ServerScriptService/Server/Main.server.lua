--!strict
local ServiceRegistry = require(script.Parent.Framework.Runtime.ServiceRegistry)
local FrameworkServiceList = require(script.Parent.Framework.Runtime.ServiceList)
local GameServiceList = require(script.Parent.Game.Runtime.GameServiceList)

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
