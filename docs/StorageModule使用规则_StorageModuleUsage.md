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
| `GetPlayerModuleData(player, moduleName)` | 读取某个模块的数据副本 | 业务模块读取自己的命名空间数据 |
| `UpdatePlayerModuleData(player, moduleName, defaultModuleData, updateFn)` | 修改某个模块的数据 | 业务模块写入自己的命名空间数据 |
| `ClosePlayer(player)` | 关闭玩家数据 | 玩家离开时由 `StorageService` 自动调用 |

核心规则：

```text
业务模块只描述“我要怎么改数据”。
StorageModule 负责读取、校验、写回。
```

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
  -> MemoryStorage
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

## 进入代码修改前的判断标准

开始扩展代码前，需要先能说清楚：

- `OpenPlayer` 为什么用 `UserId` 打开数据。
- `GetPlayerData` 为什么返回副本。
- `UpdatePlayerData` 为什么是业务修改主入口。
- `SetPlayerData` 为什么要少用。
- `ClosePlayer` 未来为什么对应保存和释放。
- `MemoryStorage` 和 `ProfileStore` 为什么只是不同底层实现。
