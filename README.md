# dev_LsTweeks
Development workspace for the L's Tweeks World of Warcraft addon.

## Table of Contents
- [Downloads](#downloads)
- [Layout](#layout)
- [Development](#development)


## Downloads
- [Download current release: 00.24.00](releases/LsTweeks-00.24.00.zip?raw=true)
- [Previous versions](releases/previous_versions/) for rollback when needed. This folder is empty until the next version is released.
- [Addon guide and installation instructions](LsTweeks/ADDON_GUIDE.md#installation)

Extract the release zip into your WoW Interface/AddOns directory so it contains LsTweeks/LsTweeks.toc. Exit the game before replacing an installed version. Your settings are stored separately in WoW SavedVariables.


## Layout
- `LsTweeks/`: installable addon and public documentation. See the [full addon guide](LsTweeks/ADDON_GUIDE.md), [changelog](LsTweeks/CHANGELOG.md), [license](LsTweeks/LICENSE), and [credits](LsTweeks/sources.md).
- `internal_dev/`: project memory, planning, tools, tests, and packaging scripts. Its ignored scratch/ folder owns disposable per-run work; tests remove their own fixtures.
- `releases/`: current addon zip plus previous_versions/ for rollback zips; share the selected verified zip.


## Development
Run development commands from this repository root. Start with `internal_dev/agent-start.ps1`; command reference: `internal_dev/working_docs/proj_mem/code_map.md`.

For live work, the game's `Interface/AddOns/LsTweeks` directory links to this repository's inner `LsTweeks/` folder using a Windows junction. Edit the files here, then reload the game UI. Keep developer files outside the addon folder. Initial installation changes may require restarting the game.

Build releases with `internal_dev/tests_tools/packaging/package.ps1`. The package contains one `LsTweeks/` folder sourced from the inner addon directory. Migration progress is tracked in `internal_dev/working_docs/ToDo/dev_mode_go.md`.
