--!strict
local ServiceRegistry = require(script.Parent.Framework.Runtime.ServiceRegistry)

local registry = ServiceRegistry.new()

registry:Init()
registry:Start()
