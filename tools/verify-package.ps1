param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ZipPath
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$policyPath = Join-Path $PSScriptRoot "package-policy.json"

function Get-AddonToc {
    $tocFiles = @(Get-ChildItem -LiteralPath $repoRoot -File -Filter "*.toc")
    if ($tocFiles.Count -eq 0) {
        throw "Missing root TOC file."
    }
    if ($tocFiles.Count -gt 1) {
        throw "Expected exactly one root TOC file, found: $($tocFiles.Name -join ', ')"
    }
    return $tocFiles[0]
}

$tocFile = Get-AddonToc
$addonName = [System.IO.Path]::GetFileNameWithoutExtension($tocFile.Name)

$invariantRequiredFiles = @(
    $tocFile.Name,
    "README.md",
    "LICENSE",
    "sources.md"
)

$invariantRequiredRoots = @(
    "core",
    "functions",
    "libs",
    "media",
    "modules"
)

$invariantForbiddenRoots = @(
    ".git",
    ".github",
    ".venv",
    ".vscode",
    "dist",
    "tools",
    "working_docs"
)

if (-not (Test-Path -LiteralPath $policyPath)) {
    throw "Missing package policy file: $policyPath"
}

if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "Missing package zip: $ZipPath"
}

$resolvedZipPath = (Resolve-Path -LiteralPath $ZipPath).Path
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$policyIncludeFiles = @($policy.includeFiles | ForEach-Object {
    if ($_ -eq "<toc>") { $tocFile.Name } else { $_ }
})
$errors = New-Object System.Collections.Generic.List[string]

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedZipPath)

try {
    $entries = @($zip.Entries | Where-Object { $_.FullName -and -not $_.FullName.EndsWith("/") })
    $entryNames = @($entries | ForEach-Object { $_.FullName.Replace("/", "\") })
    $entrySet = @{}
    foreach ($name in $entryNames) {
        $entrySet[$name.ToLowerInvariant()] = $true
    }

    if ($entryNames.Count -eq 0) {
        $errors.Add("Zip contains no file entries.")
    }

    $topLevels = @(
        $entryNames |
            ForEach-Object { ($_ -split "\\")[0] } |
            Sort-Object -Unique
    )

    if ($topLevels.Count -ne 1 -or $topLevels[0] -ne $addonName) {
        $errors.Add("Zip must contain exactly one top-level '$addonName' folder. Found: $($topLevels -join ', ')")
    }

    foreach ($name in $entryNames) {
        if ($name -match '(^|\\)\.\.(\\|$)') {
            $errors.Add("Unsafe parent traversal path: $name")
        }
        if ([System.IO.Path]::IsPathRooted($name)) {
            $errors.Add("Unsafe rooted path: $name")
        }
    }

    foreach ($file in $policyIncludeFiles) {
        $expected = "$addonName\$file"
        if (-not $entrySet.ContainsKey($expected.ToLowerInvariant())) {
            $errors.Add("Missing required file: $expected")
        }
    }

    foreach ($file in $invariantRequiredFiles) {
        $expected = "$addonName\$file"
        if (-not $entrySet.ContainsKey($expected.ToLowerInvariant())) {
            $errors.Add("Missing invariant required file: $expected")
        }
    }

    foreach ($root in @($policy.includeRoots)) {
        $prefix = "$addonName\$root\"
        $found = $entryNames | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if (-not $found) {
            $errors.Add("Missing required root content: $prefix")
        }
    }

    foreach ($root in $invariantRequiredRoots) {
        $prefix = "$addonName\$root\"
        $found = $entryNames | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if (-not $found) {
            $errors.Add("Missing invariant required root content: $prefix")
        }
    }

    foreach ($dir in @($policy.excludeDirectories)) {
        $prefix = "$addonName\$dir\"
        $found = $entryNames | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if ($found) {
            $errors.Add("Excluded directory is present: $prefix")
        }
    }

    foreach ($dir in $invariantForbiddenRoots) {
        $prefix = "$addonName\$dir\"
        $found = $entryNames | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if ($found) {
            $errors.Add("Invariant forbidden directory is present: $prefix")
        }
    }

    foreach ($file in @($policy.excludeFiles)) {
        $expected = "$addonName\$file"
        if ($entrySet.ContainsKey($expected.ToLowerInvariant())) {
            $errors.Add("Excluded file is present: $expected")
        }
    }

    $tocEntryName = "$addonName\$addonName.toc"
    $tocEntry = $zip.Entries | Where-Object { $_.FullName.Replace("/", "\") -ieq $tocEntryName } | Select-Object -First 1
    if (-not $tocEntry) {
        $errors.Add("Missing TOC file in zip: $tocEntryName")
    } else {
        $reader = New-Object System.IO.StreamReader($tocEntry.Open())
        try {
            $tocText = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }

        $tocText -split "`r?`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -eq "" -or $line.StartsWith("#")) {
                return
            }

            if ($line -match '\.(lua|xml)$') {
                $expected = "$addonName\$line"
                if (-not $entrySet.ContainsKey($expected.ToLowerInvariant())) {
                    $errors.Add("TOC references missing package file: $expected")
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "Package verification failed:" -ForegroundColor Red
        foreach ($message in $errors) {
            Write-Host "- $message" -ForegroundColor Red
        }
        exit 1
    }

    Write-Host "Package verification passed."
    Write-Host "Zip: $resolvedZipPath"
    Write-Host "Entries: $($entryNames.Count)"
} finally {
    $zip.Dispose()
}
