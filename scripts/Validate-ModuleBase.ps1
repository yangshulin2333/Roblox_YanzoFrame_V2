$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildPath = Join-Path ([System.IO.Path]::GetTempPath()) "YanzoFrame_V2_Base_Check.rbxlx"
Push-Location $Root

try {
    # 只使用 Rokit 安装的项目工具，避免 Windows PATH 意外命中 Cargo 或其他全局版本。
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

        Write-Host "[Validate-ModuleBase] 使用 Rokit 工具: ${ToolName} -> ${toolPath}"
        return $toolPath
    }

    $Wally = Get-RokitToolPath "wally"
    $Stylua = Get-RokitToolPath "stylua"
    $Selene = Get-RokitToolPath "selene"
    $Rojo = Get-RokitToolPath "rojo"

    $profileStorePath = "ServerPackages/_Index/lm-loleris_profilestore@1.0.3/profilestore/ProfileStore.luau"
    if (-not (Test-Path -LiteralPath $profileStorePath)) {
        & $Wally install
        if ($LASTEXITCODE -ne 0) {
            throw "Rokit Wally 安装依赖失败"
        }
    } else {
        Write-Host "[Validate-ModuleBase] 依赖已存在，跳过 wally install，避免中断正在运行的 Rojo。"
    }

    $requiredFiles = @(
        "default.project.json",
        "design/GameConfig.xlsx",
        "design/config-schema.json",
        "wally.toml",
        "wally.lock",
        $profileStorePath,
        "src/ServerScriptService/Server/Main.server.lua",
        "src/StarterPlayer/StarterPlayerScripts/Client/Main.client.lua",
        "src/ServerScriptService/Server/Framework/Runtime/ServiceRegistry.lua",
        "src/ServerScriptService/Server/Game/Runtime/GameServiceList.lua",
        "src/ServerScriptService/Server/Game/Config/Generated/ServerSettings.lua",
        "src/ReplicatedStorage/Game/Shared/Config/Generated/ExampleGroups.lua",
        "src/ReplicatedStorage/Game/Shared/Config/Generated/ExampleItems.lua",
        "src/StarterPlayer/StarterPlayerScripts/Client/Framework/Runtime/ControllerRegistry.lua",
        "src/StarterPlayer/StarterPlayerScripts/Client/Game/Runtime/GameControllerList.lua",
        "src/ServerScriptService/Server/Framework/Services/NetService.lua",
        "src/ServerScriptService/Server/Framework/Services/StorageService.lua",
        "src/ServerScriptService/Server/Framework/Storage/ProfileStoreStorage.lua",
        "src/ServerScriptService/Server/Framework/Services/PlayerSettingsService.lua",
        "src/ReplicatedStorage/Framework/Shared/Storage/MemoryStorage.lua",
        "src/ReplicatedStorage/Module/Shared/Config/LogConfig.lua",
        "src/ReplicatedStorage/Module/Shared/Config/StorageConfig.lua",
        "tests/UnitTest/RunUnitTest.lua",
        "tests/UnitTest/Cases/MemoryStorage_Test.lua",
        "tests/UnitTest/Cases/NetContracts_Test.lua",
        "tests/UnitTest/Cases/ProfileStoreStorage_Test.lua",
        "tests/UnitTest/Cases/StorageService_Test.lua",
        "tests/UnitTest/Cases/RuntimeRegistry_Test.lua",
        "tests/UnitTestRunner.server.lua"
    )

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            throw "Missing required file: $file"
        }
    }

    & $Stylua --check src tests
    if ($LASTEXITCODE -ne 0) {
        throw "Rokit StyLua 格式检查失败"
    }

    & $Selene src tests
    if ($LASTEXITCODE -ne 0) {
        throw "Rokit Selene 静态检查失败"
    }

    & $Rojo build default.project.json --output $buildPath
    if ($LASTEXITCODE -ne 0) {
        throw "Rokit Rojo 构建失败"
    }

    $buildContent = Get-Content -Raw $buildPath
    if ($buildContent -notmatch '<string name="Name">ProfileStore</string>') {
        throw "Rojo 构建中缺少 ProfileStore"
    }
    if ($buildContent -match '<string name="Name">_Index</string>') {
        throw "Wally 的 _Index 不能成为运行时依赖"
    }
    if ($buildContent -notmatch '<string name="Name">UnitTestRunner</string>[\s\S]{0,500}<bool name="Disabled">true</bool>') {
        throw "Rojo 构建中缺少默认禁用的 UnitTestRunner"
    }
    if ($buildContent -notmatch '<string name="Name">GameServiceList</string>') {
        throw "Rojo 构建中缺少 GameServiceList"
    }
    if ($buildContent -notmatch '<string name="Name">GameControllerList</string>') {
        throw "Rojo 构建中缺少 GameControllerList"
    }
    if ($buildContent -notmatch '<string name="Name">ExampleItems</string>') {
        throw "Rojo 构建中缺少 Shared Excel Config"
    }
    if ($buildContent -notmatch '<string name="Name">ServerSettings</string>') {
        throw "Rojo 构建中缺少 Server-only Excel Config"
    }

    Write-Host "MODULE_BASE_CHECK_OK"
} finally {
    Remove-Item -LiteralPath $buildPath -Force -ErrorAction SilentlyContinue
    Pop-Location
}
