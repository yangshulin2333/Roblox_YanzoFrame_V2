# StorageModule 使用规则

## 模块定位

`StorageModule` 是服务端玩家数据管理模块。

它负责：

- 玩家进入时打开数据。
- 玩家在线时读取和更新数据。
- 玩家离开时关闭数据。
- 写入前做基础结构校验。
- 让底层存储以后可以从 `MemoryStorage` 替换为 `ProfileStoreStorage`。

它不负责：

- 商店规则。
- 背包规则。
- 奖励规则。
- 多语言文本。
- Excel 配置导出。
- 真实 DataStore / ProfileStore 接入。

## 当前阶段

当前阶段只使用 `MemoryStorage`。

这表示玩家数据只存在于当前服务器内存中，不会永久保存。当前目标是先学清楚数据生命周期和接口规则，不处理真实线上存档。

## 数据生命周期

```text
玩家进入
  -> StorageService:OpenPlayer(player)
  -> 根据 player.UserId 打开数据
  -> 没有数据时使用 DefaultData 创建

玩家在线
  -> 其他服务通过 StorageService 读取或更新数据

玩家离开
  -> StorageService:ClosePlayer(player)
  -> 当前阶段移除内存数据
  -> 未来阶段保存并释放真实存档
```

`OpenPlayer` 只负责准备玩家数据，不负责给奖励、初始化背包、设置语言或读取配置表。

## 接口使用规则

| 接口 | 当前定位 | 使用建议 |
|---|---|---|
| `OpenPlayer(player)` | 打开玩家数据 | 玩家进入时由 `StorageService` 自动调用 |
| `GetPlayerData(player)` | 读取玩家数据副本 | 用于显示、判断、调试 |
| `UpdatePlayerData(player, updateFn)` | 修改玩家数据 | 正常业务修改优先使用 |
| `SetPlayerData(player, data)` | 替换整份玩家数据 | 少用，仅用于初始化、修复、迁移等明确场景 |
| `ClosePlayer(player)` | 关闭玩家数据 | 玩家离开时由 `StorageService` 自动调用 |

核心规则：

```text
业务模块只描述“我要怎么改数据”。
StorageModule 负责读取、校验、写回。
```

## Schema 规则

当前最小数据结构：

```lua
{
	SchemaVersion = 1,
}
```

`SchemaVersion` 是 StorageModule 的基础字段，用于标记数据结构版本。

当前不要提前加入：

- `Coins`
- `Items`
- `Language`
- `Shop`
- `Inventory`
- `QuestProgress`

这些字段属于具体业务模块，应在真实调用方出现后再讨论是否加入 Schema。

## ProfileStore 关系

业务模块不直接依赖 `ProfileStore`。

未来关系应保持为：

```text
ShopModule / BagModule / RewardModule
  -> StorageModule
  -> ProfileStoreStorage
  -> ProfileStore
```

当前关系是：

```text
业务模块
  -> StorageModule
  -> MemoryStorage
```

这样未来替换底层存储时，业务模块不需要重写。

## 当前冒烟验证

`StorageModuleSmokeTestService` 只验证 StorageModule 的接口规则：

- `OpenKey` 能打开默认数据。
- `UpdateKey` 能写入测试字段。
- `GetKey` 返回副本，外部修改不会污染内部数据。
- `RemoveKey` 能清理测试数据。

测试使用临时 key，不会把测试字段加入正式 Schema。

## 进入代码修改前的判断标准

开始扩展代码前，需要先能说清楚：

- `OpenPlayer` 为什么用 `UserId` 打开数据。
- `GetPlayerData` 为什么返回副本。
- `UpdatePlayerData` 为什么是业务修改主入口。
- `SetPlayerData` 为什么要少用。
- `ClosePlayer` 未来为什么对应保存和释放。
- `MemoryStorage` 和 `ProfileStore` 为什么只是不同底层实现。
