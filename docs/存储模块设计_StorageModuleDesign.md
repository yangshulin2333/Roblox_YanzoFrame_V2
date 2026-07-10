# StorageModule 设计说明

## 当前定位

YanzoFrame_V1_StorageModule 从 YanzoFrame_V0 复制而来，用于把 Storage 从“基础边界”逐步发展成独立模块。

当前阶段是 `StorageModule V1.1`：保留内存测试后端，并增加 ProfileStore 持久化后端。

## 为什么基础框架要保留 Storage

如果基础框架完全没有 Storage，后续商店、背包、奖励、敌人进度都要各自临时写一套数据读写方法。

这样很容易变乱。

所以基础框架保留最小 Storage：

- 有统一入口。
- 有默认数据。
- 有数据校验。
- 有测试与正式两种后端实现。
- 可以让模块先跑通逻辑。

## V1.1 范围

V1.1 已引入：

- Wally 锁定的 ProfileStore。
- 玩家档案会话锁、自动保存和会话释放。
- 数据未就绪与加载失败处理。

当前仍延后：

- 自制原生 DataStore 适配器。
- 数据迁移
- 批量维护
- 线上数据修复

## 当前保留的接口

MemoryStorage 和 ProfileStoreStorage 共同提供：

| 方法 | 作用 |
|---|---|
| `Open(key)` | 打开一份数据，没有就创建默认数据 |
| `IsOpen(key)` | 判断数据是否已经打开 |
| `Get(key)` | 读取数据副本 |
| `Set(key, data)` | 替换数据 |
| `Update(key, fn)` | 基于旧数据修改 |
| `Close(key)` | 保存并释放当前会话；Memory 后端只释放内存数据 |

StorageService 提供：

| 方法 | 作用 |
|---|---|
| `OpenKey(key)` | 打开通用 key 数据 |
| `IsKeyOpen(key)` | 判断通用 key 是否已经打开 |
| `GetKey(key)` | 读取通用 key 数据 |
| `SetKey(key, data)` | 写入通用 key 数据 |
| `UpdateKey(key, fn)` | 修改通用 key 数据 |
| `CloseKey(key)` | 关闭通用 key 会话 |
| `OpenPlayer(player)` | 打开玩家数据 |
| `GetPlayerData(player)` | 读取玩家数据 |
| `SetPlayerData(player, data)` | 写入玩家数据 |
| `UpdatePlayerData(player, fn)` | 修改玩家数据 |
| `GetPlayerModuleData(player, moduleName)` | 读取某个模块的数据 |
| `UpdatePlayerModuleData(player, moduleName, defaultModuleData, fn)` | 修改某个模块的数据 |
| `IsPlayerDataReady(player)` | 判断玩家档案是否已经打开 |
| `ClosePlayer(player)` | 保存并释放玩家档案会话 |

## 当前默认数据

默认数据只保留框架级字段：

```lua
{
	SchemaVersion = 1,
	Settings = {
		Language = "zh-CN",
	},
	Modules = {},
}
```

其中：

- `SchemaVersion` 标记数据结构版本。
- `Settings.Language` 保存玩家语言偏好，当前只支持 `zh-CN` 和 `en-US`。
- `Modules` 是后续模块数据的扩展容器，当前不预填业务模块数据。

业务模块应通过 `GetPlayerModuleData` / `UpdatePlayerModuleData` 访问自己的 `Modules[moduleName]`，不要直接散写根字段。

不在基础框架里放：

- `Coins`
- `Items`
- `Inventory`
- `Shop`
- `Enemy`
- `Reward`

这些都属于具体模块。

## 后续升级路径

V1.1 完成 Studio 跨重进持久化验收后冻结。未来只有真实 Schema 升级需求出现时才增加迁移，不预先加入批量维护或 JSON / Excel 工具。

## 当前真实消费者

`PlayerSettingsService` 是第一个使用 StorageModule 的服务。

它不直接保存数据，只通过 `StorageService` 读写：

```text
Settings.Language
```

当前支持：

- `zh-CN`
- `en-US`

这条链路用于证明：业务服务应该依赖 StorageModule，而不是直接依赖 `MemoryStorage`、DataStore 或 ProfileStore。

此前的 `StorageModuleDemoController` 仅用于教学验证，已在 `v1-storage-baseline` 收口时移除；正式游戏应由自己的客户端界面调用对应业务服务。
