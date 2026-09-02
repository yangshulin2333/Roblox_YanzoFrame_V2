--!strict

-- RemoteRateLimiter 只记录服务器内存中的请求冷却，不负责封禁、持久化或全局限流。
local RemoteRateLimiter = {}
RemoteRateLimiter.__index = RemoteRateLimiter

local function assertCooldownSeconds(cooldownSeconds)
	if
		type(cooldownSeconds) ~= "number"
		or cooldownSeconds ~= cooldownSeconds
		or cooldownSeconds <= 0
		or cooldownSeconds == math.huge
	then
		error("cooldownSeconds must be a finite number greater than 0", 3)
	end

	return cooldownSeconds
end

function RemoteRateLimiter.new(clock)
	if clock ~= nil and type(clock) ~= "function" then
		error("clock must be a function", 2)
	end

	local self = setmetatable({}, RemoteRateLimiter)
	self._clock = clock or os.clock
	self._cooldownSecondsByName = {}
	self._lastRequestAtByPlayer = {}
	return self
end

function RemoteRateLimiter:SetCooldown(remoteName, cooldownSeconds)
	if type(remoteName) ~= "string" or remoteName == "" then
		error("remoteName must be a non-empty string", 2)
	end

	self._cooldownSecondsByName[remoteName] = assertCooldownSeconds(cooldownSeconds)
end

-- 返回是否允许请求，以及被拒绝时还需等待的秒数。
function RemoteRateLimiter:TryAcquire(player, remoteName)
	local cooldownSeconds = self._cooldownSecondsByName[remoteName]
	if cooldownSeconds == nil then
		error("Request cooldown is not registered: " .. tostring(remoteName), 2)
	end

	local now = self._clock()
	local lastRequestAtByName = self._lastRequestAtByPlayer[player]
	if lastRequestAtByName == nil then
		lastRequestAtByName = {}
		self._lastRequestAtByPlayer[player] = lastRequestAtByName
	end

	local lastRequestAt = lastRequestAtByName[remoteName]
	if lastRequestAt ~= nil then
		local retryAfterSeconds = cooldownSeconds - (now - lastRequestAt)
		if retryAfterSeconds > 0 then
			return false, retryAfterSeconds
		end
	end

	lastRequestAtByName[remoteName] = now
	return true, 0
end

function RemoteRateLimiter:ClearPlayer(player)
	self._lastRequestAtByPlayer[player] = nil
end

return RemoteRateLimiter
