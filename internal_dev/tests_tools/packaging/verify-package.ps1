param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ZipPath
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
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
    "internal_dev"
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
$policyIncludeRoots = @($policy.includeRoots)
$policyExcludeDirectories = @($policy.excludeDirectories)
$policyExcludeFiles = @($policy.excludeFiles)
$errors = New-Object System.Collections.Generic.List[string]

function Normalize-RelativePath {
    param([string]$Path)
    return $Path.Replace("/", "\").Trim("\")
}

function Test-UnderAnyRoot {
    param(
        [string]$RelativePath,
        [object[]]$Roots
    )

    $relative = Normalize-RelativePath $RelativePath
    foreach ($root in @($Roots)) {
        $normalizedRoot = Normalize-RelativePath $root
        if ($relative -ieq $normalizedRoot -or $relative.StartsWith("$normalizedRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-RepoRelativePath {
    param([System.IO.FileSystemInfo]$Item)

    $root = $repoRoot.TrimEnd("\")
    $fullName = $Item.FullName
    if ($fullName.Length -le $root.Length) {
        return ""
    }
    return Normalize-RelativePath $fullName.Substring($root.Length + 1)
}

function Test-GitIgnored {
    param(
        [string]$RelativePath,
        [bool]$IsDirectory
    )

    $relative = (Normalize-RelativePath $RelativePath).Replace("\", "/")
    if ($IsDirectory -and -not $relative.EndsWith("/")) {
        $relative = "$relative/"
    }

    & git -C $repoRoot check-ignore --quiet --no-index -- $relative
    return $LASTEXITCODE -eq 0
}

function Add-ExcludedDirectory {
    param(
        [System.IO.DirectoryInfo]$Directory,
        [System.Collections.Generic.List[string]]$ExcludedDirectories,
        [System.Collections.Generic.List[string]]$ExcludedFiles
    )

    $relative = Get-RepoRelativePath $Directory
    $ExcludedDirectories.Add($relative)
    Get-ChildItem -LiteralPath $Directory.FullName -Force -Recurse | ForEach-Object {
        $childRelative = Get-RepoRelativePath $_
        if ($_.PSIsContainer) {
            $ExcludedDirectories.Add($childRelative)
        } else {
            $ExcludedFiles.Add($childRelative)
        }
    }
}

function Get-PolicyCoverageInventory {
    $includedFiles = New-Object System.Collections.Generic.List[string]
    $includedDirectories = New-Object System.Collections.Generic.List[string]
    $excludedFiles = New-Object System.Collections.Generic.List[string]
    $excludedDirectories = New-Object System.Collections.Generic.List[string]

    $rootItems = @(Get-ChildItem -LiteralPath $repoRoot -Force)
    foreach ($item in $rootItems) {
        $relative = Get-RepoRelativePath $item
        if ($item.PSIsContainer) {
            if ((Test-UnderAnyRoot $relative $policyIncludeRoots)) {
                $includedDirectories.Add($relative)
                Get-ChildItem -LiteralPath $item.FullName -Force -Recurse | ForEach-Object {
                    $childRelative = Get-RepoRelativePath $_
                    if ($_.PSIsContainer) {
                        $includedDirectories.Add($childRelative)
                    } else {
                        $includedFiles.Add($childRelative)
                    }
                }
            } elseif ((Test-UnderAnyRoot $relative $policyExcludeDirectories)) {
                Add-ExcludedDirectory -Directory $item -ExcludedDirectories $excludedDirectories -ExcludedFiles $excludedFiles
            } elseif (Test-GitIgnored -RelativePath $relative -IsDirectory $true) {
                Add-ExcludedDirectory -Directory $item -ExcludedDirectories $excludedDirectories -ExcludedFiles $excludedFiles
            } else {
                $errors.Add("Unaccounted top-level directory in workspace: $relative")
            }
        } else {
            if ($policyIncludeFiles | Where-Object { (Normalize-RelativePath $_) -ieq $relative } | Select-Object -First 1) {
                $includedFiles.Add($relative)
            } elseif ($policyExcludeFiles | Where-Object { (Normalize-RelativePath $_) -ieq $relative } | Select-Object -First 1) {
                $excludedFiles.Add($relative)
            } elseif (Test-GitIgnored -RelativePath $relative -IsDirectory $false) {
                $excludedFiles.Add($relative)
            } else {
                $errors.Add("Unaccounted top-level file in workspace: $relative")
            }
        }
    }

    return [pscustomobject]@{
        IncludedFiles = @($includedFiles)
        IncludedDirectories = @($includedDirectories)
        ExcludedFiles = @($excludedFiles)
        ExcludedDirectories = @($excludedDirectories)
    }
}

$coverage = Get-PolicyCoverageInventory

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

    if ($entryNames.Count -ne $coverage.IncludedFiles.Count) {
        $errors.Add("Zip file count does not match policy-included workspace files. Zip: $($entryNames.Count), expected: $($coverage.IncludedFiles.Count)")
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

    foreach ($root in $policyIncludeRoots) {
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

    foreach ($dir in $policyExcludeDirectories) {
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

    foreach ($file in $policyExcludeFiles) {
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
    Write-Host "Policy coverage: $($coverage.IncludedFiles.Count) included files, $($coverage.IncludedDirectories.Count) included folders, $($coverage.ExcludedFiles.Count) excluded files, $($coverage.ExcludedDirectories.Count) excluded folders"
} finally {
    $zip.Dispose()
}

