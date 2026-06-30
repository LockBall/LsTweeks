# Packaging
Tools in this folder build the public CurseForge/manual release zip.


## Table of Contents
- [Files](#files)
- [Build](#build)
- [Package Rules](#package-rules)
- [Verify](#verify)


## Files
- `package.ps1`: builds the release zip.
- `package-policy.json`: single source of truth for package include/exclude behavior.
- `verify-package.ps1`: verifies a generated release zip against `package-policy.json`.


## Build
Run from the addon root:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/package.ps1
```

Output:

```text
dist/<toc-name>-<version>.zip
```

The addon package name comes from the root `.toc` filename. The version comes from `## Version:` in that `.toc` file.

`package.ps1` automatically runs `verify-package.ps1` after building.


## Package Rules
The zip must contain one top-level folder matching the root `.toc` filename.

Included and excluded paths are defined in `package-policy.json`.
Top-level files or folders ignored by `.gitignore` are treated as excluded by the verifier, so local cache/build artifacts do not need duplicate entries in `package-policy.json`.

Currently included public roots:

- `core/`
- `functions/`
- `libs/`
- `media/`
- `modules/`

Currently included public files:

- `LICENSE`
- `README.md`
- `sources.md`
- `<toc>` placeholder, resolved to the root `.toc` filename

Currently excluded workspace/private paths:

- `.git/`
- `.github/`
- `internal_dev/`
- `.gitignore`

Common ignored dev-only paths are excluded through `.gitignore`, including local virtual environments, editor caches, LuaLS check output, package build output, OS junk, and temporary/compiler output.

README image assets under `media/readme_images/` and `media/svg/` are public-facing and included. Audio Volumes reference/log files under `modules/sound_levels/sounds/` are public-facing and included.


## Verify
Run verification directly with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/verify-package.ps1 dist/<toc-name>-<version>.zip
```

The verifier checks:

- the zip opens successfully
- the zip has one top-level folder matching the root `.toc` filename
- required included roots/files from `package-policy.json` are present
- excluded roots/files from `package-policy.json` are absent
- every top-level workspace file/folder is accounted for by an include rule, an explicit exclude rule, or `.gitignore`
- the zip file count matches the number of policy-included workspace files
- invariant required public files/roots are present even if the policy is edited incorrectly
- invariant forbidden private/workspace roots are absent even if the policy is edited incorrectly
- all Lua/XML files referenced by the root `.toc` file exist inside the zip
- entries do not use unsafe rooted or parent-traversal paths

After building, inspect `dist/<toc-name>-<version>.zip` externally if desired.
