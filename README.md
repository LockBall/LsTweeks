# dev_LsTweeks
Development workspace for the L's Tweeks World of Warcraft addon.

## Table of Contents
- [Layout](#layout)
- [Development](#development)


## Layout
- `LsTweeks/`: installable addon and public documentation. See the [full addon guide](LsTweeks/ADDON_GUIDE.md), [changelog](LsTweeks/CHANGELOG.md), [license](LsTweeks/LICENSE), and [credits](LsTweeks/sources.md).
- `internal_dev/`: project memory, planning, tools, tests, and packaging scripts.
- `releases/`: current generated addon package and temporary build staging.
- `internal_dev/local_artifacts/`: ignored private release history, rollback snapshots, audit reports, and disposable test runs.


## Development
Run development commands from this repository root. Start with `internal_dev/agent-start.ps1`; command reference: `internal_dev/working_docs/proj_mem/code_map.md`.

For live work, the game's `Interface/AddOns/LsTweeks` directory links to this repository's inner `LsTweeks/` folder using a Windows junction. Edit the files here, then reload the game UI. Keep developer files outside the addon folder. Initial installation changes may require restarting the game.

Build releases with `internal_dev/tests_tools/packaging/package.ps1`. The package contains one `LsTweeks/` folder sourced from the inner addon directory. Migration progress is tracked in `internal_dev/working_docs/ToDo/dev_mode_go.md`.
