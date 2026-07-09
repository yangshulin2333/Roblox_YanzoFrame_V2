--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Framework.Shared.Net.RemoteNames)

local StorageModuleDemoController = {
	Name = "StorageModuleDemoController",
}

StorageModuleDemoController._logger = nil
StorageModuleDemoController._net = nil
StorageModuleDemoController._label = nil

local TEXT_BY_LANGUAGE = {
	["zh-CN"] = {
		Title = "StorageModule 最小示例",
		Body = "当前语言：中文\n点击 English 会通过服务端保存语言偏好。",
	},
	["en-US"] = {
		Title = "StorageModule Demo",
		Body = "Current language: English\nClick 中文 to save the language on the server.",
	},
}

local function createButton(parent, text, position, onClick)
	local button = Instance.new("TextButton")
	button.Name = text .. "Button"
	button.Size = UDim2.fromOffset(120, 34)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(45, 68, 100)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 16
	button.Parent = parent
	button.MouseButton1Click:Connect(onClick)
	return button
end

function StorageModuleDemoController:Init(context)
	self._logger = context.Logger
	self._net = context.Net
end

function StorageModuleDemoController:_setStatus(text)
	if self._label ~= nil then
		self._label.Text = text
	end
end

function StorageModuleDemoController:_render(language)
	local text = TEXT_BY_LANGUAGE[language] or TEXT_BY_LANGUAGE["zh-CN"]
	self:_setStatus(text.Title .. "\n\n" .. text.Body)
end

function StorageModuleDemoController:_requestLanguage()
	local result = self._net.Request(RemoteNames.PlayerSettingsGetLanguage, {})
	if not result.Ok then
		self:_setStatus("StorageModule Demo\n\n读取语言失败: " .. tostring(result.Code))
		return
	end

	self:_render(result.Data.Language)
end

function StorageModuleDemoController:_setLanguage(language)
	self:_setStatus("StorageModule Demo\n\n正在保存语言: " .. language)

	local result = self._net.Request(RemoteNames.PlayerSettingsSetLanguage, {
		Language = language,
	})

	if not result.Ok then
		self:_setStatus("StorageModule Demo\n\n保存语言失败: " .. tostring(result.Code))
		return
	end

	self:_render(result.Data.Language)
end

function StorageModuleDemoController:_createGui()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("StorageModuleDemoGui")
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StorageModuleDemoGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(360, 190)
	panel.Position = UDim2.fromOffset(24, 96)
	panel.BackgroundColor3 = Color3.fromRGB(23, 29, 38)
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Size = UDim2.new(1, -24, 1, -74)
	label.Position = UDim2.fromOffset(12, 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = "StorageModule Demo\n\n正在读取语言..."
	label.TextColor3 = Color3.fromRGB(235, 241, 250)
	label.TextSize = 16
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = panel
	self._label = label

	createButton(panel, "中文", UDim2.fromOffset(12, 142), function()
		self:_setLanguage("zh-CN")
	end)

	createButton(panel, "English", UDim2.fromOffset(146, 142), function()
		self:_setLanguage("en-US")
	end)
end

function StorageModuleDemoController:Start()
	self:_createGui()
	task.defer(function()
		self:_requestLanguage()
	end)
end

return StorageModuleDemoController
