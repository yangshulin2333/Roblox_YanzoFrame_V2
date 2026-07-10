--!strict

local Players = game:GetService("Players")

local PersistenceVerificationService = {
	Name = "PersistenceVerificationService",
}

PersistenceVerificationService._logger = nil
PersistenceVerificationService._services = nil
PersistenceVerificationService._testedPlayers = {}

function PersistenceVerificationService:Init(context)
	self._logger = context.Logger
	self._services = context.Services
	self._testedPlayers = {}
end

function PersistenceVerificationService:_verifyPlayer(player)
	local storageService = self._services.StorageService
	if storageService == nil then
		error("StorageService is missing", 2)
	end

	local deadline = os.clock() + 30
	while player.Parent == Players and not storageService:IsPlayerDataReady(player) and os.clock() < deadline do
		task.wait(0.1)
	end

	if player.Parent ~= Players then
		return
	end

	if not storageService:IsPlayerDataReady(player) then
		self._logger.Warn(self.Name, "Persistence check timed out: " .. player.Name)
		return
	end

	local ok, result = pcall(function()
		return storageService:UpdatePlayerModuleData(player, "PersistenceCheck", { Value = 0 }, function(data)
			data.Value = data.Value + 1
			return data
		end)
	end)

	if not ok then
		self._logger.Warn(self.Name, "Persistence check failed: " .. player.Name .. " / " .. tostring(result))
		return
	end

	print("[StorageV11Check] PersistenceCheck = " .. tostring(result.Value))
end

function PersistenceVerificationService:_schedulePlayer(player)
	if self._testedPlayers[player] then
		return
	end

	self._testedPlayers[player] = true
	task.spawn(function()
		self:_verifyPlayer(player)
	end)
end

function PersistenceVerificationService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_schedulePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._testedPlayers[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_schedulePlayer(player)
	end
end

return PersistenceVerificationService
