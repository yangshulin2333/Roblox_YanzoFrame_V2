--!strict

local ServerRoot = script.Parent.Parent.Parent
local FrameworkServices = ServerRoot.Framework.Services

return {
	require(FrameworkServices.NetService),
	require(FrameworkServices.StorageService),
	require(FrameworkServices.StartupSmokeTestService),
	require(FrameworkServices.StorageModuleSmokeTestService),
}
