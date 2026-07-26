# Shared Util 使用规则

## 模块定位

`ReplicatedStorage.Framework.Shared.Util` 放置可以被服务器和客户端复用的无状态工具函数。

它不是 Service：不参与 `ServiceRegistry`，不持有玩家、存档、Remote 或场景状态，也不负责初始化生命周期。

## 当前内容

| 模块 | 接口 | 用途 |
|---|---|---|
| `TableUtil` | `TableUtil.DeepCopy(value)` | 为普通 Lua table 创建独立副本，避免调用方修改原始数据引用 |

## 放入 Util 的判断标准

满足以下条件才考虑新增工具模块：

- 至少两个真实调用点存在相同逻辑。
- 函数不依赖玩家、服务实例、Remote、DataStore 或 Workspace。
- 输入相同时输出一致，不修改框架或游戏的外部状态。
- 可以按用途命名，例如 `TableUtil`、`StringUtil`，不能使用含义模糊的 `FunctionModule`。

## 不属于 Util 的内容

- `StorageService:WaitForPlayerData`：依赖玩家在线状态和存档会话生命周期。
- `Logger`、Remote 注册、资源查找：依赖框架服务或 Roblox Instance。
- Speed、Wins、鞋子、奖励等游戏业务逻辑。

## 当前边界

`TableUtil.DeepCopy` 处理普通的、没有循环引用的 Lua table。循环引用、Instance 克隆、序列化和配置读取尚未出现第二个真实需求，不提前加入。
