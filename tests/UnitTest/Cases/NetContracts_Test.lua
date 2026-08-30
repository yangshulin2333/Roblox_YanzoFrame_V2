--!strict

-- 验证 Remote 名称和统一网络结果的最小公开契约。
return function(testContext)
	local NetResult = require(game.ReplicatedStorage.Framework.Shared.Net.NetResult)
	local RemoteGuards = require(game.ReplicatedStorage.Framework.Shared.Net.RemoteGuards)
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
end
