param(
    [ValidateSet("status", "update", "save", "sync", "setup", "help")]
    [string]$Action = "help",

    [string]$Message = ""
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Write-Step {
    param([string]$Text)
    Write-Host "[Git简化] $Text"
}

function Invoke-Git {
    param([string[]]$Arguments)

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git 命令失败：git $($Arguments -join ' ')"
    }
}

function Get-CurrentBranch {
    $branch = (& git branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "当前不在普通分支上，无法自动推送。"
    }

    return $branch
}

function Get-Upstream {
    $upstream = & git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        return ""
    }

    return ($upstream -join "").Trim()
}

function Get-HasChanges {
    $status = & git status --porcelain
    return $null -ne $status
}

function Push-CurrentBranch {
    $branch = Get-CurrentBranch
    $upstream = Get-Upstream

    if ([string]::IsNullOrWhiteSpace($upstream)) {
        Write-Step "第一次推送当前分支：$branch"
        Invoke-Git @("push", "-u", "origin", $branch)
        return
    }

    Write-Step "推送到远端：$upstream"
    Invoke-Git @("push")
}

function Save-And-Push {
    param([string]$CommitMessage)

    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        $CommitMessage = "保存：$(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    }

    if (Get-HasChanges) {
        Write-Step "加入所有改动"
        Invoke-Git @("add", "-A")

        Write-Step "提交：$CommitMessage"
        Invoke-Git @("commit", "-m", $CommitMessage)
    } else {
        Write-Step "没有需要提交的本地改动"
    }

    if (-not [string]::IsNullOrWhiteSpace((Get-Upstream))) {
        Write-Step "同步远端提交，避免推送被拒绝"
        Invoke-Git @("pull", "--rebase", "--autostash")
    }

    Push-CurrentBranch
    Write-Step "完成"
}

function Show-Help {
    Write-Host @"
YanzoFrame_V1_StorageModule Git 简化脚本

常用命令：
  .\scripts\Git-Simple.ps1 setup
      一次性设置当前仓库的中文文件名和 UTF-8 显示。

  .\scripts\Git-Simple.ps1 status
      查看当前分支和文件变化。

  .\scripts\Git-Simple.ps1 update
      类似 SVN 更新：只从远端拉取，不提交本地改动。

  .\scripts\Git-Simple.ps1 save -Message "优化日志"
      类似 SVN 提交：加入全部改动、提交、同步远端、推送。

  .\scripts\Git-Simple.ps1 sync -Message "优化日志"
      等同于 save，保留这个名字方便理解。
"@
}

Push-Location $Root
try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "没有找到 git 命令，请先安装 Git for Windows。"
    }

    switch ($Action) {
        "setup" {
            Write-Step "设置当前仓库的中文文件名和 UTF-8 显示"
            Invoke-Git @("config", "core.quotepath", "false")
            Invoke-Git @("config", "i18n.commitEncoding", "utf-8")
            Invoke-Git @("config", "i18n.logOutputEncoding", "utf-8")
            Write-Step "完成"
        }
        "status" {
            Write-Step "当前分支：$(Get-CurrentBranch)"
            Invoke-Git @("status", "--short", "--branch")
        }
        "update" {
            Write-Step "从远端更新当前分支"
            Invoke-Git @("pull", "--ff-only", "--autostash")
            Write-Step "完成"
        }
        "save" {
            Save-And-Push -CommitMessage $Message
        }
        "sync" {
            Save-And-Push -CommitMessage $Message
        }
        default {
            Show-Help
        }
    }
} catch {
    Write-Host "[Git简化] 失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "如果提示冲突，先解决冲突后运行 git rebase --continue；不确定时把错误发给 Codex 处理。"
    exit 1
} finally {
    Pop-Location
}

