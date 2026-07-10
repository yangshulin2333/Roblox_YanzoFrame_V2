--!strict

local Lifecycle = {}

--[[
	module  被检查的模块表，比如 NetService / StorageService / 任意 Controller
	owner   模块类型文字，比如 "Service" 或 "Controller"
]]

function Lifecycle.AssertModule(module, owner) --Assert：断言 / 强制检查
	if type(module) ~= "table" then
		error(owner .. " 必须返回一个表", 3)
	end

	--必须有合法的 Name
	if type(module.Name) ~= "string" or module.Name == "" then
		error(owner .. "这个模块没有提供有效的 Name。", 3)
	end

	--Init 可以没有；但如果有，必须是函数
	if module.Init ~= nil and type(module.Init) ~= "function" then
		error(owner .. " module " .. module.Name .. " 有一个不是函数的 Init", 3)
	end
	--Start 可以没有；但如果有，必须是函数
	if module.Start ~= nil and type(module.Start) ~= "function" then
		error(owner .. " module " .. module.Name .. " 有一个不是函数的 Start", 3)
	end
end

return Lifecycle
