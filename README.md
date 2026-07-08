# YanzoFrame_V0

这是一个 Roblox 可复用模块开发底座。

它不是完整游戏工程，也不是任何具体游戏工程。它的目标是让每个模块可以单独学习、单独验证、最后再接入别的项目。

## 当前定位

YanzoFrame_V0 是后续复制用的基础框架本体。

它只保留所有模块都会用到的最小能力：

- Rojo 项目映射
- Server 启动入口
- Client 启动入口
- ServiceRegistry
- ControllerRegistry
- NetService / NetClient
- MemoryStorage / StorageService 基础边界
- StartupSmokeTest

Storage 在这里不是完整存储模块。它只是基础框架的一条最小数据边界，用来让后续模块可以先用内存数据验证逻辑。

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
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V0
stylua --check src
selene src
rojo build default.project.json --output "$env:TEMP\YanzoFrame_V0.rbxlx"
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

## Studio 使用方式

```powershell
rojo serve default.project.json --address 127.0.0.1 --port 34872
```

然后在 Roblox Studio 中连接 Rojo 插件。

## 掌握顺序

先完全掌握基础框架，再开始第一个正式模块。

推荐顺序：

1. `default.project.json`：理解本地文件进入 Roblox 的位置。
2. `Main.server.lua` / `Main.client.lua`：理解前后端入口。
3. `ServiceRegistry` / `ControllerRegistry`：理解模块启动顺序。
4. `Logger` / `Lifecycle`：理解基础工具。
5. `NetService` / `NetClient`：理解前后端通信边界。
6. `StorageService` / `MemoryStorage`：理解基础存储边界。
7. `StartupSmokeTest`：理解框架是否成功启动。

掌握检查见：

```text
docs/基础框架掌握清单_FrameworkMasteryChecklist.md
```
