--!strict

-- 验证 MemoryStorage 的公开读写契约，不访问真实 DataStore。
return function(testContext)
	local MemoryStorage = require(game.ReplicatedStorage.Framework.Shared.Storage.MemoryStorage)
	local expect = testContext.expect

	local function makeStorage()
		return MemoryStorage.new({
			Counter = 0,
			Nested = {
				Enabled = true,
			},
		}, function(data)
			if type(data.Counter) ~= "number" then
				return false, "Counter must be a number"
			end
			return true
		end)
	end

	-- Open 和 Get 返回副本，调用方不能绕过 Set/Update 修改内部数据。
	testContext.test("returns independent data copies", function()
		local storage = makeStorage()
		local opened = storage:Open("PlayerA")
		opened.Counter = 99
		opened.Nested.Enabled = false

		local stored = storage:Get("PlayerA")
		expect.equal(stored.Counter, 0)
		expect.truthy(stored.Nested.Enabled)
	end)

	-- Update 只更新指定的已打开 key，并返回更新后的副本。
	testContext.test("updates an opened key", function()
		local storage = makeStorage()
		storage:Open("PlayerA")

		local updated = storage:Update("PlayerA", function(data)
			data.Counter += 1
			return data
		end)

		expect.equal(updated.Counter, 1)
		expect.equal(storage:Get("PlayerA").Counter, 1)
	end)

	-- Get 不会隐式创建数据，关闭或未打开的 key 必须明确失败。
	testContext.test("rejects reads before open", function()
		local storage = makeStorage()
		expect.throws(function()
			storage:Get("Missing")
		end)
	end)
end
