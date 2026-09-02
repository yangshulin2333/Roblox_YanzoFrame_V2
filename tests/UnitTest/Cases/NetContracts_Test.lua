--!strict

-- 验证 Remote 名称和统一网络结果的最小公开契约。
return function(testContext)
	local NetResult = require(game.ReplicatedStorage.Framework.Shared.Net.NetResult)
	local RemoteGuards = require(game.ReplicatedStorage.Framework.Shared.Net.RemoteGuards)
	local RemoteRateLimiter = require(game.ServerScriptService.Server.Framework.Net.RemoteRateLimiter)
	local NetService = require(game.ServerScriptService.Server.Framework.Services.NetService)
	local expect = testContext.expect

	-- 合法名称保持不变，可安全作为 Remote 实例名。
	testContext.test("accepts a valid remote name", function()
		expect.equal(RemoteGuards.AssertRemoteName("PlayerSettings.GetLanguage"), "PlayerSettings.GetLanguage")
	end)

	-- 空名称、路径字符和超长名称必须在创建 Remote 前失败。
	testContext.test("rejects invalid remote names", function()
		expect.throws(function()
			RemoteGuards.AssertRemoteName("")
		end)
		expect.throws(function()
			RemoteGuards.AssertRemoteName("Player/Settings")
		end)
		expect.throws(function()
			RemoteGuards.AssertRemoteName(string.rep("A", 81))
		end)
	end)

	-- 成功与失败结果都保留统一的 Ok 标记和对应字段。
	testContext.test("builds recognizable network results", function()
		local success = NetResult.Ok({ Value = 1 })
		local failure = NetResult.Err("INVALID_PAYLOAD", "Payload is invalid")

		expect.truthy(success.Ok)
		expect.equal(success.Data.Value, 1)
		expect.falsy(failure.Ok)
		expect.equal(failure.Code, "INVALID_PAYLOAD")
		expect.truthy(NetResult.IsResult(success))
		expect.truthy(NetResult.IsResult(failure))
		expect.falsy(NetResult.IsResult({}))
	end)

	-- NetService 必须在重复请求进入业务 handler 前返回稳定的 RATE_LIMITED。
	testContext.test("returns RATE_LIMITED before a repeated handler runs", function()
		local now = 10
		local limiter = RemoteRateLimiter.new(function()
			return now
		end)
		limiter:SetCooldown("Game.Test", 1)

		local service = setmetatable({
			_requestRateLimiter = limiter,
			_logger = {
				Warn = function() end,
			},
		}, {
			__index = NetService,
		})
		local player = {}
		local handlerCalls = 0
		local function handler()
			handlerCalls += 1
			return { Value = handlerCalls }
		end

		local first = service:_handleRequest("Game.Test", handler, player, {})
		local repeated = service:_handleRequest("Game.Test", handler, player, {})

		expect.truthy(first.Ok)
		expect.falsy(repeated.Ok)
		expect.equal(repeated.Code, "RATE_LIMITED")
		expect.equal(repeated.Data.RemoteName, "Game.Test")
		expect.equal(handlerCalls, 1)
	end)
end
