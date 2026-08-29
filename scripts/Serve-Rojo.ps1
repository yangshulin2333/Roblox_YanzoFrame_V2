$ErrorActionPreference = "Stop"

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

    $Wally = Get-RokitToolPath "wally"
    $Rojo = Get-RokitToolPath "rojo"

    # ServerPackages 被 .gitignore 排除，每次开工都要先重新生成，否则 rojo serve 会因为
    # default.project.json 里指向 ServerPackages 的 $path 找不到文件而直接报错退出。
    & $Wally install
    if ($LASTEXITCODE -ne 0) {
        throw "Rokit Wally 安装依赖失败"
    }

    & $Rojo serve default.project.json --address 127.0.0.1 --port 34872
} finally {
    Pop-Location
}
