param(
    [ValidateSet("Error", "Warning", "Information", "Hint")]
    [string]$CheckLevel = "Warning"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$extensionsRoot = Join-Path $env:USERPROFILE ".vscode\extensions"

$luaServer = Get-ChildItem -Path $extensionsRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq "lua-language-server.exe" -and $_.FullName -match "sumneko\.lua" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1

if (-not $luaServer) {
    throw "Could not find Sumneko lua-language-server.exe under $extensionsRoot"
}

$kethoExtension = Get-ChildItem -Path $extensionsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "ketho.wow-api-*" } |
    Sort-Object Name -Descending |
    Select-Object -First 1

if (-not $kethoExtension) {
    throw "Could not find ketho.wow-api extension under $extensionsRoot"
}

$annotationsCore = Join-Path $kethoExtension.FullName "Annotations\Core"
$annotationsFrameXML = Join-Path $kethoExtension.FullName "Annotations\FrameXML"

if (-not (Test-Path -LiteralPath $annotationsCore)) {
    throw "Missing Ketho Core annotations: $annotationsCore"
}

if (-not (Test-Path -LiteralPath $annotationsFrameXML)) {
    throw "Missing Ketho FrameXML annotations: $annotationsFrameXML"
}

$outputRoot = Join-Path $repoRoot ".lua-language-server"
$configPath = Join-Path $outputRoot "check-config.lua"
$logPath = Join-Path $outputRoot "log"
$metaPath = Join-Path $outputRoot "meta"

New-Item -ItemType Directory -Path $outputRoot, $logPath, $metaPath -Force | Out-Null

function Convert-ToLuaString {
    param([Parameter(Mandatory = $true)][string]$Value)
    '"' + ($Value.Replace("\", "\\").Replace('"', '\"')) + '"'
}

$coreLua = Convert-ToLuaString $annotationsCore
$frameLua = Convert-ToLuaString $annotationsFrameXML

$config = @"
return {
    runtime = {
        version = "Lua 5.1",
        builtin = {
            basic = "disable",
            debug = "disable",
            io = "disable",
            math = "disable",
            os = "disable",
            package = "disable",
            string = "disable",
            table = "disable",
            utf8 = "disable",
        },
    },
    workspace = {
        library = {
            $coreLua,
            $frameLua,
        },
        ignoreDir = {
            ".vscode",
            "libs",
            ".lua-language-server",
            ".luals-check",
        },
    },
    diagnostics = {
        ignoredFiles = "Disable",
        globals = {
            "SlashCmdList",
            "ColorPickerFrame",
            "SOUNDKIT",
            "AddonCompartmentFrame",
            "BuffFrame",
            "DebuffFrame",
            "PanelTemplates_SetNumTabs",
            "PanelTemplates_UpdateTabs",
            "PanelTemplates_TabResize",
            "StaticPopupDialogs",
            "StaticPopup_Show",
            "PanelTemplates_SelectTab",
            "PanelTemplates_DeselectTab",
            "Settings",
            "STANDARD_TEXT_FONT",
            "PlayerFrame",
            "MinimalSliderWithSteppersMixin",
            "CreateMinimalSliderFormatter",
        },
        disable = {
            "assign-type-mismatch",
        },
    },
    type = {
        weakUnionCheck = true,
    },
}
"@

Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8

Write-Host "LuaLS:" $luaServer.FullName
Write-Host "Ketho:" $kethoExtension.FullName
Write-Host "Config:" $configPath
Write-Host ""

& $luaServer.FullName `
    --check="$repoRoot" `
    --configpath="$configPath" `
    --check_format=pretty `
    --checklevel="$CheckLevel" `
    --logpath="$logPath" `
    --metapath="$metaPath"

$exitCode = $LASTEXITCODE

Write-Host ""
Write-Host "Known Sound Levels note: Ketho may flag C_Sound.PlaySound(soundKitID, `"SFX`") as a string-channel param-type-mismatch even though in-game testing confirmed it works on this client."

exit $exitCode
