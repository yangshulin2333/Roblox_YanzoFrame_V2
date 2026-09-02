[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z][A-Za-z0-9_]{0,29}$")]
    [string]$ProjectName,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [ValidatePattern("^[A-Za-z][A-Za-z0-9_-]{0,79}$")]
    [string]$RemoteRootName = "",

    [ValidatePattern("^[A-Za-z][A-Za-z0-9_-]{0,49}$")]
    [string]$ProfileStoreName = "",

    [switch]$AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Write-Step {
    param([string]$Text)
    Write-Host "[New-YanzoProject] $Text"
}

function Get-FullUnresolvedPath {
    param([string]$Path)

    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Assert-RequiredPath {
    param([string]$RelativePath)

    $fullPath = Join-Path $SourceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "PROJECT_TEMPLATE_MISSING: $RelativePath"
    }
}

function Write-Utf8Text {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Set-LuaStringValue {
    param(
        [string]$Path,
        [string]$Key,
        [string]$Value
    )

    $content = [System.IO.File]::ReadAllText($Path)
    $pattern = '(?m)^(\s*' + [Regex]::Escape($Key) + '\s*=\s*)"[^"]*"'
    $regex = New-Object System.Text.RegularExpressions.Regex($pattern)
    $matches = $regex.Matches($content)
    if ($matches.Count -ne 1) {
        throw "PROJECT_TEMPLATE_REPLACE_FAILED: $Key in $Path"
    }

    $updated = $regex.Replace(
        $content,
        { param($match) $match.Groups[1].Value + '"' + $Value + '"' },
        1
    )
    Write-Utf8Text -Path $Path -Content $updated
}

function Set-ProjectIdentity {
    param([string]$ProjectRoot)

    $projectFile = Join-Path $ProjectRoot "default.project.json"
    $project = Get-Content -LiteralPath $projectFile -Raw | ConvertFrom-Json
    $project.name = $ProjectName
    Write-Utf8Text -Path $projectFile -Content (($project | ConvertTo-Json -Depth 100) + "`n")

    Set-LuaStringValue `
        -Path (Join-Path $ProjectRoot "src\ReplicatedStorage\Framework\Shared\Net\RemoteNames.lua") `
        -Key "RootFolder" `
        -Value $RemoteRootName

    Set-LuaStringValue `
        -Path (Join-Path $ProjectRoot "src\ReplicatedStorage\Module\Shared\Config\StorageConfig.lua") `
        -Key "StorageConfig.Backend" `
        -Value "Memory"

    Set-LuaStringValue `
        -Path (Join-Path $ProjectRoot "src\ReplicatedStorage\Module\Shared\Config\StorageConfig.lua") `
        -Key "StorageConfig.ProfileStoreName" `
        -Value $ProfileStoreName

    $readmePath = Join-Path $ProjectRoot "README.md"
    $readme = [System.IO.File]::ReadAllText($readmePath)
    $headingPattern = New-Object System.Text.RegularExpressions.Regex("(?m)^# .+$")
    if ($headingPattern.Matches($readme).Count -lt 1) {
        throw "PROJECT_TEMPLATE_REPLACE_FAILED: README heading"
    }
    $readme = $headingPattern.Replace($readme, "# $ProjectName", 1)
    Write-Utf8Text -Path $readmePath -Content $readme
}

function Copy-TemplateEntry {
    param(
        [string]$RelativePath,
        [string]$TargetRoot
    )

    $sourcePath = Join-Path $SourceRoot $RelativePath
    $targetPath = Join-Path $TargetRoot $RelativePath

    if (Test-Path -LiteralPath $sourcePath -PathType Container) {
        New-Item -ItemType Directory -Path $targetPath | Out-Null
        Get-ChildItem -LiteralPath $sourcePath -Force | Copy-Item -Destination $targetPath -Recurse -Force
        return
    }

    $targetParent = Split-Path -Parent $targetPath
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent | Out-Null
    }
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
}

function Invoke-PowerShellCheck {
    param(
        [string]$ScriptPath,
        [string]$ErrorCode
    )

    & $ScriptPath
    if (-not $?) {
        throw $ErrorCode
    }
}

function Initialize-GeneratedProject {
    param(
        [string]$ProjectRoot,
        [string]$GitPath,
        [string]$PythonPath,
        [string]$RokitToolRoot
    )

    Push-Location $ProjectRoot
    try {
        Write-Step "安装 Excel Config 工具"
        & (Join-Path $ProjectRoot "scripts\Setup-ConfigTool.ps1") -PythonCommand $PythonPath
        if (-not $?) {
            throw "PROJECT_CONFIG_SETUP_FAILED"
        }

        Write-Step "安装 Wally 依赖"
        & (Join-Path $RokitToolRoot "wally.exe") install
        if ($LASTEXITCODE -ne 0) {
            throw "PROJECT_WALLY_INSTALL_FAILED"
        }

        Write-Step "验证新项目 Config"
        Invoke-PowerShellCheck `
            -ScriptPath (Join-Path $ProjectRoot "scripts\Validate-ConfigTool.ps1") `
            -ErrorCode "PROJECT_CONFIG_CHECK_FAILED"

        Write-Step "验证新项目框架与 Rojo 构建"
        Invoke-PowerShellCheck `
            -ScriptPath (Join-Path $ProjectRoot "scripts\Validate-ModuleBase.ps1") `
            -ErrorCode "PROJECT_MODULE_CHECK_FAILED"

        Write-Step "初始化独立 Git 仓库"
        & $GitPath init -b main
        if ($LASTEXITCODE -ne 0) {
            throw "PROJECT_GIT_INIT_FAILED"
        }
    } finally {
        Pop-Location
    }
}

if ([string]::IsNullOrWhiteSpace($RemoteRootName)) {
    $RemoteRootName = "${ProjectName}_Remotes"
}
if ([string]::IsNullOrWhiteSpace($ProfileStoreName)) {
    $ProfileStoreName = "${ProjectName}_PlayerData_V1"
}

if ($RemoteRootName.Length -gt 80) {
    throw "PROJECT_REMOTE_NAME_TOO_LONG: maximum 80 characters"
}
if ($ProfileStoreName.Length -gt 50) {
    throw "PROJECT_STORE_NAME_TOO_LONG: maximum 50 characters"
}

$DestinationPath = Get-FullUnresolvedPath $Destination
$DestinationParent = Split-Path -Parent $DestinationPath
$DestinationLeaf = Split-Path -Leaf $DestinationPath

if ([string]::IsNullOrWhiteSpace($DestinationLeaf)) {
    throw "PROJECT_DESTINATION_INVALID: target folder name is empty"
}
if (-not (Test-Path -LiteralPath $DestinationParent -PathType Container)) {
    throw "PROJECT_DESTINATION_PARENT_MISSING: $DestinationParent"
}
if (Test-Path -LiteralPath $DestinationPath) {
    throw "PROJECT_DESTINATION_EXISTS: $DestinationPath"
}

$sourcePrefix = $SourceRoot.TrimEnd('\') + '\'
if ($DestinationPath.Equals($SourceRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    $DestinationPath.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PROJECT_DESTINATION_INSIDE_TEMPLATE: $DestinationPath"
}

$TemplateEntries = @(
    ".gitattributes",
    ".gitignore",
    "AGENTS.md",
    "README.md",
    "default.project.json",
    "design",
    "docs",
    "rokit.toml",
    "scripts",
    "selene.toml",
    "src",
    "stylua.toml",
    "tests",
    "wally.lock",
    "wally.toml"
)

foreach ($entry in $TemplateEntries) {
    Assert-RequiredPath $entry
}

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $gitCommand) {
    throw "PROJECT_GIT_NOT_FOUND"
}
$GitPath = $gitCommand.Source
$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
    throw "PROJECT_PYTHON_NOT_FOUND"
}
$PythonPath = $pythonCommand.Source

$RokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
foreach ($toolName in @("wally", "stylua", "selene", "rojo")) {
    $toolPath = Join-Path $RokitBin ($toolName + ".exe")
    if (-not (Test-Path -LiteralPath $toolPath)) {
        throw "PROJECT_ROKIT_TOOL_MISSING: $toolPath"
    }
}

$sourceCommit = (& $GitPath -C $SourceRoot rev-parse --short HEAD 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($sourceCommit)) {
    $sourceCommit = "NO_COMMIT"
}
$sourceStatus = @(& $GitPath -C $SourceRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw "PROJECT_SOURCE_STATUS_FAILED"
}
$sourceDirty = $sourceStatus.Count -gt 0

Write-Host ""
Write-Host "新项目创建预览"
Write-Host "  Template:     $SourceRoot"
Write-Host "  Commit:       $sourceCommit"
Write-Host "  SourceDirty:  $sourceDirty"
Write-Host "  AllowDirty:   $($AllowDirty.IsPresent)"
Write-Host "  ProjectName:  $ProjectName"
Write-Host "  Destination:  $DestinationPath"
Write-Host "  RemoteRoot:   $RemoteRootName"
Write-Host "  ProfileStore: $ProfileStoreName"
Write-Host ""

if ($sourceDirty -and -not $AllowDirty) {
    throw "PROJECT_SOURCE_DIRTY: commit or remove source changes, or explicitly use -AllowDirty"
}

if (-not $PSCmdlet.ShouldProcess($DestinationPath, "创建并验证独立 YanzoFrame 项目")) {
    Write-Host "NEW_PROJECT_PREVIEW_OK"
    return
}

$StageRoot = Join-Path $DestinationParent ("." + $DestinationLeaf + ".yanzo-stage-" + [Guid]::NewGuid().ToString("N"))
$DestinationCreatedByScript = $false

try {
    Write-Step "验证源模板"
    Invoke-PowerShellCheck `
        -ScriptPath (Join-Path $SourceRoot "scripts\Validate-ConfigTool.ps1") `
        -ErrorCode "PROJECT_SOURCE_CONFIG_CHECK_FAILED"
    Invoke-PowerShellCheck `
        -ScriptPath (Join-Path $SourceRoot "scripts\Validate-ModuleBase.ps1") `
        -ErrorCode "PROJECT_SOURCE_MODULE_CHECK_FAILED"

    Write-Step "复制允许的模板文件"
    New-Item -ItemType Directory -Path $StageRoot | Out-Null
    foreach ($entry in $TemplateEntries) {
        Copy-TemplateEntry -RelativePath $entry -TargetRoot $StageRoot
    }

    Write-Step "写入项目唯一标识"
    Set-ProjectIdentity -ProjectRoot $StageRoot

    Write-Step "形成最终项目目录"
    Move-Item -LiteralPath $StageRoot -Destination $DestinationPath
    $DestinationCreatedByScript = $true

    Initialize-GeneratedProject `
        -ProjectRoot $DestinationPath `
        -GitPath $GitPath `
        -PythonPath $PythonPath `
        -RokitToolRoot $RokitBin

    Write-Host "NEW_PROJECT_OK | Project=$ProjectName | Path=$DestinationPath"
} catch {
    $message = $_.Exception.Message

    if (Test-Path -LiteralPath $StageRoot) {
        Remove-Item -LiteralPath $StageRoot -Recurse -Force
    }
    if ($DestinationCreatedByScript -and (Test-Path -LiteralPath $DestinationPath)) {
        Remove-Item -LiteralPath $DestinationPath -Recurse -Force
    }

    throw "NEW_PROJECT_FAILED: $message"
}
