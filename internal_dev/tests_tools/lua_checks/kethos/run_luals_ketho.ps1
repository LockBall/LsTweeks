param(
    [ValidateSet("Error", "Warning", "Information", "Hint")]
    [string]$CheckLevel = "Warning",
    [string[]]$Files,
    [switch]$Changed
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")
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

$luaChecksRoot = Join-Path $repoRoot "internal_dev\tests_tools\lua_checks"
$configTemplatePath = Join-Path $PSScriptRoot "check-config-template.lua"
$outputRoot = Join-Path $luaChecksRoot ".lua-language-server"
$configPath = Join-Path $outputRoot "check-config.lua"
$logPath = Join-Path $outputRoot "log"
$metaPath = Join-Path $outputRoot "meta"

if (-not (Test-Path -LiteralPath $configTemplatePath)) {
    throw "Missing LuaLS config template: $configTemplatePath"
}

New-Item -ItemType Directory -Path $outputRoot, $logPath, $metaPath -Force | Out-Null

function Convert-ToLuaString {
    param([Parameter(Mandatory = $true)][string]$Value)
    '"' + ($Value.Replace("\", "\\").Replace('"', '\"')) + '"'
}

function Convert-ToRepoRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    $rootPath = $repoRoot.Path.TrimEnd("\")
    if (-not $fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "File is outside repo root: $Path"
    }
    return $fullPath.Substring($rootPath.Length).TrimStart("\") -replace "\\", "/"
}

function Get-ChangedLuaFiles {
    $paths = @(
        git diff --name-only --diff-filter=ACMRTUXB
        git diff --cached --name-only --diff-filter=ACMRTUXB
        git ls-files --others --exclude-standard
    )

    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        $normalized = $path -replace "\\", "/"
        if ([System.IO.Path]::GetExtension($normalized) -ne ".lua") { continue }
        if (-not (Test-Path -LiteralPath $normalized)) { continue }
        $normalized
    }
}

function Resolve-CheckTargets {
    if ($Changed -and $Files.Count -gt 0) {
        throw "Use either -Changed or -Files, not both."
    }

    if ($Changed) {
        $changedFiles = @(Get-ChangedLuaFiles | Sort-Object -Unique)
        if ($changedFiles.Count -le 1) {
            return $changedFiles
        }
        $directories = foreach ($file in $changedFiles) {
            $directory = Split-Path -Parent $file
            if ([string]::IsNullOrWhiteSpace($directory)) {
                "."
            } else {
                $directory -replace "\\", "/"
            }
        }
        return @($directories | Sort-Object -Unique)
    }

    if ($Files.Count -gt 0) {
        $targets = foreach ($file in $Files) {
            if (-not (Test-Path -LiteralPath $file)) {
                throw "Check target does not exist: $file"
            }
            Convert-ToRepoRelativePath $file
        }
        return @($targets | Sort-Object -Unique)
    }

    return @($repoRoot.Path)
}

$coreLua = Convert-ToLuaString $annotationsCore
$frameLua = Convert-ToLuaString $annotationsFrameXML

$config = (Get-Content -LiteralPath $configTemplatePath -Raw).
    Replace("__KETHO_CORE__", $coreLua).
    Replace("__KETHO_FRAMEXML__", $frameLua)

Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8

Push-Location $repoRoot
try {
    Write-Host "LuaLS:" $luaServer.FullName
    Write-Host "Ketho:" $kethoExtension.FullName
    Write-Host "Config:" $configPath
    Write-Host ""

    $checkTargets = Resolve-CheckTargets
    if ($checkTargets.Count -eq 0) {
        Write-Host "No Lua files matched the requested targeted check."
        $exitCode = 0
    } else {
        $exitCode = 0
        foreach ($target in $checkTargets) {
            Write-Host "Check:" $target
            & $luaServer.FullName `
                --check="$target" `
                --configpath="$configPath" `
                --check_format=pretty `
                --checklevel="$CheckLevel" `
                --logpath="$logPath" `
                --metapath="$metaPath"

            if ($LASTEXITCODE -ne 0) {
                $exitCode = $LASTEXITCODE
            }
        }
    }

    if ($exitCode -ne 0) {
        Write-Host ""
        Write-Host "Known Audio Volumes note: Ketho may flag C_Sound.PlaySound(soundKitID, `"SFX`") as a string-channel param-type-mismatch even though in-game testing confirmed it works on this client. Verified Audio Volumes call sites should use narrow inline diagnostic suppressions."
    }
} finally {
    Pop-Location
}

exit $exitCode
