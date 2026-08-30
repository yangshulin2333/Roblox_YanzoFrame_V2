--!strict

-- 人工入口：默认 Disabled。需要时临时启用并在 Studio 中 Play。
local ServerStorage = game:GetService("ServerStorage")

local totals = require(ServerStorage.UnitTest.RunUnitTest)()
if totals.run == 0 then
	error("Unit test suite did not discover any cases", 0)
end
if totals.failed > 0 then
	error(string.format("Unit test suite failed: %d of %d cases failed", totals.failed, totals.run), 0)
end
