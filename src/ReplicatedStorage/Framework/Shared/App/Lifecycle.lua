--!strict

local Lifecycle = {}

--[[
	service 必须是 table
	service.Name 必须存在
	service.Init 如果存在，必须是 function
	service.Start 如果存在，必须是 function
]]

function Lifecycle.AssertModule(module, owner)
	if type(module) ~= "table" then
		error(owner .. " 必须返回一个表", 3)
	end

	if type(module.Name) ~= "string" or module.Name == "" then
		error(owner .. "这个模块没有提供有效的 Name。", 3)
	end

	if module.Init ~= nil and type(module.Init) ~= "function" then
		error(owner .. " module " .. module.Name .. " has a non-function Init", 3)
	end

	if module.Start ~= nil and type(module.Start) ~= "function" then
		error(owner .. " module " .. module.Name .. " has a non-function Start", 3)
	end
end

return Lifecycle
