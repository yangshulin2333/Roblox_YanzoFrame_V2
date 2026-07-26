--!strict

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local MemoryStorage = {}
MemoryStorage.__index = MemoryStorage

function MemoryStorage.new(defaultData, validate)
	if type(defaultData) ~= "table" then
		error("defaultData must be a table", 2)
	end

	if validate ~= nil and type(validate) ~= "function" then
		error("validate must be a function", 2)
	end

	local self = setmetatable({}, MemoryStorage)
	self._defaultData = TableUtil.DeepCopy(defaultData)
	self._validate = validate
	self._dataByKey = {}
	self._updatingByKey = {}
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
		error("invalid storage data: " .. tostring(message), 3)
	end
end

function MemoryStorage:_createDefault()
	local data = TableUtil.DeepCopy(self._defaultData)
	self:_validateData(data)
	return data
end

function MemoryStorage:IsOpen(key)
	key = self:_assertKey(key)
	return self._dataByKey[key] ~= nil
end

function MemoryStorage:Open(key, _options)
	key = self:_assertKey(key)

	if not self:IsOpen(key) then
		self._dataByKey[key] = self:_createDefault()
	end

	return self:Get(key)
end

function MemoryStorage:Get(key)
	key = self:_assertKey(key)

	local data = self._dataByKey[key]
	if data == nil then
		error("storage key is not open: " .. key, 2)
	end

	return TableUtil.DeepCopy(data)
end

function MemoryStorage:Set(key, data)
	key = self:_assertKey(key)

	if not self:IsOpen(key) then
		error("storage key is not open: " .. key, 2)
	end

	local copy = TableUtil.DeepCopy(data)
	self:_validateData(copy)
	self._dataByKey[key] = copy
	return self:Get(key)
end

function MemoryStorage:Update(key, updateFn)
	key = self:_assertKey(key)

	if type(updateFn) ~= "function" then
		error("updateFn must be a function", 2)
	end

	if self._updatingByKey[key] then
		error("storage key is already being updated: " .. key, 2)
	end

	self._updatingByKey[key] = true
	local ok, nextData = pcall(updateFn, self:Get(key))
	self._updatingByKey[key] = nil

	if not ok then
		error(nextData, 2)
	end

	if nextData == nil then
		error("updateFn must return storage data", 2)
	end

	return self:Set(key, nextData)
end

function MemoryStorage:Close(key)
	key = self:_assertKey(key)
	self._updatingByKey[key] = nil
	self._dataByKey[key] = nil
end

return MemoryStorage
