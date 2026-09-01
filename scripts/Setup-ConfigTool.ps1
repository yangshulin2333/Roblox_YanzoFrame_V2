param(
    [string]$PythonCommand = "python"
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvRoot = Join-Path $Root ".config-tools\venv"
$VenvPython = Join-Path $VenvRoot "Scripts\python.exe"
$Requirements = Join-Path $PSScriptRoot "config\requirements.txt"

Push-Location $Root
try {
    if (-not (Test-Path -LiteralPath $VenvPython)) {
        # 隔离 Excel 工具依赖，避免影响用户的全局 Python 环境。
        & $PythonCommand -m venv $VenvRoot
        if (-not $?) {
            throw "CONFIG_TOOL_VENV_CREATE_FAILED"
        }
    }

    & $VenvPython -m pip install --disable-pip-version-check -r $Requirements
    if (-not $?) {
        throw "CONFIG_TOOL_DEPENDENCY_INSTALL_FAILED"
    }

    Write-Host "CONFIG_TOOL_SETUP_OK"
} finally {
    Pop-Location
}
