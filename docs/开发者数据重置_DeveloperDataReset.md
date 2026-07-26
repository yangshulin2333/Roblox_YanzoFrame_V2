# 开发者数据重置入口

## 解决的问题

持久化存档会保留测试过程中的数据。开发阶段需要能将当前测试玩家恢复为 `StorageConfig.DefaultData`，从而重新验收新手、成长和解锁流程。

## 运行路径

```text
`ReplicatedStorage.Resources.UI.DeveloperPanel` 模板
  -> `DeveloperPanelController` 克隆到 `PlayerGui`
  -> Developer.ResetMyData RemoteFunction
  -> DeveloperService（权限、payload、审计）
  -> StorageService:ResetPlayerData(player)
  -> StorageConfig.DefaultData
  -> 强制当前玩家重新进入
```

当前模板位于 `ReplicatedStorage.Resources.UI.DeveloperPanel`。客户端 `DeveloperPanelController` 只在 Studio Play 中把它克隆到当前玩家的 `PlayerGui`，并且只能调用 `Developer.ResetMyData`，不能携带目标 UserId 或任意数据字段。

`StarterGui` 不再保留同名 GUI，避免 Roblox 自动复制和 Controller 克隆同时发生。当前只有一张模板；因此本次由 `DeveloperPanelController` 直接挂载，不引入通用 UI 管理器。

## 权限规则

配置位置：`ReplicatedStorage.Module.Shared.Config.DeveloperConfig`

- Studio Play：`AllowDataResetInStudio = true` 时，允许当前测试玩家重置自己的数据。
- 正式服务器：默认 `AllowedUserIds = {}`，因此全部拒绝。
- 如需在受控正式测试服使用，必须显式把 Roblox UserId 写为 `AllowedUserIds[UserId] = true`。
- 客户端只能请求“重置我自己”；目标玩家由 RemoteFunction 的 `player` 参数决定。

## 重置语义

`StorageService:ResetPlayerData(player)` 只替换已打开的存档为默认结构，不直接知道任何游戏的 Speed、Wins、背包或 HUD。

`DeveloperService` 在成功后安排玩家离开。玩家重新进入后，各游戏业务服务会从默认档案重新初始化自己的缓存、Attribute 和 UI，避免只重置存档却保留旧运行时状态。

## 最小开发者面板模板

`ReplicatedStorage.Resources.UI.DeveloperPanel` 的唯一用途是验证这条框架链路，不承载 Speed、Wins 或其他游戏业务调试项。

| 名称 | ClassName | 职责 |
|---|---|---|
| `DeveloperPanel` | `ScreenGui` | 面板根节点，客户端在非 Studio 环境隐藏它。 |
| `Panel` | `Frame` | 深色面板容器。 |
| `CollapseButton` | `TextButton` | 展开状态显示；点击后隐藏面板。 |
| `ToggleButton` | `TextButton` | 折叠状态显示在侧边；点击后恢复面板。 |
| `ResetButton` | `TextButton` | 打开二次确认，不直接写数据。 |
| `ConfirmFrame` | `Frame` | 二次确认区域，默认隐藏。 |
| `ConfirmButton` | `TextButton` | 发起空载荷重置请求。 |
| `CancelButton` | `TextButton` | 关闭二次确认。 |
| `FeedbackLabel` | `TextLabel` | 显示等待、成功或失败结果。 |

建议颜色：面板背景 `RGB(30, 41, 59)`，危险操作按钮 `RGB(220, 53, 69)`，取消按钮 `RGB(71, 85, 105)`，确认提示 `RGB(251, 191, 36)`，失败文字 `RGB(248, 113, 113)`。

## 结果码

| 结果码 | 含义 |
|---|---|
| `DATA_RESET_COMPLETE` | 默认数据已写入，需重新进入 |
| `DATA_NOT_READY` | 玩家档案尚未打开 |
| `DATA_RESET_FAILED` | 默认数据写入失败 |
| `DEVELOPER_RESET_DISABLED` | 当前环境配置关闭了入口 |
| `DEVELOPER_NOT_ALLOWED` | 正式服务器中当前玩家不在白名单 |
| `PLAYER_LEFT` | 请求处理时玩家已离开 |
| `INVALID_PAYLOAD` | 客户端携带了不允许的数据字段 |

## 非目标

- 不提供 `ResetSpeed`、`SetWins`、赠送物品等游戏业务操作。
- 不允许重置其他玩家。
- 不依赖客户端二次确认实现安全；二次确认只属于未来 UI 的防误点体验。
