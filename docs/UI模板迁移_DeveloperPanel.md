# DeveloperPanel UI 模板迁移

## 目标

把已验收的 `StarterGui.DeveloperPanel` 草稿迁移为 Rojo 管理的客户端可读模板，确保 UI 只有一个权威来源。

## 对象边界

| 对象 | 权威位置 | 谁创建 / 调整布局 | 运行时位置 | 代码允许做什么 | 代码不允许做什么 |
|---|---|---|---|---|---|
| `DeveloperPanel` | `ReplicatedStorage.Resources.UI.DeveloperPanel` | Studio / Rojo 模板 | `PlayerGui.DeveloperPanel` | 克隆、启用、隐藏、改反馈文字、绑定按钮 | 重排布局、改尺寸、改颜色、创建第二份模板 |
| `Panel` 与其子节点 | 模板内部 | Studio / Rojo 模板 | 克隆体内部 | 查找、显示 / 隐藏二次确认、绑定点击 | 改动视觉层级和静态文本布局 |
| `DeveloperPanelController` | `StarterPlayerScripts.Client` | 代码 | 客户端运行时 | 防重复克隆、交互和发请求 | 修改持久化数据或绕过服务端权限 |

## 运行时路径

```text
ReplicatedStorage.Resources.UI.DeveloperPanel（唯一模板）
  -> DeveloperPanelController:Clone()
  -> PlayerGui.DeveloperPanel（当前玩家运行时副本）
  -> 按钮交互 / Developer.ResetMyData
```

## 模板实例清单

以下实例均由 `DeveloperPanel.model.json` 创建；全部**无 Tag、无 Attribute**。在 Studio Edit 模式展开 `ReplicatedStorage.Resources.UI.DeveloperPanel` 即可逐项核对；Play 后同一结构会出现在 `PlayerGui.DeveloperPanel`。

| 实例名称 | ClassName | 父级位置 | Studio 验收 |
|---|---|---|---|
| `UI` | `Folder` | `ReplicatedStorage.Resources` | 存在且包含 `DeveloperPanel`。 |
| `DeveloperPanel` | `ScreenGui` | `ReplicatedStorage.Resources.UI` | 默认 `Enabled = false`，子级为 `Panel`、`ToggleButton`。 |
| `Panel` | `Frame` | `DeveloperPanel` | 深色容器，包含下列 9 个直接子级。 |
| `UICorner`、`UIStroke`、`UISizeConstraint` | `UICorner`、`UIStroke`、`UISizeConstraint` | `Panel` | 圆角为 12px；描边 RGB(79, 129, 189)；最小尺寸 280×260。 |
| `TitleLabel`、其 `UITextSizeConstraint` | `TextLabel`、`UITextSizeConstraint` | `Panel.TitleLabel` | 标题“开发调试”，字号范围 16–24。 |
| `DescriptionLabel`、其 `UITextSizeConstraint` | `TextLabel`、`UITextSizeConstraint` | `Panel.DescriptionLabel` | 说明文字可见，字号范围 12–18。 |
| `ResetButton`、`UICorner`、`UITextSizeConstraint` | `TextButton`、`UICorner`、`UITextSizeConstraint` | `Panel.ResetButton` | 按钮文本“初始化全部数据”，背景 RGB(220, 53, 69)。 |
| `ConfirmFrame`、`UICorner` | `Frame`、`UICorner` | `Panel.ConfirmFrame` | 默认 `Visible = false`。 |
| `ConfirmLabel`、其 `UITextSizeConstraint` | `TextLabel`、`UITextSizeConstraint` | `Panel.ConfirmFrame.ConfirmLabel` | 点击初始化按钮后可见提示文字。 |
| `ConfirmButton`、`UICorner`、`UITextSizeConstraint` | `TextButton`、`UICorner`、`UITextSizeConstraint` | `Panel.ConfirmFrame.ConfirmButton` | 红色确认按钮；本次验收不点击，避免修改真实存档。 |
| `CancelButton`、`UICorner`、`UITextSizeConstraint` | `TextButton`、`UICorner`、`UITextSizeConstraint` | `Panel.ConfirmFrame.CancelButton` | 点击后关闭二次确认；背景 RGB(71, 85, 105)。 |
| `FeedbackLabel`、其 `UITextSizeConstraint` | `TextLabel`、`UITextSizeConstraint` | `Panel.FeedbackLabel` | 默认显示 Studio 限定提示，字号范围 12–18。 |
| `CollapseButton`、`UICorner`、`UITextSizeConstraint` | `TextButton`、`UICorner`、`UITextSizeConstraint` | `Panel.CollapseButton` | 点击后 `Panel.Visible = false`。 |
| `ToggleButton`、`UICorner`、`UIStroke`、`UITextSizeConstraint` | `TextButton`、`UICorner`、`UIStroke`、`UITextSizeConstraint` | `DeveloperPanel.ToggleButton` | 默认隐藏；折叠后显示“调”，点击恢复完整面板。 |

颜色基准：面板背景 RGB(30, 41, 59)，描边 RGB(79, 129, 189)，危险操作按钮 RGB(220, 53, 69)，取消/折叠按钮 RGB(71, 85, 105)。

## 迁移规则

1. `StarterGui` 不再保留同名 `DeveloperPanel`，避免 Roblox 自动复制与 Controller 克隆同时发生。
2. 模板根节点默认 `Enabled = false`；Controller 只在 Studio Play 且配置允许时启用运行时副本。
3. 同一 `PlayerGui` 若已存在 `DeveloperPanel`，Controller 复用它，不创建重复副本。
4. 本次不引入 `UIManager`。只有第二个真实 GUI 出现相同克隆生命周期需求后，才评估 YF-007。

## Studio 验收

1. Edit 模式中：`ReplicatedStorage.Resources.UI.DeveloperPanel` 存在，`StarterGui` 不存在同名 GUI。
2. Play 模式中：`PlayerGui.DeveloperPanel` 由 Controller 创建且只有一份。
3. 面板、折叠图标、二次确认行为与草稿一致。
4. 停止并再次 Play 后仍无重复 GUI。
