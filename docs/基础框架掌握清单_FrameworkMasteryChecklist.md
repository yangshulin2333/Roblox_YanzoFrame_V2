# 基础框架掌握清单

这个清单用于判断：是否可以开始第一个正式模块。

在完成这些问题前，不进入完整 StorageModule 开发。

## 1. Rojo 映射

你需要能回答：

- `default.project.json` 是做什么的？
- `ReplicatedStorage.Framework` 来自本地哪个文件夹？
- `ReplicatedStorage.Module` 和 `Framework` 有什么区别？
- Server 代码会进入 Roblox 的哪个服务？
- Client 代码会进入 Roblox 的哪个服务？

## 2. 启动入口

你需要能回答：

- `Main.server.lua` 做了什么？
- `Main.client.lua` 做了什么？
- 为什么入口文件不直接写业务逻辑？

## 3. ServiceRegistry

你需要能回答：

- `ServiceList` 是什么？
- `ServiceRegistry` 为什么要先注册所有 Service？
- `Init` 和 `Start` 的区别是什么？
- 新增一个 Service 要改哪些文件？

## 4. ControllerRegistry

你需要能回答：

- `ControllerList` 是什么？
- Controller 和 Service 有什么区别？
- 为什么 Client 不能直接决定金币、背包、等级？

## 5. Net 基础

你需要能回答：

- `NetService` 在 Roblox 里创建了哪些 Remote 文件夹？
- `NetClient.Request()` 用来做什么？
- `NetResult.Ok()` 和 `NetResult.Err()` 有什么区别？
- 为什么 Remote 名字要放在 `RemoteNames` 里？

## 6. Storage 基础边界

你需要能回答：

- 为什么基础框架保留 Storage？
- 为什么现在不做 DataStore？
- `MemoryStorage:Get()` 为什么返回副本？
- `StorageService` 和 `MemoryStorage` 有什么区别？
- `StorageConfig` 为什么只保留 `SchemaVersion`？

## 7. 验证

你需要能独立运行：

```powershell
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V0
stylua --check src
selene src
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

你还需要能在 Studio 中确认：

- Server 输出 `服务端启动冒烟测试通过`
- Client 输出 `客户端启动冒烟测试通过`

## 进入第一个模块前的标准

满足下面条件后，才开始第一个正式模块：

- 能说清楚框架文件夹结构。
- 能说清楚 Server 和 Client 的责任边界。
- 能说清楚 Service / Controller 的启动流程。
- 能说清楚 Net 请求的基础流程。
- 能说清楚 Storage 当前为什么只是基础边界。
- 能独立跑通过验证命令。
