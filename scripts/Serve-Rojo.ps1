[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 34872,

    [switch]$StopExistingRojo
)

$ErrorActionPreference = "Stop"
$StartCancelled = $false

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $Root

try {
    # 只使用 Rokit 安装的项目工具，避免 Windows PATH 意外命中其他全局版本（例如 WinGet 装的 rojo）。
    $RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"

    function Get-RokitToolPath {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ToolName
        )

        $toolPath = Join-Path $RokitBin ($ToolName + ".exe")
        if (-not (Test-Path -LiteralPath $toolPath)) {
            throw "未找到 Rokit 工具 ${ToolName}: ${toolPath}。请先在项目根目录执行 rokit install。"
        }

        Write-Host "[Serve-Rojo] 使用 Rokit 工具: ${ToolName} -> ${toolPath}"
        return $toolPath
    }

    function Get-PortOwners {
        $processIds = @(
            Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty OwningProcess -Unique
        )

        $owners = @()
        foreach ($processId in $processIds) {
            $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
            $owners += [pscustomobject]@{
                ProcessId = $processId
                Name = if ($null -eq $process) { "<exited>" } else { $process.Name }
                CommandLine = if ($null -eq $process) { "" } else { [string]$process.CommandLine }
            }
        }

        return $owners
    }

    function Assert-RojoPortAvailable {
        while ($true) {
            $owners = @(Get-PortOwners)
            if ($owners.Count -eq 0) {
                return
            }

            $summary = ($owners | ForEach-Object { "PID=$($_.ProcessId), Process=$($_.Name)" }) -join "; "
            $escapedPort = [Regex]::Escape($Port.ToString())
            $allOwnersAreRojo = $true

            foreach ($owner in $owners) {
                $isRojoServe = $owner.Name -ieq "rojo.exe" -and
                    $owner.CommandLine -match "(?i)(^|\s)serve(\s|$)" -and
                    $owner.CommandLine -match ("(?i)(^|\s)--port(?:\s+|=)" + $escapedPort + "(\s|$)")

                if (-not $isRojoServe) {
                    $allOwnersAreRojo = $false
                }
            }

            Write-Host "[Serve-Rojo] 端口被占用: 127.0.0.1:$Port | $summary"

            $shouldStop = $StopExistingRojo
            if (-not $StopExistingRojo) {
                if ($allOwnersAreRojo) {
                    $choice = Read-Host "选择：[S] 停止旧 Rojo并使用此端口  [P] 输入其他端口  [C] 取消（默认 C）"
                } else {
                    Write-Host "[Serve-Rojo] 占用者不是可确认的 Rojo serve，出于安全考虑不会提供终止选项。"
                    $choice = Read-Host "选择：[P] 输入其他端口  [C] 取消（默认 C）"
                }

                if ($choice -match "^(?i:p|port)$") {
                    $portText = Read-Host "请输入新端口（1-65535）"
                    $newPort = 0
                    if (-not [int]::TryParse($portText, [ref]$newPort) -or $newPort -lt 1 -or $newPort -gt 65535) {
                        Write-Host "[Serve-Rojo] 端口无效，请重新选择。"
                        continue
                    }

                    $script:Port = $newPort
                    continue
                }

                if ($choice -match "^(?i:s|stop|y|yes)$" -and $allOwnersAreRojo) {
                    $shouldStop = $true
                } else {
                    $script:StartCancelled = $true
                    return
                }
            }

            if (-not $allOwnersAreRojo) {
                throw "ROJO_PORT_OWNER_UNSAFE: 127.0.0.1:$Port | $summary | 占用者不是可确认的 Rojo serve，拒绝终止"
            }

            if ($shouldStop) {
                foreach ($owner in $owners) {
                    Write-Host "[Serve-Rojo] 停止旧 Rojo: Port=$Port PID=$($owner.ProcessId)"
                    Stop-Process -Id $owner.ProcessId -Force
                }

                $deadline = [DateTime]::UtcNow.AddSeconds(5)
                while (@(Get-PortOwners).Count -gt 0) {
                    if ([DateTime]::UtcNow -ge $deadline) {
                        throw "ROJO_PORT_RELEASE_TIMEOUT: 127.0.0.1:$Port"
                    }
                    Start-Sleep -Milliseconds 100
                }

                return
            }
        }
    }

    $Wally = Get-RokitToolPath "wally"
    $Rojo = Get-RokitToolPath "rojo"

    Assert-RojoPortAvailable
    if ($StartCancelled) {
        Write-Host "[Serve-Rojo] 已取消，未启动服务。"
        return
    }

    # ServerPackages 被 .gitignore 排除，每次开工都要先重新生成，否则 rojo serve 会因为
    # default.project.json 里指向 ServerPackages 的 $path 找不到文件而直接报错退出。
    & $Wally install
    if ($LASTEXITCODE -ne 0) {
        throw "Rokit Wally 安装依赖失败"
    }

    Write-Host "[Serve-Rojo] 启动服务: 127.0.0.1:$Port"
    & $Rojo serve default.project.json --address 127.0.0.1 --port $Port
} finally {
    Pop-Location
}
