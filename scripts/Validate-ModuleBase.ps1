$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $Root

try {
    $requiredFiles = @(
        "default.project.json",
        "src/ServerScriptService/Server/Main.server.lua",
        "src/StarterPlayer/StarterPlayerScripts/Client/Main.client.lua",
        "src/ServerScriptService/Server/Framework/Runtime/ServiceRegistry.lua",
        "src/StarterPlayer/StarterPlayerScripts/Client/Framework/Runtime/ControllerRegistry.lua",
        "src/ServerScriptService/Server/Framework/Services/NetService.lua",
        "src/ServerScriptService/Server/Framework/Services/StorageService.lua",
        "src/ReplicatedStorage/Framework/Shared/Storage/MemoryStorage.lua",
        "src/ReplicatedStorage/Module/Shared/Config/LogConfig.lua",
        "src/ReplicatedStorage/Module/Shared/Config/StorageConfig.lua"
    )

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            throw "Missing required file: $file"
        }
    }

    if (Get-Command stylua -ErrorAction SilentlyContinue) {
        & stylua --check src
        if ($LASTEXITCODE -ne 0) {
            throw "stylua check failed"
        }
    } else {
        Write-Host "SKIP stylua: command not found"
    }

    if (Get-Command selene -ErrorAction SilentlyContinue) {
        & selene src
        if ($LASTEXITCODE -ne 0) {
            throw "selene check failed"
        }
    } else {
        Write-Host "SKIP selene: command not found"
    }

    if (Get-Command rojo -ErrorAction SilentlyContinue) {
        $buildPath = Join-Path ([System.IO.Path]::GetTempPath()) "YanzoFrame_V0_ModuleBase_Check.rbxlx"
        & rojo build default.project.json --output $buildPath
        if ($LASTEXITCODE -ne 0) {
            throw "rojo build failed"
        }
        Remove-Item -LiteralPath $buildPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "SKIP rojo: command not found"
    }

    Write-Host "MODULE_BASE_CHECK_OK"
} finally {
    Pop-Location
}
