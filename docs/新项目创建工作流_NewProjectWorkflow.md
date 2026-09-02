# 新项目创建工作流

## 目标

`New-Game.ps1` 是日常使用入口：输入一次游戏显示名，它会自动推导项目标识和目标路径，再调用底层 `New-YanzoProject.ps1`，把当前已验证的 YanzoFrame V2 模板转换成一个独立的新项目，并在交付前完成依赖安装、Config 校验、代码检查和 Rojo 构建。

这个工具只负责初始化开发环境，不负责创建玩法、正式 UI、场景资源、GitHub 仓库或 Roblox Experience。

## 游戏名规则

- 使用简单英文名称，例如 `EggGame`、`WoodenMan-123`。
- 必须以英文字母开头。
- 可以包含英文字母、数字、空格、连字符和下划线。
- 最长 30 个字符。

空格和连字符会自动转换成内部标识的下划线。例如 `WoodenMan-123` 会生成 `WoodenMan_123`，但文件夹仍保留原显示名。

## 第一次使用

在框架母版根目录直接运行：

```powershell
.\scripts\New-Game.ps1 "WoodenMan-123"
```

脚本会显示游戏名、内部标识、目标路径、Remote 根目录名和 ProfileStore 名，并询问是否创建。只想预览、不创建时运行：

```powershell
.\scripts\New-Game.ps1 "WoodenMan-123" -WhatIf
```

新项目默认创建在框架母版旁边。目标目录本身必须不存在，工具使用原子目录移动形成最终项目；即使其他程序在生成过程中创建了同名目录，也会立即停止，不会合并、覆盖或删除该目录。自动化流程确实需要跳过确认时，可以追加 `-Yes`。

源模板存在未提交改动时，创建和预览都会默认停止并返回 `PROJECT_SOURCE_DIRTY`。先提交或清理模板改动；只有明确需要复制当前未提交状态时，才显式追加 `-AllowDirty`。`-AllowDirty` 只是确认来源状态，不会放宽目标目录覆盖保护。

## 默认项目标识

当游戏显示名是 `WoodenMan-123` 时，默认生成：

| 项目标识 | 默认值 |
| --- | --- |
| 游戏显示名与目录 | `WoodenMan-123` |
| Rojo 项目名 | `WoodenMan_123` |
| Remote 根目录 | `WoodenMan_123_Remotes` |
| ProfileStore 名 | `WoodenMan_123_PlayerData_V1` |
| 本地开发存储 | `Memory` |

确实需要自定义内部标识或目标路径时，再直接使用底层脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\New-YanzoProject.ps1 `
  -ProjectName "EggGame" `
  -Destination "C:\Roblox\EggGame" `
  -RemoteRootName "EggGame_Remotes" `
  -ProfileStoreName "EggGame_PlayerData_V1"
```

## 工具实际执行的步骤

1. 检查目标路径、Git、Python 和 Rokit 工具。
2. 显示源模板 Commit、脏工作区状态和新项目唯一标识；脏模板默认停止。
3. 重新验证源模板的 Config、Luau 和 Rojo 构建。
4. 只复制明确允许的模板文件。
5. 不复制原项目的 `.git`、`.codex`、`.codegraph`、`codegraph.json`、缓存和构建产物。
6. 写入新的 Rojo 项目名、Remote 根目录名、ProfileStore 名和 README 标题。
7. 将新项目开发默认存储设置为 `Memory`，保证未发布的本地 Place 可以直接 Play。
8. 在新项目中重新创建 `.config-tools` 和 `ServerPackages`。
9. 在新项目中运行 Config 验证和模块基线验证。
10. 初始化独立的 `main` Git 仓库，不创建 Commit，不配置 Remote，不推送。
11. 输出 `NEW_PROJECT_OK`。

如果任一步失败，工具只清理带有本次唯一所有权标记的临时目录或目标目录；无法确认所有权时一律不删除。它不会触碰源模板或其他程序创建的同名目录，也不会留下一个假装成功的半成品项目。

## 自动验证生成器

框架维护者修改项目生成器后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Validate-ProjectTool.ps1
```

验证脚本会在系统临时目录中：

- 验证 `-WhatIf` 不创建文件。
- 验证脏模板在未传入 `-AllowDirty` 时停止且不创建目录。
- 实际生成一个临时项目。
- 检查项目唯一标识。
- 检查本地缓存没有被复制。
- 检查 Git 仓库独立、无 Commit、无 Remote。
- 验证目标目录冲突会停止。
- 模拟生成过程中外部创建同名目录，确认外部目录及保护文件不会被删除。
- 完成后删除它自己创建的临时测试目录。

看到 `PROJECT_TOOL_CHECK_OK` 表示项目生成器验收通过。

## 连接 Roblox Studio

进入新项目目录后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Serve-Rojo.ps1
```

默认端口是 `34872`。同时连接多个 Studio 项目时，为每个项目指定不同端口，例如：

```powershell
.\scripts\Serve-Rojo.ps1 -Port 34873
```

端口被占用时，脚本会显示占用进程，并提供停止旧 Rojo、输入其他端口或取消三种选择。只有占用者能确认是该端口的 Rojo serve 时才提供停止选项；其他程序占用时只能换端口或取消。自动化流程需要替换旧 Rojo 时，可以显式追加 `-StopExistingRojo`。

然后在 Roblox Studio 中：

1. 打开一个新的 Baseplate。
2. 使用 Rojo 插件连接脚本输出的端口，例如 `localhost:34872` 或 `localhost:34873`。
3. 确认资源管理器出现 Framework、Game、Module 和 Server 目录。
4. 点击 Play。
5. 确认 Output 没有框架启动错误。
6. 停止 Play 后再开始具体游戏开发。

Rojo 连接与 Play 属于 Studio 手动验收；自动化 `rojo build` 不能替代这一步。

## 切换正式持久化

新项目第一次本地 Play 使用 `MemoryStorage`，退出后数据不会保留。这样可以避免未发布 Place 因没有 DataStore 权限而在 ProfileStore 检查处中断。

准备验证正式存档时：

1. 发布到正确的 Roblox Experience。
2. 确认 `StorageConfig.ProfileStoreName` 仍是当前项目的唯一名称。
3. 在 `StorageConfig.lua` 中把 `StorageConfig.Backend` 从 `Memory` 改为 `ProfileStore`。
4. 按当前测试需要配置 Studio API 权限。
5. 重新 Play，验证保存、离开和重进读取。

不要为了消除本地报错而让两个不同项目共用一个 ProfileStore 名。

## 完成边界

新项目创建完成只代表：

- 开发环境独立。
- 项目标识唯一。
- Config 和框架底座通过检查。
- 可以连接 Studio 开始开发。

它不代表具体玩法、存档业务字段、UI、场景资源或正式发布已经完成。
