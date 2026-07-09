# YanzoFrame_V1_StorageModule

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
- MemoryStorage / StorageService 基础边界
- StartupSmokeTest

Storage 在当前阶段仍是最小内存边界。后续会按阶段讨论是否扩展为 DataStore / ProfileStore 适配器，不会一次性塞入完整线上存档系统。

## 当前不包含什么

- 真实 DataStore
- ProfileStore
- 数据迁移
- 批量数据维护
- JSON / Excel 导入导出
- 商店系统
- 背包系统
- 敌人系统
- UI 自动布局
- 外部素材系统
- Wally 第三方依赖

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
stylua --check src
selene src
rojo build default.project.json --output "$env:TEMP\YanzoFrame_V1_StorageModule.rbxlx"
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

## 日志使用

默认启动日志等级在这里配置：

```text
src/ReplicatedStorage/Module/Shared/Config/LogConfig.lua
```

当前默认是 `Warn`：正常启动只显示警告和错误，避免 Roblox Studio 输出窗口刷屏。

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

## 掌握顺序

先确认复制件身份正确，再开始 StorageModule 的正式设计和实现。

推荐顺序：

1. `default.project.json`：理解本地文件进入 Roblox 的位置。
2. `Main.server.lua` / `Main.client.lua`：理解前后端入口。
3. `ServiceRegistry` / `ControllerRegistry`：理解模块启动顺序。
4. `Logger` / `Lifecycle`：理解基础工具。
5. `NetService` / `NetClient`：理解前后端通信边界。
6. `StorageService` / `MemoryStorage`：理解基础存储边界。
7. `StartupSmokeTest`：理解框架是否成功启动。
8. `StorageModule`：再讨论 Schema、适配器、保存时机和失败处理。

掌握检查见：

```text
docs/基础框架掌握清单_FrameworkMasteryChecklist.md
```

StorageModule 使用规则见：

```text
docs/StorageModule使用规则_StorageModuleUsage.md
```
