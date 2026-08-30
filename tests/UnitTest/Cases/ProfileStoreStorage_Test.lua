--!strict

-- 验证 ProfileStore 会话打开后的准备阶段失败时不会遗留活动会话。
return function(testContext)
	local ProfileStoreStorage = require(game.ServerScriptService.Server.Framework.Storage.ProfileStoreStorage)
	local expect = testContext.expect

	-- AddUserId/Reconcile/校验发生异常时，适配器必须释放刚打开的会话。
	testContext.test("ends a session when profile preparation crashes", function()
		local storage = ProfileStoreStorage.new("YanzoFrame_UnitTest", {
			SchemaVersion = 1,
		})
		local endSessionCount = 0
		local fakeProfile = {
			Data = {
				SchemaVersion = 1,
			},
		}

		function fakeProfile:AddUserId(_userId)
			error("TEST_PROFILE_PREPARE_FAILED")
		end

		function fakeProfile:EndSession()
			endSessionCount += 1
		end

		storage._store = {
			StartSessionAsync = function(_self, _key, _options)
				return fakeProfile
			end,
		}

		expect.throws(function()
			storage:Open("PlayerA", {
				UserId = 1,
			})
		end)
		expect.equal(endSessionCount, 1)
	end)

	-- Update 回调期间会话被替换时，旧快照不能写入新会话。
	testContext.test("rejects an update after the storage session changes", function()
		local storage = ProfileStoreStorage.new("YanzoFrame_UnitTest", {
			SchemaVersion = 1,
			Value = 0,
		})
		local key = "PlayerA"

		local function makeProfile(value)
			local active = true
			local profile = {
				Data = {
					SchemaVersion = 1,
					Value = value,
				},
			}

			function profile:IsActive()
				return active
			end

			function profile:EndSession()
				active = false
			end

			return profile
		end

		local oldProfile = makeProfile(1)
		local newProfile = makeProfile(2)
		storage._profilesByKey[key] = oldProfile

		local callbackStarted = false
		local releaseCallback = false
		local updateDone = false
		local updateOk = false
		local updateError = nil

		task.spawn(function()
			updateOk, updateError = pcall(function()
				storage:Update(key, function(data)
					callbackStarted = true
					while not releaseCallback do
						task.wait()
					end
					data.Value = 99
					return data
				end)
			end)
			updateDone = true
		end)

		while not callbackStarted do
			task.wait()
		end

		storage:Close(key)
		storage._profilesByKey[key] = newProfile
		releaseCallback = true

		while not updateDone do
			task.wait()
		end

		expect.falsy(updateOk)
		expect.truthy(string.find(tostring(updateError), "storage session changed", 1, true))
		expect.equal(newProfile.Data.Value, 2)
	end)
end
