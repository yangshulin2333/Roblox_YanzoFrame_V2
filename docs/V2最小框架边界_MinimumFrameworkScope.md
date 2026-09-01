# V2 最小框架边界

## 目的

V2 的目标不是“预先准备所有游戏系统”，而是让新项目能稳定启动、由服务器安全处理数据、让客户端可显示结果，并让开发期可以排错和通过服务器入口重置测试档案。

任何不满足这个目标的能力，先留在具体游戏项目或候选记录中，不进入 V2。

## 当前保留

| 范围 | 保留内容 | 保留原因 |
|---|---|---|
| 启动 | `ServiceRegistry`、`ControllerRegistry`、`Lifecycle` | 统一并可验证地启动服务与控制器。 |
| 项目边界 | Framework 列表、`GameServiceList`、`GameControllerList` | 通用底座先启动，具体项目模块后启动，双方目录不混放。 |
| 日志 | `Logger`、`LogConfig` | 排错需要统一格式、等级和业务调用方文本。 |
| 网络 | `NetService`、`RemoteNames`、`NetResult`、`RemoteGuards` | 客户端请求与服务器校验的最小边界。 |
| 存档 | `StorageService`、存储适配器、`StorageConfig` | V2 的核心目标：服务器权威的玩家数据生命周期。 |
| 资源 | `ServerStorage.Resources`、`ReplicatedStorage.Resources`、`ResourceService` | 区分服务器模板、客户端可读模板和运行时副本。 |
| 纯工具 | `TableUtil.DeepCopy` | 已有多处真实调用，且不依赖 Roblox 生命周期。 |
| UI 模板 | `Resources.UI`、每个 GUI 自己的 Controller | 已解决模板来源和运行时 `PlayerGui` 副本的职责问题。 |
| 配置构建 | 双表头 Excel、Schema、Luau 生成工具 | 三人团队已有策划直接调数需求；工具只在本地运行，不进入 Roblox 运行时。 |

## 当前明确不加入

| 不加入的内容 | 以后归属 / 进入条件 |
|---|---|
| 商店、背包、装备、鞋子、翅膀、跑步机 | 具体游戏 Service；不能进入 V2。 |
| `SetSpeed`、`SetWins`、赠送物品 | 具体游戏开发面板；框架只保留服务器侧整档重置方法，不默认提供 Remote 或 UI。 |
| 通用 `UIManager` | 至少第二个复杂 GUI 出现相同的模板挂载与生命周期代码后，重新评估 YF-007。 |
| 全局 `InitContext` 类型系统 | 至少第二个 Service 出现相同的局部类型需求后，重新评估 YF-008。 |
| 通用 Accessory 挂载服务 | 至少第二种饰品完成同样的服务器挂载与重生验证后，重新评估 YF-010。 |
| 资源商城、资源 ID 表、自动下载或导入 | 游戏或制作工具职责，不属于运行时基础框架。 |
| 数据迁移、批量运维、运行时 Excel/JSON/CSV 读取 | 当前没有真实维护需求，不预先实现。 |
| Controller 全部并行启动 | 先由具体项目证明同步启动造成重复阻塞问题，再处理 YF-004。 |

## 新能力进入 V2 的五个门槛

新增能力必须同时满足：

1. 不包含具体游戏名、装备 ID、货币、价格、奖励或场景布局。
2. 至少存在两个真实调用点，或两个项目都出现同一问题。
3. 可以用一句话说明公开接口、数据所有者和失败结果。
4. 有最小自动检查或 Studio 验收步骤。
5. 不需要为了接入它而改写现有游戏业务逻辑。

任一条件不满足时，只记录到候选文件，不新增模块、服务或管理器。

## 删除与收敛规则

1. 只有“转发调用”的浅模块，不新增；已有同类代码出现时优先合并回明确所有者。
2. 只有一个使用点的辅助函数，先留在原脚本；满足重复证据后才进入 `Util`。
3. 任何新 Service 必须拥有服务器权威状态、生命周期或跨业务的基础能力；否则不进入 `ServiceRegistry`。
4. 任何新 UI 先作为 `Resources.UI` 模板和专属 Controller；第二个复杂界面前不抽象统一管理器。
5. 删除框架代码前先确认没有第二个调用者，并运行完整 `Validate-ModuleBase.ps1` 和 Studio Play。

## 当前结论

V2 只保留已确认的通用能力。具体玩法通过 `Game` 列表接入，不进入 `Framework`；下一次修改仍需先明确真实证据、范围、验收方式和不做项。

Excel Config 属于开发期构建工具：策划编辑 Excel，程序维护 Schema，生成器输出 Shared 或 Server-only Luau。它不新增 Service，不依赖 Storage，也不随游戏运行。
