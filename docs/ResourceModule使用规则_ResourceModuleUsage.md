# ResourceModule 使用规则

## 目标

`ResourceModule` 只管理资源模板的来源位置、可见性和服务器克隆入口。它不管理任何游戏的资源 ID、价格、奖励、装备资格、存档字段或场景布局。

## 资源位置

| 资源用途 | 源目录 | 读取者 | 运行时副本 |
|---|---|---|---|
| 服务器专用模板 | `ServerStorage.Resources` | 仅 Server | 由 Server 克隆到 Character 或 Workspace |
| 客户端可读模板 | `ReplicatedStorage.Resources` | Client / Server | 由对应 Controller 或 Service 创建副本 |
| 场景展示与 Trigger | `Workspace.Map` | Studio / Server / Client | 原地使用，不是模板库 |
| 临时导入与对位 | `Workspace._Workbenches` | Studio | 验收后清理或转移为正式模板 |

## 服务器模板调用

Server Service 可通过 `ResourceService` 使用路径键查找或克隆模板：

```lua
local template, findError = resourceService:FindServerTemplate("Accessories/StarterHat")
local clone, cloneError = resourceService:CloneServerTemplate("Accessories/StarterHat", character)
```

- 路径键使用 `/` 分段，不能包含空段、`.` 或 `..`。
- `FindServerTemplate` 不修改模板；`CloneServerTemplate` 只会克隆到调用方传入的明确父级。
- 资源不存在时返回 `nil, "RESOURCE_NOT_FOUND"`；非法路径返回 `nil, "INVALID_RESOURCE_KEY"`；父级非法时返回 `nil, "INVALID_PARENT"`。
- 客户端不能访问 `ServerStorage.Resources`。需要由客户端读取的模板必须放入 `ReplicatedStorage.Resources`，但该目录不代表客户端拥有业务数据修改权。

## 新增正式资源的 Studio 验收

1. 在 `Workspace._Workbenches` 完成导入、R15 对位或视觉检查。
2. 将通过验收的服务器模板移入 `ServerStorage.Resources`，或将必须给客户端读取的模板移入 `ReplicatedStorage.Resources`。
3. 由对应游戏 Server Service 验证资格、消耗和状态后，再调用 `ResourceService:CloneServerTemplate`。
4. 在 Play 中确认运行时副本出现于预期父级，停止后模板仍只保留在资源目录。
5. 清理 `_Workbenches` 的原始导入件，确保没有两个正式来源。

## 日志文本约定

- Logger 的 `scope` 保持英文模块名，例如 `ResourceService`，便于筛选和定位代码。
- 输出给开发者阅读的日志 message 使用中文，例如“服务器资源根目录已就绪”。
- 错误码、资源路径键与 Roblox 技术名称保持英文，例如 `RESOURCE_NOT_FOUND`、`ServerStorage.Resources`。

## 当前不做

- 自动上传、下载、扫描或迁移 Roblox 作品资源。
- 同名封装 Roblox 原生 `AssetService`。
- 把鞋子、翅膀、跑步机等游戏资源或规则加入 V2。
