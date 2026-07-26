--!strict

local TableUtil = {}

-- 深拷贝普通 Lua table，避免调用方直接持有存储内部的数据引用。
function TableUtil.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[TableUtil.DeepCopy(key)] = TableUtil.DeepCopy(item)
	end

	return copy
end

return TableUtil
