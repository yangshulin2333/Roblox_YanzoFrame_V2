--!strict

-- 验证请求冷却按玩家、按 Remote 隔离，并能在玩家离开时清理。
return function(testContext)
	local RemoteRateLimiter = require(game.ServerScriptService.Server.Framework.Net.RemoteRateLimiter)
	local expect = testContext.expect

	local function newLimiter(nowRef)
		return RemoteRateLimiter.new(function()
			return nowRef.Value
		end)
	end

	-- 连续请求会被拒绝，冷却结束后恢复。
	testContext.test("limits repeated requests and recovers after cooldown", function()
		local nowRef = { Value = 10 }
		local limiter = newLimiter(nowRef)
		local player = {}
		limiter:SetCooldown("Game.Test", 1)

		local firstAllowed = limiter:TryAcquire(player, "Game.Test")
		local secondAllowed, retryAfterSeconds = limiter:TryAcquire(player, "Game.Test")

		expect.truthy(firstAllowed)
		expect.falsy(secondAllowed)
		expect.equal(retryAfterSeconds, 1)

		nowRef.Value = 11
		local recovered = limiter:TryAcquire(player, "Game.Test")
		expect.truthy(recovered)
	end)

	-- 不同玩家和不同 Remote 各自拥有独立冷却。
	testContext.test("separates players and remote names", function()
		local nowRef = { Value = 20 }
		local limiter = newLimiter(nowRef)
		local firstPlayer = {}
		local secondPlayer = {}
		limiter:SetCooldown("Game.First", 1)
		limiter:SetCooldown("Game.Second", 1)

		expect.truthy(limiter:TryAcquire(firstPlayer, "Game.First"))
		expect.falsy(limiter:TryAcquire(firstPlayer, "Game.First"))
		expect.truthy(limiter:TryAcquire(firstPlayer, "Game.Second"))
		expect.truthy(limiter:TryAcquire(secondPlayer, "Game.First"))
	end)

	-- 玩家离开后的清理允许同一对象重新建立冷却状态。
	testContext.test("clears a leaving player's cooldown state", function()
		local nowRef = { Value = 30 }
		local limiter = newLimiter(nowRef)
		local player = {}
		limiter:SetCooldown("Game.Test", 1)

		expect.truthy(limiter:TryAcquire(player, "Game.Test"))
		expect.falsy(limiter:TryAcquire(player, "Game.Test"))

		limiter:ClearPlayer(player)

		expect.truthy(limiter:TryAcquire(player, "Game.Test"))
	end)

	-- 非法冷却值和未注册 Remote 必须明确失败，不能悄悄绕过保护。
	testContext.test("rejects invalid or missing cooldown configuration", function()
		local nowRef = { Value = 40 }
		local limiter = newLimiter(nowRef)

		expect.throws(function()
			limiter:SetCooldown("Game.Test", 0)
		end)
		expect.throws(function()
			limiter:SetCooldown("Game.Test", math.huge)
		end)
		expect.throws(function()
			limiter:TryAcquire({}, "Game.Missing")
		end)
	end)
end
