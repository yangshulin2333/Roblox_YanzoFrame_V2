--!strict

local ServerStorage = game:GetService("ServerStorage")

local ResourceService = {
	Name = "ResourceService",
}

ResourceService._logger = nil
ResourceService._resources = nil

-- 校验服务器资源路径键，例如 "Accessories/StarterHat"，并拆分为逐层查找的目录名。
local function splitResourceKey(resourceKey)
	if type(resourceKey) ~= "string" or resourceKey == "" then
		return nil, "INVALID_RESOURCE_KEY"
	end

	local segments = string.split(resourceKey, "/")
	for _, segment in ipairs(segments) do
		if segment == "" or segment == "." or segment == ".." then
			return nil, "INVALID_RESOURCE_KEY"
		end
	end

	return segments, nil
end

-- 在服务完成初始化后，返回 Rojo 映射得到的 ServerStorage.Resources 根目录。
function ResourceService:_getResourcesFolder()
	if self._resources == nil then
		error("ResourceService 尚未初始化", 2)
	end

	return self._resources
end

-- 初始化服务器专用资源根目录；缺失映射时立即报错，避免错误地从场景或客户端目录取模板。
function ResourceService:Init(context)
	self._logger = context.Logger

	local resources = ServerStorage:FindFirstChild("Resources")
	if resources == nil or not resources:IsA("Folder") then
		error("未找到 ServerStorage.Resources，请检查 default.project.json 的资源映射。", 2)
	end

	self._resources = resources
	self._logger.Info(self.Name, "服务器资源根目录已就绪")
end

-- 按资源路径键查找服务器专用模板；此函数只读取模板，不创建运行时副本。
function ResourceService:FindServerTemplate(resourceKey)
	local segments, keyError = splitResourceKey(resourceKey)
	if segments == nil then
		return nil, keyError
	end

	local current = self:_getResourcesFolder()
	for _, segment in ipairs(segments) do
		local nextInstance = current:FindFirstChild(segment)
		if nextInstance == nil then
			self._logger.Warn(self.Name, "未找到服务器资源模板: " .. resourceKey)
			return nil, "RESOURCE_NOT_FOUND"
		end
		current = nextInstance
	end

	return current, nil
end

-- 将服务器专用模板克隆到调用方明确指定的服务器控制父级。
function ResourceService:CloneServerTemplate(resourceKey, parent)
	if typeof(parent) ~= "Instance" then
		return nil, "INVALID_PARENT"
	end

	local template, findError = self:FindServerTemplate(resourceKey)
	if template == nil then
		return nil, findError
	end

	local clone = template:Clone()
	clone.Parent = parent
	return clone, nil
end

return ResourceService
