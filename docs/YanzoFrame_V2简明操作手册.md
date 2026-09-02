# YanzoFrame V2 简明操作手册

## 1. 这套框架解决什么问题

YanzoFrame V2 是 Roblox 项目的**最小通用底座**，不是一套已经写好的游戏。

它只负责以下事情：

| 你需要的能力 | 应使用的框架入口 | 谁拥有最终决定权 |
| --- | --- | --- |
| 玩家存档 | `StorageService` | Server |
| Client 与 Server 通信 | `NetClient` / `NetService` | Server |
| 服务器私有模型模板 | `ServerStorage.Resources` / `ResourceService` | Server |
| Client 可见 UI 模板 | `ReplicatedStorage.Resources.UI` | Client 负责显示，Server 负责真实结果 |
| 启动、日志、基础校验 | Registry、`Logger`、Rokit 验证脚本 | 框架 |

它**不负责**商店、背包、货币、鞋子、翅膀、跑步机、奖励数值或场景布局。这些必须留在具体游戏项目的业务代码中。

## 2. 先记住这一张图

```text
本地 src 文件
    │ Rojo 同步
    ▼
Roblox Studio 中的服务与模板
    │
    ├─ Server：Main.server.lua → ServiceRegistry
    │       ├─ Framework ServiceList
    │       └─ GameServiceList
    │       ├─ 修改存档
    │       ├─ 校验 Client 请求
    │       └─ 克隆服务器私有资源
    │
    └─ Client：Main.client.lua → ControllerRegistry
            ├─ Framework ControllerList
            └─ GameControllerList
            ├─ 收集输入
            ├─ 请求 Server
            └─ 克隆 UI 模板、显示 Server 返回结果
```

一句话原则：**Client 只能表达“我想做什么”；Server 决定“能不能做、改什么数据”。**

## 3. 当前目录各放什么

| 路径 | 放什么 | 不要放什么 |
| --- | --- | --- |
| `src/ReplicatedStorage/Framework` | 可复用底座：网络、日志、存档接口、纯工具 | 游戏的鞋子 ID、价格、胜利数 |
| `src/ReplicatedStorage/Game/Shared/Config/Generated` | Excel 生成的 Shared 配置 | Server-only 数值、手写业务逻辑 |
| `src/ReplicatedStorage/Module/Shared/Config` | 当前项目配置与默认存档结构 | 玩家运行时数据 |
| `src/ServerScriptService/Server/Framework/Services` | Server 生命周期、存档、网络、资源 | 具体游戏玩法 Service |
| `src/ServerScriptService/Server/Game` | 具体游戏 Service 和显式 `GameServiceList` | 通用框架底座 |
| `src/ServerScriptService/Server/Game/Config/Generated` | Excel 生成的 Server-only 配置 | Client 可以读取的数据 |
| `src/StarterPlayer/StarterPlayerScripts/Client/Game` | 具体游戏 Controller 和显式 `GameControllerList` | 真实奖励、存档写入 |
| `src/ServerStorage/Resources` | 玩家永远不应直接看到的模型模板 | 已放进地图的展示副本 |
| `src/ReplicatedStorage/Resources/UI` | Client 需要克隆的 UI 模板 | 服务器私有模型 |

`Workspace` 只应放已运行的地图、展示副本和交互对象；不要把原始资源模板长期放在这里。

## 4. 新项目从 V2 开始时，先改哪三处

复制 V2 基线后，先完成以下三件事，再开始写业务。

1. 在 `default.project.json` 修改项目名称；保留现有四类映射：`Framework`、`Module`、`ReplicatedStorage.Resources`、`ServerStorage.Resources`。
2. 在 `RemoteNames.lua` 修改 `RootFolder` 为新项目唯一名称，避免两个 Place 的 Remote 根目录重名。
3. 在 `StorageConfig.lua` 修改 `ProfileStoreName`、默认存档结构和当前项目需要的默认语言；不要把业务数据直接散落进 Service。

当前默认存档形状是：

```text
{
  SchemaVersion = 1,
  Settings = { Language = "zh-CN" },
  Modules = {},
}
```

具体游戏的数据放在 `Modules.你的游戏名`，例如 `Modules.JumpGame`。这样框架只知道“有模块数据”，不知道 Speed、Wins 或物品的业务含义。

## 5. 最常用：服务器业务如何读写玩家数据

业务 Service 只能依赖 `StorageService`，不能直接 `require` `ProfileStoreStorage`、`MemoryStorage` 或第三方 `ProfileStore`。完整接口表和结果码见 `docs/StorageModule使用规则_StorageModuleUsage.md`。

```lua
-- 只负责在 Server 增加一个游戏模块中的胜利数；Client 不传胜利数，也不直接写存档。
function WinService:AddWin(player)
    local ready, reason = self._storageService:WaitForPlayerData(player, 10)
    if not ready then
        return false, reason
    end

    local data = self._storageService:UpdatePlayerModuleData(player, "JumpGame", {
        Wins = 0,
    }, function(moduleData)
        moduleData.Wins += 1
        return moduleData
    end)

    return true, data.Wins
end
```

不要在 Client 用 Attribute 当作永久数据源；Attribute 只能作为 HUD 的运行时镜像。

## 6. Client 与 Server 通信怎么写

### Server：注册请求并校验

1. 在 `RemoteNames.lua` 增加一个名字，例如 `JumpGame.ClaimReward`。
2. 在业务 Service 的 `Start()` 中调用 `NetService:RegisterRequest`。
3. 在 handler 内校验玩家、条件和数据，再调用业务 Service 修改存档。

```lua
-- Server 注册领奖请求；真实资格与奖励数量只在 Server 判断。
function RewardService:Start()
    self._services.NetService:RegisterRequest(RemoteNames.JumpGameClaimReward, function(player, payload)
        if type(payload) ~= "table" then
            return NetResult.Err("INVALID_PAYLOAD", "请求格式不正确")
        end

        local ok, result = self:ClaimReward(player)
        if not ok then
            return NetResult.Err(result, "当前不能领取奖励")
        end

        return NetResult.Ok({ Reward = result })
    end)
end
```

### Client：发送意图并显示结果

```lua
-- Client 只请求领取，不传奖励数量；UI 只根据 Server 返回结果更新。
local result = NetClient.Request(RemoteNames.JumpGameClaimReward, {})
if result.Ok then
    rewardLabel.Text = "领取成功：" .. tostring(result.Data.Reward)
else
    rewardLabel.Text = "领取失败：" .. tostring(result.Code)
end
```

不要让 Client 发送 `Wins = 999`、`Reward = 1000` 这类“希望 Server 直接采纳的结果”。Client 可以发送按钮意图或目标 ID，Server 必须自行计算和校验。

## 7. 资源与 UI 怎么放

### 服务器私有模板

服务器专用模板放在 `src/ServerStorage/Resources/`，查找和克隆调用 `resourceService:FindServerTemplate` / `CloneServerTemplate`；完整规则和路径表见 `docs/ResourceModule使用规则_ResourceModuleUsage.md`。

### Client UI 模板

```text
src/ReplicatedStorage/Resources/UI/
└─ MyPanel.model.json
```

每个复杂 GUI 的 Controller 负责：从 `ReplicatedStorage.Resources.UI` 克隆模板到 `PlayerGui`、绑定按钮、更新文本和控制显示。位置、大小、颜色、层级由模板/Studio 管理，不在 Controller 中硬编码布局。

## 8. 每次开发的固定操作

### 策划修改 Excel 后

首次使用先安装隔离依赖：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Setup-ConfigTool.ps1
```

以后每次修改 `design/config/workbooks` 中的 Excel 后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-GameConfig.ps1
```

只有全部 Sheet、中文释义、英文键名、类型、范围、枚举和引用都通过后，工具才会替换旧的 `Generated` 目录。失败时旧 Luau 保持不变。

### 启动同步

```powershell
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V2
powershell -ExecutionPolicy Bypass -File .\scripts\Serve-Rojo.ps1
```

这个脚本会先 `wally install` 重新生成 `ServerPackages/`（它被 `.gitignore` 排除，不重装会导致 `rojo serve` 因为 `$path` 找不到 `ProfileStore.luau` 而报错退出），再用 Rokit 锁定版本的 `rojo` 启动服务。默认端口是 `34872`；同时打开多个项目时使用 `.\scripts\Serve-Rojo.ps1 -Port 34873` 指定不同端口。端口被占用时会显示进程信息，并提供停止旧 Rojo、输入其他端口或取消三种选择；非 Rojo 占用者不会被终止。自动化流程需要替换旧 Rojo 时可追加 `-StopExistingRojo`。不要自己手打裸的 `rojo`/`wally` 命令——这台机器的 PATH 里可能还装着版本不同的全局 `rojo`（例如 WinGet 装的），裸命令解析到那个版本会导致插件和服务端协议不匹配，报 `protocolVersion` 相关的错误。

在 Roblox Studio 的 Rojo 插件连接脚本输出的地址，例如 `127.0.0.1:34872` 或 `127.0.0.1:34873`。

### 修改后验证

```powershell
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V2
& "$env:USERPROFILE\.rokit\bin\wally.exe" install
& "$env:USERPROFILE\.rokit\bin\stylua.exe" --check src tests
& "$env:USERPROFILE\.rokit\bin\selene.exe" src tests
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ConfigTool.ps1
```

最后在 Studio Play 验收实际链路。静态检查通过只说明代码和 Rojo 映射可用，不等于 UI、模型、存档体验都正确。

验证脚本只会在 `ServerPackages` 缺失时运行 `wally install`；依赖已存在时会复用当前文件，避免日常验证中断正在运行的 Rojo 服务。修改 `wally.toml` 或 `wally.lock` 后，应先停止 Rojo，再重新安装依赖并启动服务。

需要运行最小行为测试时，临时启用 `ServerScriptService.UnitTestRunner` 后 Play，确认输出为 `[SUMMARY] 11 run, 11 passed, 0 failed`，完成后恢复禁用。测试只覆盖 Registry 显式顺序、内存 Storage、ProfileStore 异常与跨会话更新防护、快速重进加载和 Remote 基础契约，不能代替 ProfileStore 跨重进验收。

## 9. 常见问题先查哪里

| 现象 | 先查位置 | 常见原因 |
| --- | --- | --- |
| `ServerStorage.Resources` 缺失 | `default.project.json`、Rojo 是否重启 | 映射没同步或目录不存在 |
| Client 找不到 Remote | `RemoteNames.lua`、对应 Service 的 `Start()` | 名字不一致或 Server 未注册 |
| 玩家刚进入就读不到数据 | `WaitForPlayerData` 返回码 | 数据仍在加载、加载失败或玩家离开 |
| UI 没出现 | `Resources/UI` 模板、`ControllerList.lua` | 模板未同步、Controller 未登记或名称不一致 |
| 日志太多 | `LogConfig.lua` | 稳定候选默认是 `Warn`；检查是否被临时改成 `Info` 或 `Debug` |

## 10. 当前 V2 的边界检查

在准备新增一个“通用模块”前，先过一遍 `docs/V2最小框架边界_MinimumFrameworkScope.md` 里“新能力进入 V2 的五个门槛”；任何一项不满足，就先写在候选记录或留在游戏项目中，不加入框架。

## 11. 推荐掌握顺序

1. `default.project.json`：先明白文件为何会出现在 Studio 的不同服务中。
2. `Main.server.lua`、`ServiceRegistry.lua`、`ServiceList.lua`、`GameServiceList.lua`：明白 Server 如何组合并启动两类 Service。
3. `Main.client.lua`、`ControllerRegistry.lua`、`ControllerList.lua`、`GameControllerList.lua`：明白 Client 如何组合并启动两类 Controller。
4. `NetService.lua`、`NetClient.lua`、`NetResult.lua`：明白请求边界。
5. `StorageService.lua`、`StorageConfig.lua`：明白数据读写与就绪。
6. `ResourceService.lua` 与两个 `Resources` 目录：明白模板可见性。

## 相关文档

- `docs/V2最小框架边界_MinimumFrameworkScope.md`：V2 保留与不保留什么。
- `docs/StorageModule使用规则_StorageModuleUsage.md`：存档 API 的详细规则。
- `docs/ResourceModule使用规则_ResourceModuleUsage.md`：资源目录和查找规则。
- `docs/Excel配置工作流_ExcelConfigWorkflow.md`：Excel 三行表头、多工作簿、生成和错误处理规则。
