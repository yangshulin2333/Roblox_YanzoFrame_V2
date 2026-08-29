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
    ├─ Server：Main.server.lua → ServiceRegistry → ServiceList 中的 Service
    │       ├─ 修改存档
    │       ├─ 校验 Client 请求
    │       └─ 克隆服务器私有资源
    │
    └─ Client：Main.client.lua → ControllerRegistry → ControllerList 中的 Controller
            ├─ 收集输入
            ├─ 请求 Server
            └─ 克隆 UI 模板、显示 Server 返回结果
```

一句话原则：**Client 只能表达“我想做什么”；Server 决定“能不能做、改什么数据”。**

## 3. 当前目录各放什么

| 路径 | 放什么 | 不要放什么 |
| --- | --- | --- |
| `src/ReplicatedStorage/Framework` | 可复用底座：网络、日志、存档接口、纯工具 | 游戏的鞋子 ID、价格、胜利数 |
| `src/ReplicatedStorage/Module/Shared/Config` | 当前项目配置与默认存档结构 | 玩家运行时数据 |
| `src/ServerScriptService/Server/Framework/Services` | Server 生命周期、存档、网络、资源 | 具体游戏玩法 Service |
| `src/StarterPlayer/StarterPlayerScripts/Client/Framework/Controllers` | 每个复杂 UI 的 Client 控制器 | 真实奖励、存档写入 |
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

业务 Service 只能依赖 `StorageService`，不能直接 `require` `ProfileStoreStorage`、`MemoryStorage` 或第三方 `ProfileStore`。

最小使用顺序：

1. 玩家进入后先等待数据就绪。
2. 读取或更新自己业务模块的数据。
3. 把可显示的结果同步给 Client；如果需要 Network，就让 Client 请求 Server，Server 返回结果。

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

要点：

- `GetPlayerModuleData` 返回的是副本，改完副本不会保存。
- 需要保存时使用 `UpdatePlayerModuleData`。
- `WaitForPlayerData` 失败时要处理其结果，例如 `DATA_LOAD_FAILED`、`DATA_READY_TIMEOUT`、`PLAYER_LEFT`。
- 不要在 Client 用 Attribute 当作永久数据源；Attribute 只能作为 HUD 的运行时镜像。

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

```text
src/ServerStorage/Resources/
└─ Accessories/
   └─ StarterHat
```

Server 需要生成运行时副本时：

```lua
-- 只从 ServerStorage.Resources 查找模板，并克隆到明确的运行时父级。
local clone, reason = resourceService:CloneServerTemplate("Accessories/StarterHat", workspace.RuntimeItems)
if clone == nil then
    warn("资源创建失败：" .. reason)
end
```

`ResourceService` 当前只提供服务器模板的查找和克隆。它不管理价格、装备资格、资源 ID 商城或自动导入。

### Client UI 模板

```text
src/ReplicatedStorage/Resources/UI/
└─ MyPanel.model.json
```

每个复杂 GUI 的 Controller 负责：从 `ReplicatedStorage.Resources.UI` 克隆模板到 `PlayerGui`、绑定按钮、更新文本和控制显示。位置、大小、颜色、层级由模板/Studio 管理，不在 Controller 中硬编码布局。

## 8. 每次开发的固定操作

### 启动同步

```powershell
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V2
& "$env:USERPROFILE\.rokit\bin\rojo.exe" serve default.project.json --address 127.0.0.1 --port 34872
```

在 Roblox Studio 的 Rojo 插件连接 `127.0.0.1:34872`。

### 修改后验证

```powershell
cd D:\AI\Codex\Codex_ModuleDev\YanzoFrame_V2
& "$env:USERPROFILE\.rokit\bin\wally.exe" install
& "$env:USERPROFILE\.rokit\bin\stylua.exe" --check src
& "$env:USERPROFILE\.rokit\bin\selene.exe" src
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ModuleBase.ps1
```

最后在 Studio Play 验收实际链路。静态检查通过只说明代码和 Rojo 映射可用，不等于 UI、模型、存档体验都正确。

## 9. 常见问题先查哪里

| 现象 | 先查位置 | 常见原因 |
| --- | --- | --- |
| `ServerStorage.Resources` 缺失 | `default.project.json`、Rojo 是否重启 | 映射没同步或目录不存在 |
| Client 找不到 Remote | `RemoteNames.lua`、对应 Service 的 `Start()` | 名字不一致或 Server 未注册 |
| 玩家刚进入就读不到数据 | `WaitForPlayerData` 返回码 | 数据仍在加载、加载失败或玩家离开 |
| UI 没出现 | `Resources/UI` 模板、`ControllerList.lua` | 模板未同步、Controller 未登记或名称不一致 |
| 日志太多 | `LogConfig.lua` | 当前 V2 基线默认是 `Debug`；稳定后可改回 `Warn` |

## 10. 当前 V2 的边界检查

在准备新增一个“通用模块”前，先问五个问题：

1. 它是否不包含具体游戏名称、货币、价格、奖励和场景布局？
2. 是否已经有至少两个真实调用点或两个项目遇到同一问题？
3. 能否一句话说清 API、数据所有者和失败结果？
4. 是否有最小验证方式？
5. 接入时是否不用重写已有游戏业务？

任何一项答案是否定的，就先写在候选记录或留在游戏项目中，不加入框架。

## 11. 推荐掌握顺序

1. `default.project.json`：先明白文件为何会出现在 Studio 的不同服务中。
2. `Main.server.lua`、`ServiceRegistry.lua`、`ServiceList.lua`：明白 Server 如何启动。
3. `Main.client.lua`、`ControllerRegistry.lua`、`ControllerList.lua`：明白 Client 如何启动。
4. `NetService.lua`、`NetClient.lua`、`NetResult.lua`：明白请求边界。
5. `StorageService.lua`、`StorageConfig.lua`：明白数据读写与就绪。
6. `ResourceService.lua` 与两个 `Resources` 目录：明白模板可见性。

## 相关文档

- `docs/V2最小框架边界_MinimumFrameworkScope.md`：V2 保留与不保留什么。
- `docs/StorageModule使用规则_StorageModuleUsage.md`：存档 API 的详细规则。
- `docs/ResourceModule使用规则_ResourceModuleUsage.md`：资源目录和查找规则。
