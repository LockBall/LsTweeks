# Development Workspace Migration

## Table of Contents
- [Goal](#goal)
- [Current State](#current-state)
- [Migration Checklist](#migration-checklist)
- [Completion Criteria](#completion-criteria)


## Goal
Separate the development repository from the installable addon. Edit one working copy and load edits through the existing manual in-game reload workflow.

Proposed outer workspace: `dev_LsTweeks`, containing the addon folder `LsTweeks/` alongside `internal_dev/`, `releases/`, and repository configuration. The outer workspace is the local repository directory; only its inner addon folder links into the game. Confirmed: both the outer local workspace and the GitHub repository will be named dev_LsTweeks. The inner addon folder remains LsTweeks.

Keep existing development folders together rather than introducing new ToDo/docs/tools folders. Resolve public documentation and license placement against packaging policy before moving files, retaining one owner for each document.


## Current State
- [x] Initial layout inspected: TOC and runtime folders live at the repository root.
- [x] Development tools and working documents identified under `internal_dev/`.
- [x] Packaging inspected: builder and verifier assume a root-level TOC and payload.
- [x] User confirmed the installed addon is an extraction of the latest release; the repository previously lived in AddOns.
- [x] Game AddOns directory supplied: `G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns`.
- [x] Existing migration note expanded into this checklist.
- No structural changes, repository renames, or installation changes performed yet.


## Migration Checklist

### 1. Establish The Working Baseline
- [x] Reviewed Git status: only this previously untracked note is changed; existing user work preserved.
- [x] Installed addon inspected: regular physical directory, with no existing junction.
- [x] Baseline recorded: version 00.24.00; SavedVariables Ls_Tweeks_DB; TOC retained in baseline archive; SHA256 manifest saved alongside it. All 153 payload files exactly match the 153 installed files.
- [ ] Audit path assumptions in tools, tests, editor configuration, automation, runtime assets, and documentation.
- [x] Fast validation and all 28 headless suites passed after correcting this note to LF line endings.
- [x] Baseline archive and payload_manifest.json saved under releases/migration_baseline; baseline archive now passes verification after fixing .agents and .claude exclusions.
- [x] Saved tracked repository checkpoint as releases/migration_baseline/repository_HEAD.zip at the recorded baseline commit. The baseline addon archive matches the installed payload byte for byte. Migration note and preparation changes are saved beside the checkpoint. Keep installed release in place until the junction step.

### 2. Separate The Addon Payload
- [ ] Create `LsTweeks/` inside the repository and move the agreed addon payload into it.
- [ ] Keep planning, project memory, tools, tests, packaging scripts, and repository configuration outside that folder.
- [ ] Preserve addon name, TOC content and load order, relative paths, runtime assets, SavedVariables, version, and behavior.
- [ ] Compare moved payload hashes against the baseline and explain intentional differences.

### 3. Update Development And Packaging Paths
- [ ] Distinguish repository root from addon root in affected tools and tests.
- [ ] Update package policy, builder, and verifier to consume the inner addon folder.
- [ ] Update editor configuration, automation, and development commands where needed.
- [ ] Update project memory, file maps, installation instructions, and superseded path references.
- [ ] Run appropriate existing checks after the final path changes.
- [ ] Build and verify a release; compare payload contents with the baseline and confirm one top-level `LsTweeks/` folder.

### 4. Apply Repository Naming
- [x] Confirmed both hosted repository and local workspace rename to dev_LsTweeks.
- [ ] Rename the outer local directory to `dev_LsTweeks`, accounting for the active workspace and filesystem permissions.
- [ ] If included, rename the hosted repository and update the Git remote and affected links.
- [ ] Reopen the final workspace as needed and verify Git and development commands.
- [ ] Finish local relocation before creating the final game junction.

### 5. Connect The Live Game Installation
- [ ] Preserve the installed release as a rollback copy outside the active AddOns scan location.
- [ ] Create `AddOns/LsTweeks` as a Windows junction to the final workspace's inner `LsTweeks/` folder.
- [ ] Verify the junction target and confirm development files remain outside it.
- [ ] Verify TOC entries and runtime assets through the game-facing path.
- [ ] Preserve saved settings; keep the addon SavedVariables identity and files intact.

### 6. Verify In Game And Close Out
- [ ] User confirms discovery and loading; restart the client if needed for the initial installation change.
- [ ] User confirms saved settings, expected module behavior, media, and absence of new Lua errors.
- [ ] Confirm a harmless visible edit appears after manual reload, then restore that edit.
- [ ] Record final layout and validation evidence in owning documentation.
- [ ] Review the final diff and provide one combined commit message.
- [ ] Retain rollback files until the live workflow is confirmed working.


## Completion Criteria
- The development workspace has a clear development name; the addon retains `LsTweeks`.
- The game loads the same inner addon files edited in the workspace through a verified junction.
- Manual reload picks up edits without copying or syncing.
- Development files remain outside the linked addon folder.
- Releases are built from the inner payload and pass package verification.
- Baseline comparison and in-game acceptance confirm the working addon is preserved.

Baseline Git commit: 19da6202818b132770b037c4e728d1bfca69c96a. Preliminary path audit identified the fast checker, region and contract checks, packaging scripts, API/annotation tooling, and LuaLS tooling as migration review targets. Full path audit and recoverable checkpoint remain pending. No runtime or installation changes made.

Preparation fixes: explicit policy exclusions and invariant guards for .agents/.claude; builder invokes verifier in a separate process and propagates failure; fast checker propagates Lua syntax, whitespace, and package failures. Isolated packaging regression checks passed (valid fixture and deliberate failing verifier). Real package and non-test fast checks passed after fixes; runtime files are unchanged, so the earlier 28-suite baseline remains applicable.

Path audit findings to address during the move: packaging root discovery and coverage inventory; fast-check TOC and file selection; region-check vendored-library exclusion; internal-contract source roots; headless harness addon root and changed-suite selection; API reference TOC default; LuaLS/editor library exclusions; .gitattributes and .editorconfig paths; public README links and repository entry point; project and command documentation. API caches stay under internal_dev and need relocation-aware handling when the outer workspace is renamed.
