# StorageModule 使用规则

## 模块定位

`StorageModule` 是服务端玩家数据管理模块。

它负责：

- 玩家进入时打开数据。
- 玩家在线时读取和更新数据。
- 玩家离开时关闭数据。
- 写入前做基础结构校验。
- 让业务代码可以在 `MemoryStorage` 和 `ProfileStoreStorage` 之间切换而无需重写。

它不负责：

- 商店规则。
- 背包规则。
- 奖励规则。
- 多语言文本。
- Excel 配置导出。
- 排行榜和跨服务器全局状态。

## 当前阶段

当前默认使用 `ProfileStoreStorage`，由 ProfileStore 负责自动保存和会话锁。`MemoryStorage` 保留为不访问线上数据的测试后端。

## 数据生命周期

```text
玩家进入
  -> StorageService:OpenPlayer(player)
  -> 根据 player.UserId 打开数据
  -> ProfileStore 加载档案；没有数据时使用 DefaultData 创建
  -> 打开成功后 IsPlayerDataReady(player) 才为 true
  -> 需要等待的业务服务可调用 WaitForPlayerData(player, timeoutSeconds?)

玩家在线
  -> 其他服务通过 StorageService 读取或更新数据

玩家离开
  -> StorageService:ClosePlayer(player)
  -> ProfileStore 保存并释放会话
```

`OpenPlayer` 只负责准备玩家数据，不负责给奖励、初始化背包、设置语言或读取配置表。

同一玩家的数据正在打开时，后续 `OpenPlayer` 调用会等待当前加载完成并复用结果，不会再创建第二个 ProfileStore 会话，也不会把“正在加载”误判为加载失败。

## 接口使用规则

| 接口 | 当前定位 | 使用建议 |
|---|---|---|
| `OpenPlayer(player)` | 打开玩家数据 | 玩家进入时由 `StorageService` 自动调用 |
| `IsPlayerDataReady(player)` | 判断玩家档案是否已打开 | Remote 和业务操作前用于返回 `DATA_NOT_READY` |
| `WaitForPlayerData(player, timeoutSeconds?)` | 等待指定玩家的数据准备完成 | 只用于确实需要在初始化后继续的服务；返回统一结果码，不要自行重复轮询 |
| `GetPlayerData(player)` | 读取玩家数据副本 | 用于显示、判断、调试 |
| `UpdatePlayerData(player, updateFn)` | 修改玩家数据 | 正常业务修改优先使用 |
| `SetPlayerData(player, data)` | 替换整份玩家数据 | 少用，仅用于初始化、修复、迁移等明确场景 |
| `ResetPlayerData(player)` | 恢复当前默认整档数据 | 仅服务器开发入口调用；成功后应让玩家重新进入以清理业务缓存 |
| `GetPlayerModuleData(player, moduleName)` | 读取某个模块的数据副本 | 业务模块读取自己的命名空间数据 |
| `UpdatePlayerModuleData(player, moduleName, defaultModuleData, updateFn)` | 修改某个模块的数据 | 业务模块写入自己的命名空间数据 |
| `ClosePlayer(player)` | 关闭玩家数据 | 玩家离开时由 `StorageService` 自动调用 |

核心规则：

```text
业务模块只描述“我要怎么改数据”。
StorageModule 负责读取、校验、写回。
```

`UpdatePlayerData` 和 `UpdatePlayerModuleData` 的回调应保持短小、同步，不在里面等待网络或其他长任务。框架会锁住同一 key 的并发更新；如果回调等待期间存档会话已经关闭或被替换，本次更新会明确失败，旧数据不会写进新会话。

### 等待数据就绪的结果码

`WaitForPlayerData(player, timeoutSeconds?)` 不修改数据，只等待本次玩家数据生命周期出现确定结果：

| 返回值 | 含义 | 业务服务应如何处理 |
|---|---|---|
| `true, "READY"` | 数据已打开，可继续读取或写入 | 继续初始化 |
| `false, "PLAYER_LEFT"` | 玩家已经离开 | 停止当前初始化，不再写入 |
| `false, "DATA_LOAD_FAILED"` | 数据加载失败 | 停止初始化；玩家会由 StorageService 断开并提示重进 |
| `false, "DATA_SESSION_ENDED"` | 已打开的数据会话意外结束 | 停止初始化；玩家会由 StorageService 断开并提示重进 |
| `false, "DATA_READY_TIMEOUT"` | 调用方提供的超时时间已到 | 由具体业务决定重试、提示或放弃 |

`timeoutSeconds` 省略时，会持续等待到上述某个确定结果；传入 `0` 时只做一次即时检查。

`IsPlayerDataReady(player)` 仍保留给不应等待的即时操作，例如 Remote 请求直接返回 `DATA_NOT_READY`。不要为了统一而把所有即时操作都改为等待。

后续业务模块不要直接操作 `data.Modules`。优先使用模块命名空间接口：

```lua
StorageService:UpdatePlayerModuleData(player, "Shop", {
	Purchased = {},
}, function(shopData)
	shopData.Purchased["ItemId"] = true
	return shopData
end)
```

这样 Shop、Bag、Reward 等模块只管理自己的数据区域，不把字段散落到玩家数据根表。

## Schema 规则

当前最小数据结构：

```lua
{
	SchemaVersion = 1,
	Settings = {
		Language = "zh-CN",
	},
	Modules = {},
}
```

`SchemaVersion` 是 StorageModule 的基础字段，用于标记数据结构版本。

`Settings.Language` 是当前唯一进入 Schema 的玩家偏好字段，只允许：

- `zh-CN`
- `en-US`

`Modules` 是后续模块的数据扩展容器，当前不预填任何业务模块数据。

当前不要提前加入：

- `Coins`
- `Items`
- `Shop`
- `Inventory`
- `QuestProgress`

这些字段属于具体业务模块，应在真实调用方出现后再讨论是否放入 `Modules`。

## 玩家设置消费者

`PlayerSettingsService` 是当前第一个真实消费者。

它负责读写玩家设置，但不直接管理底层存储：

```text
PlayerSettingsService
  -> StorageService
  -> ProfileStoreStorage
  -> ProfileStore
```

当前只提供语言偏好接口：

| 接口 | 作用 |
|---|---|
| `GetLanguage(player)` | 读取玩家语言 |
| `SetLanguage(player, language)` | 设置玩家语言 |

`SetLanguage` 只接受：

- `zh-CN`
- `en-US`

这说明后续模块应该这样接入 StorageModule：

```text
具体模块负责业务含义。
StorageModule 负责保存和校验玩家数据。
```

## ProfileStore 关系

业务模块不直接依赖 `ProfileStore`。

当前正式关系是：

```text
ShopModule / BagModule / RewardModule
  -> StorageModule
  -> ProfileStoreStorage
  -> ProfileStore
```

测试关系是：

```text
业务模块
  -> StorageModule
  -> MemoryStorage
```

两条链路使用同一组 StorageService 接口，业务模块不需要重写。

## 进入代码修改前的判断标准

开始扩展代码前，需要先能说清楚：

- `OpenPlayer` 为什么用 `UserId` 打开数据。
- `GetPlayerData` 为什么返回副本。
- `UpdatePlayerData` 为什么是业务修改主入口。
- `SetPlayerData` 为什么要少用。
- `ClosePlayer` 为什么是保存和释放会话，而不是删除永久数据。
- `MemoryStorage` 和 `ProfileStore` 为什么只是不同底层实现。
