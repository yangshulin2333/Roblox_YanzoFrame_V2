# ADR-001：资源模块边界（ResourceModule）

## 状态

已接受；`ResourceModule v0.1` 已完成目录映射、服务器查找与克隆入口。实际游戏资源模板验证仍由各游戏项目完成。

> 本 ADR 写于框架仍称为 V1 的阶段，按 ADR 惯例记录当时的决策上下文，正文中的 "V1" 不随后续改名回溯修改。当前框架世代请参照 `docs/V2最小框架边界_MinimumFrameworkScope.md`。

## 日期

2026-07-26

## 背景

`YanzoFrame_V2_JumpGame` 已出现多个资源管理问题：可穿戴 Accessory 的服务器模板、场景展示模型、临时对位模型和 Place-only 跑步机模型没有稳定的来源边界。一次场景回退只能恢复代码，不能恢复 Place 内的原跑步机，说明“资源来源”和“运行时场景副本”必须独立管理。

这不是把鞋子、翅膀或跑步机业务放入框架；它们的 ID、价格、奖励、装备规则和地图布局仍属于游戏。

## 决策

V1 的下一轮能力规划为独立的 `ResourceModule`。它只定义通用资源契约：

1. 资源模板的唯一来源和可见性约定；
2. 服务器安全查找/克隆服务器专用模板的入口；
3. 客户端可读模板的明确读取边界；
4. 缺失资源、错误路径和错误类型的可观察失败信息；
5. 临时工作台资源与正式模板的清理约定。

建议的资源归属如下：

| 资源类别 | 权威位置 | 读取者 | 运行时副本位置 | 说明 |
|---|---|---|---|---|
| 服务器专用模板 | `ServerStorage.Resources` | Server | Character / Workspace | 例如服务端验证后才克隆的 Accessory。 |
| 客户端必须读取的模板 | `ReplicatedStorage.Resources` | Client / Server | PlayerGui / Workspace | 例如 UI 模板或纯展示模板。 |
| 场景展示和交互对象 | `Workspace.Map` | Studio / Server / Client | 原地使用 | 只保留已锚定的展示副本和 Trigger，不作为模板库。 |
| 临时导入和对位对象 | `Workspace._Workbenches` | Studio | 不进入运行时 | 验收后必须清理或转移为正式模板。 |

## 不属于 ResourceModule

- 鞋子、翅膀、跑步机、宠物等具体资源 ID；
- 胜利数消耗、装备资格、奖励、存档字段和 UI 业务；
- 自动上传 Roblox 资源、下载作品或扫描并迁移旧 Place；
- Roblox 原生 `AssetService` 的同名包装。

## 预期接口方向（非代码承诺）

`ResourceService` 应是框架层通用入口，游戏侧配置负责把业务 ID 映射到具体资源路径。预期最小能力为“按已验证路径取得模板”“服务器克隆服务器模板”“返回可识别的失败结果”。客户端不得直接修改服务器专用模板；数据修改仍由游戏 Server Service 负责。

## 实施前置条件

1. 审计 V1 当前 `default.project.json` 是否已安全映射 `ServerStorage` 与 `ReplicatedStorage` 资源目录；
2. 保留现有 `v1.1-storage-persistence` 基线；
3. 保留用户本地 `LogConfig.lua` 的 Debug 改动，不将它混入资源模块提交；
4. 为每次 Studio-only 资源结构调整先建立带时间戳的 `.rbxl` 本地副本。

## 验收

- 一个服务器专用 Accessory 模板可由 Server 安全克隆，Client 无法直接取得模板；
- 一个客户端可读模板能由 Client 读取，不产生重复运行时副本；
- 工作台对象不会被误当作正式模板；
- 模板缺失时日志能给出资源键、预期位置和调用边界；
- 删除游戏配置后，框架仍不包含任何 JumpGame 的业务名称或数值。

## 回滚

第一版仅新增目录、文档与最小服务，不迁移既有 Place 资源。若 Rojo 映射或模板查找验证失败，只移除新资源映射和服务注册，保留原 Place 资源与本地 `.rbxl` 备份；禁止使用 `git reset --hard`。

## v0.1 实现记录

- `default.project.json` 已显式映射 `ServerStorage.Resources` 与 `ReplicatedStorage.Resources`。
- `ResourceService` 仅在 Server 注册，提供 `FindServerTemplate(resourceKey)` 与 `CloneServerTemplate(resourceKey, parent)`。
- 服务端资源路径使用 `/` 分段；缺失资源、非法资源键和非法父级分别返回可识别错误码。
- 本版本没有 Remote、DataStore、资产 ID、游戏配置或自动资源迁移。
- 已通过锁定版 `wally`、`stylua`、`selene`、模块基线构建及 Rojo sourcemap 校验。
- 2026-07-26 已由开发者在 Studio 验收：两个 `Resources` Folder 已出现，Play 后 `[ResourceService]` 中文启动日志正常输出。
- 尚未把任何 JumpGame 鞋子、翅膀或跑步机模板迁入 V1；实际 Accessory 与客户端展示模板的 Studio 链路验证，必须在后续使用本契约的游戏项目中完成。
