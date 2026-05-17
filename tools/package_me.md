# Packaging

Tools in this folder build the public CurseForge/manual release zip.

## Files

- `package.ps1`: builds the release zip.
- `package-policy.json`: single source of truth for package include/exclude behavior.

## Build

Run from the addon root:

```powershell
powershell -ExecutionPolicy Bypass -File tools/package.ps1
```

Output:

```text
dist/LsTweeks-<version>.zip
```

The version comes from `## Version:` in `LsTweeks.toc`.

## Package Rules

The zip must contain one top-level `LsTweeks/` folder.

Included and excluded paths are defined in `package-policy.json`.

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
- `LsTweeks.toc`

Currently excluded workspace/private paths:

- `.git/`
- `.github/`
- `.venv/`
- `.vscode/`
- `dist/`
- `tools/`
- `working_docs/`

README image assets under `media/readme_images/` and `media/svg/` are public-facing and included. Sound Levels reference/log files under `modules/sound_levels/sounds/` are public-facing and included.

## Verify

After building, inspect `dist/LsTweeks-<version>.zip` externally if desired. The build script validates TOC file references before creating the zip.
