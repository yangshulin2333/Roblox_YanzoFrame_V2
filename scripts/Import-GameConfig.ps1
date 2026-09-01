param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$Utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $Utf8
$OutputEncoding = $Utf8
$env:PYTHONUTF8 = "1"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Python = Join-Path $Root ".config-tools\venv\Scripts\python.exe"
$Importer = Join-Path $PSScriptRoot "config\import_config.py"
$Workbook = Join-Path $Root "design\GameConfig.xlsx"
$Schema = Join-Path $Root "design\config-schema.json"

if (-not (Test-Path -LiteralPath $Python)) {
    throw "CONFIG_TOOL_NOT_INSTALLED: run scripts\Setup-ConfigTool.ps1 first"
}

# 所有校验通过后，Python 工具才会替换 Generated 目录。
$PythonArguments = @(
    $Importer,
    "--repo-root", $Root,
    "--workbook", $Workbook,
    "--schema", $Schema
)
if ($Check) {
    $PythonArguments += "--check"
}
& $Python @PythonArguments
if (-not $?) {
    throw "CONFIG_IMPORT_FAILED"
}
