--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DeveloperConfig = require(ReplicatedStorage.Module.Shared.Config.DeveloperConfig)
local RemoteNames = require(ReplicatedStorage.Framework.Shared.Net.RemoteNames)

local DeveloperPanelController = {
	Name = "DeveloperPanelController",
}

DeveloperPanelController._logger = nil
DeveloperPanelController._net = nil
DeveloperPanelController._screenGui = nil
DeveloperPanelController._panel = nil
DeveloperPanelController._confirmFrame = nil
DeveloperPanelController._resetButton = nil
DeveloperPanelController._confirmButton = nil
DeveloperPanelController._cancelButton = nil
DeveloperPanelController._collapseButton = nil
DeveloperPanelController._toggleButton = nil
DeveloperPanelController._feedbackLabel = nil

local UI_WAIT_TIMEOUT_SECONDS = 10

-- 取得指定名称和类型的 UI 子对象，缺失时直接给出明确的草稿配置错误。
local function getRequiredUiChild(parent, childName, className)
	local child = parent:WaitForChild(childName, UI_WAIT_TIMEOUT_SECONDS)
	if child == nil or not child:IsA(className) then
		error("DeveloperPanel 缺少 " .. className .. ": " .. childName, 3)
	end

	return child
end

-- 从客户端可读资源目录取得唯一模板并克隆到当前 PlayerGui；已有运行时副本时复用。
local function mountDeveloperPanel(playerGui)
	local existing = playerGui:FindFirstChild("DeveloperPanel")
	if existing ~= nil then
		if not existing:IsA("ScreenGui") then
			error("PlayerGui.DeveloperPanel 必须是 ScreenGui", 3)
		end

		return existing
	end

	local resources = ReplicatedStorage:WaitForChild("Resources", UI_WAIT_TIMEOUT_SECONDS)
	if resources == nil or not resources:IsA("Folder") then
		error("ReplicatedStorage.Resources 未就绪", 3)
	end

	local uiFolder = resources:WaitForChild("UI", UI_WAIT_TIMEOUT_SECONDS)
	if uiFolder == nil or not uiFolder:IsA("Folder") then
		error("ReplicatedStorage.Resources.UI 未就绪", 3)
	end

	local template = uiFolder:WaitForChild("DeveloperPanel", UI_WAIT_TIMEOUT_SECONDS)
	if template == nil or not template:IsA("ScreenGui") then
		error("Resources.UI.DeveloperPanel 必须是 ScreenGui", 3)
	end

	local screenGui = template:Clone()
	screenGui.Parent = playerGui
	return screenGui
end

-- 判断当前客户端是否应显示仅供开发期使用的面板。
local function shouldShowDeveloperPanel()
	return RunService:IsStudio()
		and DeveloperConfig.EnableDataReset == true
		and DeveloperConfig.AllowDataResetInStudio == true
end

-- 初始化客户端依赖，客户端只保存网络请求和表现层引用。
function DeveloperPanelController:Init(context)
	self._logger = context.Logger
	self._net = context.Net
end

-- 更新面板反馈文字和颜色，不在客户端修改任何权威数据。
function DeveloperPanelController:_setFeedback(message, color)
	self._feedbackLabel.Text = message
	self._feedbackLabel.TextColor3 = color
end

-- 打开二次确认区域，避免一次误触直接初始化存档。
function DeveloperPanelController:_showConfirmation()
	self._confirmFrame.Visible = true
	self:_setFeedback("确认后将初始化你的全部持久化数据。", Color3.fromRGB(251, 191, 36))
end

-- 关闭二次确认区域，并恢复普通提示文字。
function DeveloperPanelController:_hideConfirmation()
	self._confirmFrame.Visible = false
	self:_setFeedback("仅 Studio 开发期可用。", Color3.fromRGB(148, 163, 184))
end

-- 折叠完整面板，只在右侧保留可再次点击打开的开发图标。
function DeveloperPanelController:_collapsePanel()
	self._confirmFrame.Visible = false
	self._panel.Visible = false
	self._toggleButton.Visible = true
end

-- 恢复完整面板，并隐藏用于展开的侧边开发图标。
function DeveloperPanelController:_expandPanel()
	self._panel.Visible = true
	self._toggleButton.Visible = false
	self:_hideConfirmation()
end

-- 请求服务器初始化当前玩家数据；服务器负责权限、存档写入和重新进入。
function DeveloperPanelController:_requestReset()
	self._confirmButton.Active = false
	self._confirmButton.AutoButtonColor = false
	self:_setFeedback("正在初始化数据，请稍候……", Color3.fromRGB(251, 191, 36))

	local result = self._net.Request(RemoteNames.DeveloperResetMyData, {})
	if result.Ok == true then
		self:_setFeedback("数据已初始化，正在重新进入……", Color3.fromRGB(74, 222, 128))
		return
	end

	self._confirmButton.Active = true
	self._confirmButton.AutoButtonColor = true
	self:_setFeedback("初始化失败: " .. tostring(result.Code), Color3.fromRGB(248, 113, 113))
	self._logger.Warn(self.Name, "初始化当前玩家数据被拒绝: " .. tostring(result.Code))
end

-- 绑定按钮事件，并在非 Studio 环境中隐藏整个开发面板。
function DeveloperPanelController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = mountDeveloperPanel(playerGui)
	local panel = getRequiredUiChild(screenGui, "Panel", "Frame")

	self._screenGui = screenGui
	self._panel = panel
	self._confirmFrame = getRequiredUiChild(panel, "ConfirmFrame", "Frame")
	self._resetButton = getRequiredUiChild(panel, "ResetButton", "TextButton")
	self._confirmButton = getRequiredUiChild(self._confirmFrame, "ConfirmButton", "TextButton")
	self._cancelButton = getRequiredUiChild(self._confirmFrame, "CancelButton", "TextButton")
	self._collapseButton = getRequiredUiChild(panel, "CollapseButton", "TextButton")
	self._toggleButton = getRequiredUiChild(screenGui, "ToggleButton", "TextButton")
	self._feedbackLabel = getRequiredUiChild(panel, "FeedbackLabel", "TextLabel")

	self._screenGui.Enabled = shouldShowDeveloperPanel()
	if not self._screenGui.Enabled then
		return
	end

	self:_expandPanel()
	self._resetButton.Activated:Connect(function()
		self:_showConfirmation()
	end)
	self._cancelButton.Activated:Connect(function()
		self:_hideConfirmation()
	end)
	self._confirmButton.Activated:Connect(function()
		self:_requestReset()
	end)
	self._collapseButton.Activated:Connect(function()
		self:_collapsePanel()
	end)
	self._toggleButton.Activated:Connect(function()
		self:_expandPanel()
	end)

	self._logger.Info(self.Name, "Studio 开发者面板已启用")
end

return DeveloperPanelController
