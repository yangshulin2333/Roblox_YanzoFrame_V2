# Storage 基础边界设计

## 当前定位

Demo01 里的 Storage 不是完整 StorageModule。

它只是基础框架的一条最小存储边界，用来让后续模块可以先用内存数据验证逻辑。

## 为什么基础框架要保留 Storage

如果基础框架完全没有 Storage，后续商店、背包、奖励、敌人进度都要各自临时写一套数据读写方法。

这样很容易变乱。

所以基础框架保留最小 Storage：

- 有统一入口。
- 有默认数据。
- 有数据校验。
- 有内存实现。
- 可以让模块先跑通逻辑。

## 为什么现在不做完整版

完整版存储会引入：

- DataStore
- ProfileStore
- 失败重试
- 请求频率限制
- 关服保存
- 数据迁移
- 批量维护
- 线上数据修复

这些以后都重要，但现在会干扰基础框架学习。

## 当前保留的接口

MemoryStorage 提供：

| 方法 | 作用 |
|---|---|
| `Open(key)` | 打开一份数据，没有就创建默认数据 |
| `Get(key)` | 读取数据副本 |
| `Set(key, data)` | 替换数据 |
| `Update(key, fn)` | 基于旧数据修改 |
| `Remove(key)` | 从内存移除数据 |

StorageService 提供：

| 方法 | 作用 |
|---|---|
| `OpenKey(key)` | 打开通用 key 数据 |
| `GetKey(key)` | 读取通用 key 数据 |
| `SetKey(key, data)` | 写入通用 key 数据 |
| `UpdateKey(key, fn)` | 修改通用 key 数据 |
| `RemoveKey(key)` | 移除通用 key 数据 |
| `OpenPlayer(player)` | 打开玩家数据 |
| `GetPlayerData(player)` | 读取玩家数据 |
| `SetPlayerData(player, data)` | 写入玩家数据 |
| `UpdatePlayerData(player, fn)` | 修改玩家数据 |
| `ClosePlayer(player)` | 移除玩家内存数据 |

## 当前默认数据

默认数据只保留框架级字段：

```lua
{
	SchemaVersion = 1,
}
```

不在基础框架里放：

- `Coins`
- `Items`
- `Inventory`
- `Shop`
- `Enemy`
- `Reward`

这些都属于具体模块。

## 后续升级路径

基础框架掌握之后，第一个正式模块可以做完整 StorageModule。

升级顺序建议：

1. 保持 MemoryStorage。
2. 补充更严格的数据 schema。
3. 增加 DataStoreStorage。
4. 再讨论是否使用 ProfileStore。
5. 最后才做迁移、批量维护、JSON / Excel 工具。
