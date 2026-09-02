# YanzoFrame_V2

> 当前最新稳定标签是 `v2.1.0-storage-reliability`。

这是从 `YanzoFrame_V0` 复制出来的 Roblox 可复用框架工程。`v2.1.0` 已冻结 StorageModule 稳定基线，后续阶段在此基础上补充明确的项目接入边界。

它不是完整游戏工程，也不包含具体玩法。它的目标是让通用底座可以单独理解、单独验证，并让具体项目通过 `Game` 入口接入。

## 当前定位

`YanzoFrame_V0` 已冻结。本项目以 V2.1 StorageModule 为稳定基线，当前开发分支已分离 `Framework` / `Game`，并加入策划使用的 Excel Config 构建工具。

当前仍保留 V0 的最小底座能力：

- Rojo 项目映射
- Server 启动入口
- Client 启动入口
- ServiceRegistry
- ControllerRegistry
- NetService / NetClient
- MemoryStorage / ProfileStoreStorage / StorageService
- Framework/Game 显式 Service 与 Controller 列表
- 三行表头 Excel Config 校验与 Luau 生成

当前版本是 `StorageModule V1.1`：`MemoryStorage` 用于测试，`ProfileStoreStorage` 通过 ProfileStore 保存正式玩家档案。

### v2.1.0 兼容性说明

- 正式存档名已从 `YanzoFrame_PlayerData_V1` 改为 `YanzoFrame_PlayerData_V2`；旧命名空间的数据不会被本版本自动读取。
- 默认开发者整档重置 Service、Remote 和 UI 已移除；框架只保留服务器侧 `StorageService:ResetPlayerData()` 方法。

## 当前不包含什么

- 自制原生 DataStore 适配器
- 数据迁移
- 批量数据维护
- Roblox 运行时读取 Excel、JSON 或 CSV
- 商店系统
- 背包系统
- 敌人系统
- UI 自动布局
- 外部素材系统

## 文件夹含义

| 路径 | 作用 |
|---|---|
| `src/ReplicatedStorage/Framework` | 可复用底座代码 |
| `src/ReplicatedStorage/Game/Shared/Config/Generated` | Excel 生成的客户端可读 Game Config |
| `src/ReplicatedStorage/Module` | 当前模块自己的配置和共享数据 |
| `src/ServerScriptService/Server/Framework` | 通用服务端底座 |
| `src/ServerScriptService/Server/Game` | 具体项目的 Service 注册入口和 Server-only Config |
| `src/StarterPlayer/StarterPlayerScripts/Client/Framework` | 通用客户端底座 |
| `src/StarterPlayer/StarterPlayerScripts/Client/Game` | 具体项目的 Controller 注册入口 |
| `tests` | 仅服务器可见的最小行为测试；默认不自动运行 |
| `docs` | 学习规则和模块设计文档 |
| `scripts` | 本地验证脚本 |
| `design/config/workbooks` | 策划编辑的一个或多个 Excel 配置工作簿 |
| `design/config/config-schema.json` | 程序或 Codex 维护的 Config 字段规则 |

## 创建独立新项目

在框架母版根目录输入一次游戏显示名：

```powershell
.\scripts\New-Game.ps1 "WoodenMan-123"
```

脚本会把显示名 `WoodenMan-123` 自动转换为内部标识 `WoodenMan_123`，在框架母版旁边创建同名目录，并推导 Remote 根目录名与 ProfileStore 名。确认摘要后，它会创建独立目录，将未发布项目的开发存储设为 `Memory`，安装依赖，运行 Config 与模块验证，并初始化无 Commit、无 Remote 的本地 Git 仓库。目标目录已经存在时会停止，不会覆盖。

只预览、不创建时追加 `-WhatIf`；自动化调用需要跳过确认时追加 `-Yes`。源模板存在未提交改动时，脚本默认停止；确实要复制当前未提交状态时必须显式追加 `-AllowDirty`。需要自定义内部标识或目标路径时，仍可直接使用底层 `New-YanzoProject.ps1`。

完整说明见 `docs/新项目创建工作流_NewProjectWorkflow.md`。修改生成器后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ProjectTool.ps1
```

## 常用命令

```powershell
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V2
rokit install
& "$env:USERPROFILE\.rokit\bin\wally.exe" install
& "$env:USERPROFILE\.rokit\bin\stylua.exe" --check src tests
& "$env:USERPROFILE\.rokit\bin\selene.exe" src tests
& "$env:USERPROFILE\.rokit\bin\rojo.exe" build default.project.json --output "$env:TEMP\YanzoFrame_V2.rbxlx"
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

首次使用 Excel Config 工具：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Setup-ConfigTool.ps1
```

新增表结构时，程序或 Codex 先修改 Schema；策划只填写 Excel 第 4 行以后的数据。统一执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-GameConfig.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ConfigTool.ps1
```

`Import-GameConfig.ps1` 会按 Schema 安全创建缺失的工作簿、Sheet 和三行表头，也会在现有键名保持前缀一致时追加新字段；它不会移动、删除或覆盖已有数据。需要创建结构时先关闭 Excel，普通数据导表不需要改 Schema。

简单规则：改 Schema 时先关闭 Excel；只改第 4 行以后的数据时保存即可。新增工作簿也只在 Schema 中指定文件名，由导表工具自动创建，不需要手工新建空 Excel。

Excel 固定使用三行表头：第 1 行是中文释义，第 2 行是英文键名，第 3 行是字段类型，第 4 行起才是数据。完整规则见 `docs/Excel配置工作流_ExcelConfigWorkflow.md`。

不要直接依赖 `stylua`、`selene`、`rojo` 或 `wally` 的裸命令。Windows PATH 可能优先命中 Cargo 或其他全局版本；本项目以 `rokit.toml` 和 `$env:USERPROFILE\.rokit\bin` 中的工具作为唯一验证入口。

`Validate-ModuleBase.ps1` 只在 `ServerPackages` 缺失时执行 `wally install`。依赖已存在时会直接复用，避免验证过程中清空依赖目录并中断正在运行的 Rojo 服务。

## 日志使用

默认启动日志等级在这里配置：

```text
src/ReplicatedStorage/Module/Shared/Config/LogConfig.lua
```

当前稳定候选默认是 `Warn`，避免正常 Play 时刷屏。定位问题时可临时改为 `Info` 或 `Debug`，验收后再恢复 `Warn`。

调试时可以临时改成：

```lua
DefaultLevel = "Info"
```

需要追某一个模块时，优先只打开单个 scope：

```lua
ScopeLevels = {
    NetService = "Debug",
}
```

可用等级从少到多是：`Error`、`Warn`、`Info`、`Debug`。

## 最小行为测试

测试代码映射到 `ServerStorage.UnitTest`，不会复制给 Client。`ServerScriptService.UnitTestRunner` 默认 `Disabled = true`，所以普通 Play 不会自动运行测试。

当前只覆盖最基础、最稳定的公开契约：

- `MemoryStorage` 返回数据副本、更新已打开 key、拒绝读取未打开 key。
- `ProfileStoreStorage` 在打开后的准备阶段异常时释放会话，并拒绝把旧会话更新写进新会话。
- `StorageService` 在同一 UserId 快速重进时接管已经结束的旧加载，不会永久停在 `LOADING`。
- `RemoteGuards` 拒绝非法 Remote 名称。
- `NetResult` 保持统一成功/失败结构。
- Registry 使用调用方传入的显式列表，并保持 Init/Start 顺序。

需要运行时，临时启用 `UnitTestRunner` 后 Play；看到 `[SUMMARY] 11 run, 11 passed, 0 failed` 即通过，完成后恢复禁用。玩家存档跨重进仍属于单独的 Studio 人工验收，不由这组内存测试代替。本稳定版已在开启 API Services 的 Studio Place 中完成一次“写入临时值 -> 重进读回 -> 恢复原值 -> 再次重进确认”的验收；更换 Place、存档名或 Schema 后仍需重新验收。

## Git 简化命令

第一次先运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 setup
```

日常使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 status
powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 update
powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 save -Message "优化启动日志"
```

详细说明见：

```text
docs/Git简化工作流_GitSimpleWorkflow.md
```

## Studio 使用方式

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Serve-Rojo.ps1
```

默认使用 `34872`。同时打开多个项目时，为每个项目指定不同端口：

```powershell
.\scripts\Serve-Rojo.ps1 -Port 34873
```

如果端口被占用，脚本会显示 PID 和进程名，并提供 `[S]` 停止旧 Rojo、`[P]` 输入其他端口、`[C]` 取消。只有占用者能确认是同端口 `rojo.exe serve` 时才提供停止选项；其他程序占用时只能换端口或取消。自动化流程需要替换旧 Rojo 时可追加 `-StopExistingRojo`。然后在 Roblox Studio 中连接对应端口。不要手打裸的 `rojo serve` —— Windows PATH 上可能还装着版本不同的全局 `rojo`（比如 WinGet 装的），版本对不上会导致插件报 `protocolVersion` 相关的错误。

修改 `default.project.json` 或首次执行 `wally install` 后，需要停止并重新运行上面的脚本，再让 Studio 重新连接。

## 掌握顺序

先确认复制件身份正确，再开始 StorageModule 的正式设计和实现。

推荐顺序：

1. `default.project.json`：理解本地文件进入 Roblox 的位置。
2. `Main.server.lua` / `Main.client.lua`：理解前后端入口。
3. `ServiceRegistry` / `ControllerRegistry`：理解模块启动顺序。
4. `Logger` / `Lifecycle`：理解基础工具。
5. `NetService` / `NetClient`：理解前后端通信边界。
6. `MemoryStorage` / `ProfileStoreStorage`：理解测试后端和持久化后端。
7. `StorageService`：理解打开、数据就绪、更新和关闭会话。

掌握检查见：

```text
docs/基础框架掌握清单_FrameworkMasteryChecklist.md
```

StorageModule 使用规则见：

```text
docs/StorageModule使用规则_StorageModuleUsage.md
```

V2 的日常接入与开发顺序见：

```text
docs/YanzoFrame_V2简明操作手册.md
```
