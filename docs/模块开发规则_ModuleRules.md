# 模块开发规则 Module Rules

## 底层思想

本底座使用三种简单思想：

| 思想 | 用在哪里 | 作用 |
|---|---|---|
| 模块化 | 每个功能一个 ModuleScript | 降低互相影响 |
| 接口适配 | Storage 先定义用法，再换实现 | 以后可以从 MemoryStorage 换到 DataStore |
| 少量面向对象 | Registry / Storage 用 `new()` | 方便重复创建和测试 |

## Service 是什么

Service 是服务端模块。

它负责：

- 修改真实数据
- 校验客户端请求
- 管理玩家状态
- 调用存储
- 创建和处理 Remote

Service 标准格式：

```lua
local MyService = {
	Name = "MyService",
}

function MyService:Init(context)
end

function MyService:Start()
end

return MyService
```

## Controller 是什么

Controller 是客户端模块。

它负责：

- 绑定 UI
- 监听输入
- 请求服务端
- 显示反馈

Controller 不负责保存真实数据。

## Config 是什么

Config 是配置表。

例如金币初始值、物品价格、等级经验，都应该放在配置表里。逻辑代码只读取配置，不把数值写死在函数中。

## Remote 规则

- Client 可以请求 Server。
- Server 必须校验参数。
- Server 返回统一结果。
- Client 不能决定金币、背包、等级等真实状态。

## Storage 规则

第一阶段只使用 MemoryStorage。

原因：

- 容易理解。
- 容易调试。
- 不会产生真实线上数据风险。

等 StorageModule 学清楚后，再加 DataStore 或 ProfileStore 适配器。
