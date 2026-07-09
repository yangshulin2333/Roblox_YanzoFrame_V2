# Git 简化工作流

目标：把日常 Git 操作压缩成接近 SVN 的使用方式，同时保留 Git 的分支和远端能力。

## 第一次设置

在项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 setup
```

作用：

- 中文文件名不再显示成转义字符。
- 提交信息和日志输出使用 UTF-8。
- 只影响当前仓库，不修改全局 Git 配置。

## 日常使用

| 目标 | 命令 | 类似 SVN |
|---|---|---|
| 查看状态 | `powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 status` | 查看改动 |
| 更新远端代码 | `powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 update` | 更新 |
| 提交并推送 | `powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 save -Message "优化日志"` | 提交 |
| 提交并推送 | `powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 sync -Message "优化日志"` | 同步 |

## 推荐习惯

每次完成一个小目标后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Git-Simple.ps1 save -Message "一句话说明这次改了什么"
```

提交信息建议写成中文短句，例如：

- `优化启动日志`
- `补充 Git 简化脚本`
- `修复 StorageService 玩家数据关闭日志`

## 风险边界

- 脚本会执行 `git add -A`，也就是把当前仓库所有改动都加入提交。
- 如果有不想提交的临时文件，先用 `status` 检查。
- 如果远端和本地同时改了同一段内容，Git 仍可能要求处理冲突；这不是脚本能自动安全决定的内容。
