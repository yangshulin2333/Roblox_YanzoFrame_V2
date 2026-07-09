--!strict

local ClientRoot = script.Parent.Parent.Parent
local FrameworkControllers = ClientRoot.Framework.Controllers

return {
	require(FrameworkControllers.StartupSmokeTestController),
	require(FrameworkControllers.StorageModuleDemoController),
}
