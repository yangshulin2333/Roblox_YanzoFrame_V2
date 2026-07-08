--!strict
--内存存储器
local MemoryStorage = {}
MemoryStorage.__index = MemoryStorage

--深拷贝函数，递归复制表
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[deepCopy(key)] = deepCopy(item)
	end
	return copy
end

--new() 是造对象的工厂，不是某个已有对象的行为。
function MemoryStorage.new(defaultData, validate)
	if type(defaultData) ~= "table" then
		error("defaultData必须是table类型", 2)
	end

	if validate ~= nil and type(validate) ~= "function" then
		error("validate必须是function类型", 2)
	end

	local self = setmetatable({}, MemoryStorage)

	self._defaultData = deepCopy(defaultData) --保存一份默认数据的副本，避免外部修改
	self._validate = validate --函数在 Lua 里也是值。保存引用
	self._dataByKey = {} -- 真正保存数据的地方
	return self
end

--辅助函数，检查 key 是否是非空字符串
function MemoryStorage:_assertKey(key)
	if type(key) ~= "string" or key == "" then
		error("key必须是非空字符串", 3)
	end
	return key
end

--辅助函数，验证数据是否合法
function MemoryStorage:_validateData(data)
	if self._validate == nil then --没有提供验证函数，就不验证
		return
	end

	local ok, message = self._validate(data)
	if not ok then
		error("无效的存储数据: " .. tostring(message), 3)
	end
end

--辅助函数，创建默认数据的副本
function MemoryStorage:_createDefault()
	local data = deepCopy(self._defaultData)
	self:_validateData(data)
	return data
end

---- 当前 YanzoFrame_V0 中 Open 和 Get 都会在 key 不存在时创建默认数据；Open 暂作为未来扩展入口，完整 StorageModule 阶段再决定是否保留或拆分职责。
--如果数据不存在，则创建默认数据的副本，并返回它。
function MemoryStorage:Open(key)
	key = self:_assertKey(key) --检查 key 是否是非空字符串

	if self._dataByKey[key] == nil then
		self._dataByKey[key] = self:_createDefault() --当字段值是 table 时，字段里保存的是对那张表的引用。
	end

	return self:Get(key)
end
--玩家数据用 UserId 当 key，非玩家数据可以用自定义字符串 key。
--当前基础框架为了学习和简单，把 Get 也做成“没有就创建”。
function MemoryStorage:Get(key)
	key = self:_assertKey(key)

	if self._dataByKey[key] == nil then
		self._dataByKey[key] = self:_createDefault()
	end

	--把内部真实数据复制一份给调用者,避免调用者直接修改内部数据，破坏存储器的封装性。
	return deepCopy(self._dataByKey[key])
end

--[[
	MemoryStorage._dataByKey["A"] = {
		SchemaVersion = 1,
	}
]]
function MemoryStorage:Set(key, data)
	key = self:_assertKey(key)

	local copy = deepCopy(data) --copy 这个变量，指向 deepCopy(data) 新复制出来的表。
	self:_validateData(copy) --验证数据是否合法
	self._dataByKey[key] = copy --让 _dataByKey["A"] 这个位置，改为指向 Copy。

	return self:Get(key)
end

function MemoryStorage:Update(key, updateFn)
	key = self:_assertKey(key)

	if type(updateFn) ~= "function" then --updateFn 是一个函数。
		error("updateFn必须是function类型", 2)
	end

	local current = self:Get(key) --Get 返回副本，current 不是内部真实表。
	--[[
		function(data)
		data.Coins = data.Coins + 10
		return data
		end
		那 nextData 就是修改后的数据表。
	]]
	local nextData = updateFn(current) --把 current 交给外部函数处理。

	if nextData == nil then
		nextData = current --nextData 最后会指向 current 这张表。
	end

	return self:Set(key, nextData)
end

function MemoryStorage:Remove(key)
	key = self:_assertKey(key)
	self._dataByKey[key] = nil
end

return MemoryStorage
