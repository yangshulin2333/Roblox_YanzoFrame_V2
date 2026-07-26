--!strict

local ServerRoot = script.Parent.Parent.Parent
local FrameworkServices = ServerRoot.Framework.Services

return {
	require(FrameworkServices.NetService),
	require(FrameworkServices.ResourceService),
	require(FrameworkServices.StorageService),
	require(FrameworkServices.PlayerSettingsService),
	require(FrameworkServices.DeveloperService),
}
