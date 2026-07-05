--!strict

local ControllerRegistry = require(script.Parent.Framework.Runtime.ControllerRegistry)

--[[
    本质是：
    ControllerRegistry.new() 创建一张 self 实例表。
    return self 后，registry 指向这张表。

    所以：
    registry 和 new() 里的 self 指向同一张表。
    也就是：
    registry ---> ControllerRegistry 实例表
]]
local registry = ControllerRegistry.new()
registry:Init()
registry:Start()

--[[
    registry 是 ControllerRegistry 实例表。
    StartupSmokeTestController 是一个 controller 表。
    registry._context 是 registry 这张表里的一个字段。
    StartupSmokeTestController 没有 _context。
]]
