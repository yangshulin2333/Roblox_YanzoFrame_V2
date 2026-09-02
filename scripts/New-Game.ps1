param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$GameName,

    [switch]$WhatIf,

    [switch]$Yes,

    [switch]$AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TemplateRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TemplateParent = Split-Path -Parent $TemplateRoot
$Generator = Join-Path $PSScriptRoot "New-YanzoProject.ps1"
$DisplayName = $GameName.Trim()

if ($DisplayName -notmatch "^[A-Za-z][A-Za-z0-9 _-]{0,29}$") {
    throw "GAME_NAME_INVALID: start with a letter; use letters, numbers, spaces, hyphens, or underscores; maximum 30 characters"
}

$ProjectName = [Regex]::Replace($DisplayName, "[ -]+", "_")
$ProjectName = [Regex]::Replace($ProjectName, "_+", "_").TrimEnd("_")
$Destination = Join-Path $TemplateParent $DisplayName
$RemoteRootName = "${ProjectName}_Remotes"
$ProfileStoreName = "${ProjectName}_PlayerData_V1"

Write-Host "New game project"
Write-Host "  DisplayName:  $DisplayName"
Write-Host "  ProjectName:  $ProjectName"
Write-Host "  Destination:  $Destination"
Write-Host "  RemoteRoot:   $RemoteRootName"
Write-Host "  ProfileStore: $ProfileStoreName"
Write-Host ""

$GeneratorArguments = @{
    ProjectName = $ProjectName
    Destination = $Destination
    RemoteRootName = $RemoteRootName
    ProfileStoreName = $ProfileStoreName
    AllowDirty = $AllowDirty
}

if ($WhatIf) {
    & $Generator @GeneratorArguments -WhatIf
    if (-not $?) {
        throw "NEW_GAME_PREVIEW_FAILED"
    }
    Write-Host "NEW_GAME_PREVIEW_OK"
    return
}

if (-not $Yes) {
    $Answer = Read-Host "Create this project? [Y/N] (default Y)"
    if (-not [string]::IsNullOrWhiteSpace($Answer) -and $Answer -notmatch "^(?i:y|yes)$") {
        Write-Host "NEW_GAME_CANCELLED"
        return
    }
}

& $Generator @GeneratorArguments -Confirm:$false

if (-not $?) {
    throw "NEW_GAME_CREATE_FAILED"
}

Write-Host "NEW_GAME_OK | DisplayName=$DisplayName | Project=$ProjectName | Path=$Destination"
