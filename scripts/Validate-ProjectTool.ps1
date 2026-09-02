$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Generator = Join-Path $PSScriptRoot "New-YanzoProject.ps1"
$PowerShellExe = Join-Path $PSHOME "powershell.exe"
$TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("YanzoFrame_ProjectTool_Check_" + [Guid]::NewGuid().ToString("N"))
$ProjectName = "ProjectToolCheck"
$Destination = Join-Path $TestRoot $ProjectName
$PreviewDestination = Join-Path $TestRoot "PreviewOnly"
$DirtyDestination = Join-Path $TestRoot "DirtyRejected"
$RaceProjectName = "RaceCollision"
$RaceDestination = Join-Path $TestRoot $RaceProjectName
$RaceSentinel = Join-Path $RaceDestination "external-owner.txt"
$DirtyMarker = Join-Path $Root (".yanzo-project-tool-dirty-" + [Guid]::NewGuid().ToString("N"))
$ExpectedRemoteRoot = "ProjectToolCheck_Remotes"
$ExpectedProfileStore = "ProjectToolCheck_PlayerData_V1"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "PROJECT_TOOL_ASSERT_FAILED: $Message"
    }
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "PROJECT_TOOL_ASSERT_FAILED: $Message | Expected=$Expected | Actual=$Actual"
    }
}

$normalizedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$normalizedTestRoot = [System.IO.Path]::GetFullPath($TestRoot)
if (-not $normalizedTestRoot.StartsWith($normalizedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PROJECT_TOOL_TEMP_PATH_INVALID: $normalizedTestRoot"
}

New-Item -ItemType Directory -Path $TestRoot | Out-Null

try {
    Write-Host "[Validate-ProjectTool] 验证脏模板默认停止"
    New-Item -ItemType File -Path $DirtyMarker | Out-Null
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $dirtyOutput = & $PowerShellExe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $Generator `
            -ProjectName "DirtyRejected" `
            -Destination $DirtyDestination 2>&1
        $dirtyExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
        Remove-Item -LiteralPath $DirtyMarker -Force
    }
    Assert-True -Condition ($dirtyExitCode -ne 0) -Message "dirty source was not rejected"
    Assert-True `
        -Condition (($dirtyOutput -join "`n") -match "PROJECT_SOURCE_DIRTY") `
        -Message "dirty source error code missing"
    Assert-True `
        -Condition (-not (Test-Path -LiteralPath $DirtyDestination)) `
        -Message "dirty source created destination"

    Write-Host "[Validate-ProjectTool] 验证 WhatIf 不创建文件"
    & $PowerShellExe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $Generator `
        -ProjectName "PreviewOnly" `
        -Destination $PreviewDestination `
        -AllowDirty `
        -WhatIf
    Assert-Equal -Actual $LASTEXITCODE -Expected 0 -Message "WhatIf command failed"
    Assert-True -Condition (-not (Test-Path -LiteralPath $PreviewDestination)) -Message "WhatIf created destination"

    Write-Host "[Validate-ProjectTool] 验证运行中出现的目标目录不会被删除"
    $raceCreatorJob = Start-Job -ScriptBlock {
        param(
            [string]$ParentPath,
            [string]$DestinationLeaf,
            [string]$DestinationPath,
            [string]$SentinelPath
        )

        $stagePattern = ".${DestinationLeaf}.yanzo-stage-*"
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ([DateTime]::UtcNow -lt $deadline) {
            $stage = Get-ChildItem -LiteralPath $ParentPath -Directory -Filter $stagePattern -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($null -ne $stage) {
                New-Item -ItemType Directory -Path $DestinationPath | Out-Null
                [System.IO.File]::WriteAllText($SentinelPath, "external owner")
                return "RACE_DESTINATION_CREATED"
            }
            Start-Sleep -Milliseconds 10
        }

        throw "RACE_STAGE_WAIT_TIMEOUT"
    } -ArgumentList $TestRoot, $RaceProjectName, $RaceDestination, $RaceSentinel

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $raceOutput = & $PowerShellExe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $Generator `
            -ProjectName $RaceProjectName `
            -Destination $RaceDestination `
            -AllowDirty 2>&1
        $raceExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
        $raceJobCompleted = Wait-Job -Job $raceCreatorJob -Timeout 35
        if ($null -eq $raceJobCompleted) {
            Stop-Job -Job $raceCreatorJob
        }
        $raceJobOutput = @(Receive-Job -Job $raceCreatorJob)
        Remove-Job -Job $raceCreatorJob -Force
    }

    Assert-True `
        -Condition (($raceJobOutput -join "`n") -match "RACE_DESTINATION_CREATED") `
        -Message "race destination creator did not run"
    Assert-True -Condition ($raceExitCode -ne 0) -Message "race collision was not rejected"
    Assert-True `
        -Condition (Test-Path -LiteralPath $RaceDestination -PathType Container) `
        -Message "external race destination was deleted"
    Assert-True `
        -Condition (Test-Path -LiteralPath $RaceSentinel -PathType Leaf) `
        -Message "external race sentinel was deleted"
    $nestedRaceStages = @(
        Get-ChildItem -LiteralPath $RaceDestination -Directory -Filter ".${RaceProjectName}.yanzo-stage-*" -ErrorAction SilentlyContinue
    )
    Assert-Equal -Actual $nestedRaceStages.Count -Expected 0 -Message "staging directory was merged into external destination"
    Assert-True `
        -Condition (($raceOutput -join "`n") -match "PROJECT_DESTINATION_EXISTS") `
        -Message "race collision error code missing"

    Write-Host "[Validate-ProjectTool] 创建并完整验证临时项目"
    & $PowerShellExe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $Generator `
        -ProjectName $ProjectName `
        -Destination $Destination `
        -AllowDirty
    Assert-Equal -Actual $LASTEXITCODE -Expected 0 -Message "generator failed"
    Assert-True -Condition (Test-Path -LiteralPath $Destination -PathType Container) -Message "destination missing"

    $project = Get-Content -LiteralPath (Join-Path $Destination "default.project.json") -Raw | ConvertFrom-Json
    Assert-Equal -Actual $project.name -Expected $ProjectName -Message "Rojo project name mismatch"

    $remoteNames = Get-Content -LiteralPath (Join-Path $Destination "src\ReplicatedStorage\Framework\Shared\Net\RemoteNames.lua") -Raw
    Assert-True `
        -Condition ($remoteNames -match ('RootFolder\s*=\s*"' + [Regex]::Escape($ExpectedRemoteRoot) + '"')) `
        -Message "Remote root mismatch"

    $storageConfig = Get-Content -LiteralPath (Join-Path $Destination "src\ReplicatedStorage\Module\Shared\Config\StorageConfig.lua") -Raw
    Assert-True `
        -Condition ($storageConfig -match 'StorageConfig\.Backend\s*=\s*"Memory"') `
        -Message "new project development backend is not Memory"
    Assert-True `
        -Condition ($storageConfig -match ('ProfileStoreName\s*=\s*"' + [Regex]::Escape($ExpectedProfileStore) + '"')) `
        -Message "ProfileStore name mismatch"

    $readmeFirstLine = Get-Content -LiteralPath (Join-Path $Destination "README.md") -TotalCount 1
    Assert-Equal -Actual $readmeFirstLine -Expected "# $ProjectName" -Message "README title mismatch"

    foreach ($requiredPath in @(
        "design\config\workbooks\GameConfig.xlsx",
        "src\ReplicatedStorage\Game\Shared\Config\Generated\ExampleGroups.lua",
        "src\ReplicatedStorage\Game\Shared\Config\Generated\ExampleItems.lua",
        "src\ServerScriptService\Server\Game\Config\Generated\ServerSettings.lua",
        ".config-tools\venv\Scripts\python.exe",
        "ServerPackages\_Index\lm-loleris_profilestore@1.0.3\profilestore\ProfileStore.luau",
        ".git"
    )) {
        Assert-True `
            -Condition (Test-Path -LiteralPath (Join-Path $Destination $requiredPath)) `
            -Message "required generated project path missing: $requiredPath"
    }

    foreach ($excludedPath in @(
        ".yanzo-project-owner",
        ".codex",
        ".codegraph",
        "codegraph.json",
        "sourcemap.json"
    )) {
        Assert-True `
            -Condition (-not (Test-Path -LiteralPath (Join-Path $Destination $excludedPath))) `
            -Message "local template state was copied: $excludedPath"
    }

    $gitRoot = (& git -C $Destination rev-parse --show-toplevel).Trim()
    $normalizedGitRoot = [System.IO.Path]::GetFullPath($gitRoot.Replace('/', '\')).TrimEnd('\')
    $normalizedDestination = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\')
    Assert-Equal -Actual $normalizedGitRoot -Expected $normalizedDestination -Message "Git repository is not independent"
    $gitRemotes = @(& git -C $Destination remote)
    Assert-Equal -Actual $gitRemotes.Count -Expected 0 -Message "generated project has a Git remote"
    $commitCountText = (& git -C $Destination rev-list --all --count 2>$null | Select-Object -First 1)
    $commitCount = if ([string]::IsNullOrWhiteSpace($commitCountText)) { 0 } else { [int]$commitCountText }
    Assert-Equal -Actual $commitCount -Expected 0 -Message "generated project created an automatic commit"

    Write-Host "[Validate-ProjectTool] 验证目标冲突会停止"
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $collisionOutput = & $PowerShellExe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $Generator `
            -ProjectName $ProjectName `
            -Destination $Destination `
            -AllowDirty 2>&1
        $collisionExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    Assert-True -Condition ($collisionExitCode -ne 0) -Message "existing destination was not rejected"
    Assert-True `
        -Condition (($collisionOutput -join "`n") -match "PROJECT_DESTINATION_EXISTS") `
        -Message "collision error code missing"

    Write-Host "PROJECT_TOOL_CHECK_OK"
} finally {
    if (Test-Path -LiteralPath $DirtyMarker) {
        Remove-Item -LiteralPath $DirtyMarker -Force
    }
    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force
    }
}
