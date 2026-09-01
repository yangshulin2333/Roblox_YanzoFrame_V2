--!strict

return function(testContext)
	local ServiceRegistry = require(game.ServerScriptService.Server.Framework.Runtime.ServiceRegistry)
	local ControllerRegistry =
		require(game.StarterPlayer.StarterPlayerScripts.Client.Framework.Runtime.ControllerRegistry)
	local expect = testContext.expect

	testContext.test("starts injected services in explicit order", function()
		local calls = {}
		local first = { Name = "FirstService" }
		local second = { Name = "SecondService" }

		function first:Init(context)
			expect.equal(context.Services.SecondService, second)
			table.insert(calls, "first:init")
		end

		function second:Init()
			table.insert(calls, "second:init")
		end

		function first:Start()
			table.insert(calls, "first:start")
		end

		function second:Start()
			table.insert(calls, "second:start")
		end

		local registry = ServiceRegistry.new({ first, second })
		registry:Init()
		registry:Start()

		expect.equal(table.concat(calls, ","), "first:init,second:init,first:start,second:start")
	end)

	testContext.test("starts injected controllers in explicit order", function()
		local calls = {}
		local first = { Name = "FirstController" }
		local second = { Name = "SecondController" }

		function first:Init(context)
			expect.equal(context.Controllers.SecondController, second)
			table.insert(calls, "first:init")
		end

		function second:Init()
			table.insert(calls, "second:init")
		end

		function first:Start()
			table.insert(calls, "first:start")
		end

		function second:Start()
			table.insert(calls, "second:start")
		end

		local registry = ControllerRegistry.new({ first, second })
		registry:Init()
		registry:Start()

		expect.equal(table.concat(calls, ","), "first:init,second:init,first:start,second:start")
	end)
end
