$ErrorActionPreference = "Stop"

$Utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $Utf8
$OutputEncoding = $Utf8
$env:PYTHONUTF8 = "1"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Python = Join-Path $Root ".config-tools\venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $Python)) {
    throw "CONFIG_TOOL_NOT_INSTALLED: run scripts\Setup-ConfigTool.ps1 first"
}

Push-Location $Root
try {
    & $Python -m unittest discover -s "tests\ConfigTool" -p "test_*.py" -v
    if (-not $?) {
        throw "CONFIG_TOOL_TEST_FAILED"
    }

    & (Join-Path $PSScriptRoot "Import-GameConfig.ps1") -Check
    if (-not $?) {
        throw "CONFIG_OUTPUT_CHECK_FAILED"
    }

    Write-Host "CONFIG_TOOL_CHECK_OK"
} finally {
    Pop-Location
}
