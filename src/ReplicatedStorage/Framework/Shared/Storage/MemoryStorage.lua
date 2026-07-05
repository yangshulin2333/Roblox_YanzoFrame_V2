--!strict

local MemoryStorage = {}
MemoryStorage.__index = MemoryStorage

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

function MemoryStorage.new(defaultData, validate)
	if type(defaultData) ~= "table" then
		error("defaultData must be a table", 2)
	end

	if validate ~= nil and type(validate) ~= "function" then
		error("validate must be a function", 2)
	end

	local self = setmetatable({}, MemoryStorage)
	self._defaultData = deepCopy(defaultData)
	self._validate = validate
	self._dataByKey = {}
	return self
end

function MemoryStorage:_assertKey(key)
	if type(key) ~= "string" or key == "" then
		error("key must be a non-empty string", 3)
	end
	return key
end

function MemoryStorage:_validateData(data)
	if self._validate == nil then
		return
	end

	local ok, message = self._validate(data)
	if not ok then
		error("Invalid storage data: " .. tostring(message), 3)
	end
end

function MemoryStorage:_createDefault()
	local data = deepCopy(self._defaultData)
	self:_validateData(data)
	return data
end

function MemoryStorage:Open(key)
	key = self:_assertKey(key)

	if self._dataByKey[key] == nil then
		self._dataByKey[key] = self:_createDefault()
	end

	return self:Get(key)
end

function MemoryStorage:Get(key)
	key = self:_assertKey(key)

	if self._dataByKey[key] == nil then
		self._dataByKey[key] = self:_createDefault()
	end

	return deepCopy(self._dataByKey[key])
end

function MemoryStorage:Set(key, data)
	key = self:_assertKey(key)

	local copy = deepCopy(data)
	self:_validateData(copy)
	self._dataByKey[key] = copy

	return self:Get(key)
end

function MemoryStorage:Update(key, updateFn)
	key = self:_assertKey(key)

	if type(updateFn) ~= "function" then
		error("updateFn must be a function", 2)
	end

	local current = self:Get(key)
	local nextData = updateFn(current)

	if nextData == nil then
		nextData = current
	end

	return self:Set(key, nextData)
end

function MemoryStorage:Remove(key)
	key = self:_assertKey(key)
	self._dataByKey[key] = nil
end

return MemoryStorage
