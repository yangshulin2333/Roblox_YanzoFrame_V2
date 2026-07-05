--!strict
--检查 Remote 名字是否合法。
local RemoteGuards = {}

local MAX_REMOTE_NAME_LENGTH = 80 --定义 Remote 名字最大长度是 80。
--匹配 Remote 名字的正则表达式，允许字母、数字、点、下划线、短横线。
local REMOTE_NAME_PATTERN = "^[%w_%.%-]+$"

--[[
	必须是字符串
	不能为空
	不能太长
	只能用字母、数字、点、下划线、短横线
]]
function RemoteGuards.AssertRemoteName(remoteName, argumentName) --argumentName 报错时显示的参数名
	local label = argumentName or "remoteName"

	if type(remoteName) ~= "string" or remoteName == "" then
		error(label .. " 必须是不为空的字符串", 3)
	end

	if #remoteName > MAX_REMOTE_NAME_LENGTH then
		error(label .. " 太长", 3)
	end

	if string.match(remoteName, REMOTE_NAME_PATTERN) == nil then
		error(label .. "只能使用字母、数字、点号、下划线和连字符。", 3)
	end

	return remoteName
end

return RemoteGuards
