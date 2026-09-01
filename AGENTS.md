# YanzoFrame_V2 Agent Rules

本项目用于维护 YanzoFrame V2 的可复用 Roblox 框架能力。

## 固定目标

`YanzoFrame_V0` 已冻结，`v2.1.0-storage-reliability` 是当前稳定基线。后续只在独立阶段中推进经过确认的框架能力。

当前固定目标：

- 保持 V0 底座结构可理解、可验证。
- 保持 StorageModule V1.1 的稳定边界。
- 让 `Framework` 与具体项目的 `Game` 代码明确分离。
- 让策划通过双表头 Excel 编辑 Config，由本地工具校验并生成 Luau。
- 每次只推进一个清晰的小阶段。
- 模块要能单独理解、单独验证、单独接入别的 Roblox 项目。

## 语言规则

- 文档、解释、交接默认中文。
- 代码文件名、变量名、函数名使用简单英文。
- 必须用英文时，使用短句和常见单词。

## 代码边界

- `Framework` 放通用底座。
- `Game` 放具体项目的 Service、Controller 和业务配置。
- `Module` 放当前模块自己的配置和共享数据。
- Framework 列表先启动，Game 列表后启动；两类列表都必须显式登记。
- Server 负责真实状态修改。
- Client 只负责请求和显示。
- 配置写在表里，不把数值散落在逻辑里。
- 不把商店、背包、敌人、奖励等业务逻辑写进 StorageModule。

## Storage 边界

当前复制件已进入 `StorageModule V1.1` 持久化阶段。

当前已存在：

- `MemoryStorage`
- `ProfileStoreStorage`
- `StorageService`
- `StorageConfig`
- `Open / IsOpen / Get / Set / Update / Close`
- 默认数据校验
- 玩家数据加载失败和会话结束处理

当前阶段不加入：

- 自制原生 DataStore 适配器
- 数据迁移
- 批量维护
- 业务字段，例如 Coins、Items、Shop、Inventory

Excel Config 是仓库外的构建工具，不进入 Storage 或 Roblox 运行时。Shared 和 Server 生成目录必须分离，生成文件不能手改。

业务服务只能依赖 `StorageService`，不能直接依赖 `MemoryStorage`、`ProfileStoreStorage` 或 `ProfileStore`。
`Get` 只能读取已经打开的数据；只有 `Open` 可以加载或创建默认数据。`Close` 表示保存并释放会话，不表示删除永久数据。

## UI / Studio 边界

凡是位置、大小、颜色、层级、布局，默认 Studio 管。

代码只做：

1. 找到对象。
2. 绑定按钮事件。
3. 改文本、数值、显示隐藏。
4. 播放简单状态反馈。
5. 克隆明确标记为 Template 的对象。

代码默认不做：

- 不重排手工 UI。
- 不改手工对象尺寸位置。
- 不删除手工对象。
- 不把复杂 UI 全部代码生成。

## 验证要求

修改代码后至少运行：

```powershell
& "$env:USERPROFILE\.rokit\bin\wally.exe" install
& "$env:USERPROFILE\.rokit\bin\stylua.exe" --check src tests
& "$env:USERPROFILE\.rokit\bin\selene.exe" src tests
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ConfigTool.ps1
```

不得依赖 Windows PATH 中的同名裸命令。项目工具版本以 `rokit.toml` 为准；新机器先在项目根目录执行 `rokit install`。

涉及 Roblox Studio 的内容，还需要 Studio 手动确认。

`tests` 只放服务器侧最小行为测试。测试映射到 `ServerStorage.UnitTest`，`UnitTestRunner` 必须默认禁用，不能让普通 Play 自动执行测试。
