# 模块开发规则 Module Rules

## 底层思想

本底座使用三种简单思想：

| 思想 | 用在哪里 | 作用 |
|---|---|---|
| 模块化 | 每个功能一个 ModuleScript | 降低互相影响 |
| 接口适配 | Storage 先定义用法，再换实现 | MemoryStorage 和 ProfileStoreStorage 共用合同 |
| 少量面向对象 | Registry / Storage 用 `new()` | 方便重复创建和测试 |

## Service 是什么

Service 是服务端模块。

通用底座 Service 放在 `Server/Framework/Services` 并登记到 Framework `ServiceList`；具体游戏 Service 放在 `Server/Game` 下并登记到 `GameServiceList`。Framework 列表先启动，Game 列表后启动。

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

## Service 之间怎么互相调用

每个 Service 在 `Init(context)` 里都能拿到 `context.Services`，里面有其他所有 Service 的引用。

规则很简单：

- 只能调用别的 Service 没有下划线前缀的方法，例如 `StorageService:GetPlayerData(player)`。
- 不能直接读写别的 Service 用下划线开头的字段，例如 `otherService._xxx`。
- 想要的东西对方没有对外提供方法，就去给对方加一个方法，不要绕过去直接拿。

这样做是为了：以后 Service 一多，任何一个 Service 想改自己内部的字段名字或者实现方式，都不用担心把别的 Service 一起改坏。

## Controller 是什么

Controller 是客户端模块。

通用 Controller 登记到 Framework `ControllerList`；具体游戏 Controller 放在 `Client/Game` 下并登记到 `GameControllerList`。Framework 列表先启动，Game 列表后启动。

它负责：

- 绑定 UI
- 监听输入
- 请求服务端
- 显示反馈

Controller 不负责保存真实数据。

## Config 是什么

Config 是配置表。

例如金币初始值、物品价格、等级经验，都应该放在配置表里。逻辑代码只读取配置，不把数值写死在函数中。

策划使用的 Excel 固定采用：

1. 第 1 行写每个字段的中文释义。
2. 第 2 行写程序使用的英文键名。
3. 第 3 行起写数据。

中文释义和英文键名必须与 `design/config-schema.json` 一致。策划只编辑 Excel 数据；程序或 Codex 维护 Schema；`Generated` 下的 Luau 不能手改。

## Remote 规则

- Client 可以请求 Server。
- Server 必须校验参数。
- Server 返回统一结果。
- Client 不能决定金币、背包、等级等真实状态。

## Storage 规则

`MemoryStorage` 用于本地逻辑测试；`ProfileStoreStorage` 用于正式玩家档案。

业务模块只调用 `StorageService`。读取和更新前必须保证玩家数据已经打开，玩家离开时必须关闭会话。
