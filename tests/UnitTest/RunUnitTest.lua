--!strict

-- 轻量测试入口：发现并运行 ServerStorage.UnitTest.Cases 下的测试模块。
local ServerStorage = game:GetService("ServerStorage")

local function formatValue(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local expect = {}

function expect.equal(actual, expected)
	if actual ~= expected then
		error(string.format("expected %s, got %s", formatValue(expected), formatValue(actual)), 2)
	end
end

function expect.truthy(value)
	if not value then
		error(string.format("expected truthy, got %s", formatValue(value)), 2)
	end
end

function expect.falsy(value)
	if value then
		error(string.format("expected falsy, got %s", formatValue(value)), 2)
	end
end

function expect.throws(callback)
	local ok, result = pcall(callback)
	if ok then
		error("expected the function to throw, but it returned normally", 2)
	end
	return result
end

local function runOne(callback, timeoutSeconds)
	local done = false
	local ok = false
	local result = nil
	local startedAt = os.clock()

	task.spawn(function()
		ok, result = pcall(callback)
		done = true
	end)

	while not done and os.clock() - startedAt < timeoutSeconds do
		task.wait()
	end

	local elapsed = os.clock() - startedAt
	if not done then
		return "timeout", elapsed, string.format("exceeded %.1fs", timeoutSeconds)
	end
	if not ok then
		return "fail", elapsed, tostring(result)
	end
	return "pass", elapsed, nil
end

return function(filter, timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 5
	local totals = { run = 0, passed = 0, failed = 0 }
	local casesFolder = ServerStorage.UnitTest.Cases

	for _, module in ipairs(casesFolder:GetDescendants()) do
		if module:IsA("ModuleScript") and (filter == nil or string.find(module.Name, filter, 1, true)) then
			local required, caseFunction = pcall(require, module)
			if not required or type(caseFunction) ~= "function" then
				totals.run += 1
				totals.failed += 1
				warn(
					string.format("[FAIL] %s | case did not return a function: %s", module.Name, tostring(caseFunction))
				)
			else
				local testContext = { expect = expect }
				function testContext.test(name, callback)
					totals.run += 1
					local status, elapsed, message = runOne(callback, timeoutSeconds)
					if status == "pass" then
						totals.passed += 1
						print(string.format("[PASS] %s > %s (%.3fs)", module.Name, name, elapsed))
					else
						totals.failed += 1
						warn(
							string.format(
								"[%s] %s > %s (%.3fs) | %s",
								string.upper(status),
								module.Name,
								name,
								elapsed,
								message
							)
						)
					end
				end

				local ran, runError = pcall(caseFunction, testContext)
				if not ran then
					totals.run += 1
					totals.failed += 1
					warn(string.format("[FAIL] %s | error while building cases: %s", module.Name, tostring(runError)))
				end
			end
		end
	end

	print(string.format("[SUMMARY] %d run, %d passed, %d failed", totals.run, totals.passed, totals.failed))
	return totals
end
