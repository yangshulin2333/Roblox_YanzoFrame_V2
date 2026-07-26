# YanzoFrame_V1_StorageModule

> 当前发布基线：**YanzoFrame V2.0.0 – Framework Baseline**。仓库与本地目录继续保留历史名称，避免影响既有 Rojo 映射和 Studio 工程路径。

这是从 `YanzoFrame_V0` 复制出来的第一个正式 Roblox 可复用模块工程，用于学习和开发 `StorageModule`。

它不是完整游戏工程，也不是任何具体游戏工程。它的目标是让 StorageModule 可以单独学习、单独验证、最后再接入别的项目。

## 当前定位

`YanzoFrame_V0` 已作为基础框架本体冻结。本项目是 V1 复制件，当前只做 StorageModule。

当前仍保留 V0 的最小底座能力：

- Rojo 项目映射
- Server 启动入口
- Client 启动入口
- ServiceRegistry
- ControllerRegistry
- NetService / NetClient
- MemoryStorage / ProfileStoreStorage / StorageService

当前版本是 `StorageModule V1.1`：`MemoryStorage` 用于测试，`ProfileStoreStorage` 通过 ProfileStore 保存正式玩家档案。

## 当前不包含什么

- 自制原生 DataStore 适配器
- 数据迁移
- 批量数据维护
- JSON / Excel 导入导出
- 商店系统
- 背包系统
- 敌人系统
- UI 自动布局
- 外部素材系统

## 文件夹含义

| 路径 | 作用 |
|---|---|
| `src/ReplicatedStorage/Framework` | 可复用底座代码 |
| `src/ReplicatedStorage/Module` | 当前模块自己的配置和共享数据 |
| `src/ServerScriptService/Server` | 服务端入口和服务 |
| `src/StarterPlayer/StarterPlayerScripts/Client` | 客户端入口和控制器 |
| `docs` | 学习规则和模块设计文档 |
| `scripts` | 本地验证脚本 |

## 常用命令

```powershell
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V1_StorageModule
rokit install
& "$env:USERPROFILE\.rokit\bin\wally.exe" install
& "$env:USERPROFILE\.rokit\bin\stylua.exe" --check src
& "$env:USERPROFILE\.rokit\bin\selene.exe" src
& "$env:USERPROFILE\.rokit\bin\rojo.exe" build default.project.json --output "$env:TEMP\YanzoFrame_V1_StorageModule.rbxlx"
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

不要直接依赖 `stylua`、`selene`、`rojo` 或 `wally` 的裸命令。Windows PATH 可能优先命中 Cargo 或其他全局版本；本项目以 `rokit.toml` 和 `$env:USERPROFILE\.rokit\bin` 中的工具作为唯一验证入口。

## 日志使用

默认启动日志等级在这里配置：

```text
src/ReplicatedStorage/Module/Shared/Config/LogConfig.lua
```

当前 V2 基线默认是 `Debug`，便于开发期观察启动和数据链路；准备稳定试玩或发布时，可改回 `Warn`，避免 Roblox Studio 输出窗口刷屏。

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
rojo serve default.project.json --address 127.0.0.1 --port 34872
```

然后在 Roblox Studio 中连接 Rojo 插件。

修改 `default.project.json` 或首次执行 `wally install` 后，需要停止并重新运行 `rojo serve`，再让 Studio 重新连接。

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
