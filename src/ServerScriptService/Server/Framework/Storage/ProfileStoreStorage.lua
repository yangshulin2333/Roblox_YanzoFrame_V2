--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local TableUtil = require(ReplicatedStorage.Framework.Shared.Util.TableUtil)

local ProfileStoreStorage = {}
ProfileStoreStorage.__index = ProfileStoreStorage

function ProfileStoreStorage.new(storeName, defaultData, validate)
	if type(storeName) ~= "string" or storeName == "" then
		error("storeName must be a non-empty string", 2)
	end

	if type(defaultData) ~= "table" then
		error("defaultData must be a table", 2)
	end

	if validate ~= nil and type(validate) ~= "function" then
		error("validate must be a function", 2)
	end

	local self = setmetatable({}, ProfileStoreStorage)
	self._store = ProfileStore.New(storeName, TableUtil.DeepCopy(defaultData))
	self._validate = validate
	self._profilesByKey = {}
	self._closingByKey = {}
	self._updatingByKey = {}
	return self
end

function ProfileStoreStorage:_assertKey(key)
	if type(key) ~= "string" or key == "" then
		error("key must be a non-empty string", 3)
	end
	return key
end

function ProfileStoreStorage:_validateData(data)
	if self._validate == nil then
		return true
	end

	local ok, message = self._validate(data)
	if not ok then
		return false, tostring(message)
	end
	return true
end

function ProfileStoreStorage:_getProfile(key)
	key = self:_assertKey(key)

	local profile = self._profilesByKey[key]
	if profile == nil or not profile:IsActive() then
		error("storage key is not open: " .. key, 3)
	end
	return profile
end

function ProfileStoreStorage:IsOpen(key)
	key = self:_assertKey(key)
	local profile = self._profilesByKey[key]
	return profile ~= nil and profile:IsActive()
end

function ProfileStoreStorage:Open(key, options)
	key = self:_assertKey(key)
	options = options or {}

	if self:IsOpen(key) then
		return self:Get(key)
	end

	local profile = self._store:StartSessionAsync(key, {
		Cancel = options.Cancel,
	})

	if profile == nil then
		return nil, "PROFILE_LOAD_FAILED"
	end

	local prepareOk, isValid, validationError = pcall(function()
		if options.UserId ~= nil then
			profile:AddUserId(options.UserId)
		end
		profile:Reconcile()
		return self:_validateData(profile.Data)
	end)

	if not prepareOk then
		pcall(profile.EndSession, profile)
		error(isValid, 2)
	end

	if not isValid then
		profile:EndSession()
		return nil, "INVALID_PROFILE_DATA: " .. tostring(validationError)
	end

	self._profilesByKey[key] = profile
	profile.OnSessionEnd:Connect(function()
		local wasClosed = self._closingByKey[key] == true
		self._closingByKey[key] = nil
		self._updatingByKey[key] = nil

		if self._profilesByKey[key] == profile then
			self._profilesByKey[key] = nil
		end

		if type(options.OnSessionEnd) == "function" then
			options.OnSessionEnd(wasClosed)
		end
	end)

	return self:Get(key)
end

function ProfileStoreStorage:Get(key)
	local profile = self:_getProfile(key)
	return TableUtil.DeepCopy(profile.Data)
end

function ProfileStoreStorage:Set(key, data)
	local profile = self:_getProfile(key)
	local copy = TableUtil.DeepCopy(data)
	local isValid, validationError = self:_validateData(copy)

	if not isValid then
		error("invalid storage data: " .. tostring(validationError), 2)
	end

	table.clear(profile.Data)
	for dataKey, value in pairs(copy) do
		profile.Data[dataKey] = value
	end

	return self:Get(key)
end

function ProfileStoreStorage:Update(key, updateFn)
	key = self:_assertKey(key)

	if type(updateFn) ~= "function" then
		error("updateFn must be a function", 2)
	end

	if self._updatingByKey[key] then
		error("storage key is already being updated: " .. key, 2)
	end

	local profile = self:_getProfile(key)
	local updateToken = {}
	self._updatingByKey[key] = updateToken
	local ok, nextData = pcall(updateFn, TableUtil.DeepCopy(profile.Data))
	if self._updatingByKey[key] == updateToken then
		self._updatingByKey[key] = nil
	end

	if not ok then
		error(nextData, 2)
	end

	if nextData == nil then
		error("updateFn must return storage data", 2)
	end

	if self._profilesByKey[key] ~= profile or not profile:IsActive() then
		error("storage session changed during update: " .. key, 2)
	end

	return self:Set(key, nextData)
end

function ProfileStoreStorage:Close(key)
	key = self:_assertKey(key)

	local profile = self._profilesByKey[key]
	if profile == nil then
		return
	end

	self._closingByKey[key] = true
	self._updatingByKey[key] = nil
	self._profilesByKey[key] = nil
	profile:EndSession()
end

return ProfileStoreStorage
