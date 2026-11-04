# Development Workspace Migration

## Table of Contents
- [Goal](#goal)
- [Current State](#current-state)
- [Migration Checklist](#migration-checklist)
- [Completion Criteria](#completion-criteria)


## Goal
Separate the development repository from the installable addon. Edit one working copy and load edits through the existing manual in-game reload workflow.

Confirmed outer workspace: `dev_LsTweeks`, containing the addon folder `LsTweeks/` alongside `internal_dev/`, `releases/`, and repository configuration. The outer workspace is the local repository directory; only its inner addon folder links into the game. Confirmed: both the outer local workspace and the GitHub repository will be named dev_LsTweeks. The inner addon folder remains LsTweeks.

Keep existing development folders together rather than introducing new ToDo/docs/tools folders. Public guide, changelog, license, and sources moved with the addon payload; the full guide is now named ADDON_GUIDE.md with unchanged contents; the outer development README links to them.


## Current State
- [x] Initial layout inspected: TOC and runtime folders originally lived at the repository root.
- [x] Development tools and working documents identified under `internal_dev/`.
- [x] Packaging inspected and migrated from repository-root assumptions to the inner addon root.
- [x] User confirmed the installed addon is an extraction of the latest release; the repository previously lived in AddOns.
- [x] Game AddOns directory supplied: `G:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns`.
- [x] Existing migration note expanded into this checklist.
- Structural split implemented and validated. GitHub repository renamed to dev_LsTweeks and origin updated; nothing pushed. Local outer rename and game junction remain pending. The installed release is unchanged.


## Migration Checklist

### 1. Establish The Working Baseline
- [x] Reviewed Git status: only this previously untracked note is changed; existing user work preserved.
- [x] Installed addon inspected: regular physical directory, with no existing junction.
- [x] Baseline recorded: version 00.24.00; SavedVariables Ls_Tweeks_DB; TOC retained in baseline archive; SHA256 manifest saved alongside it. All 153 payload files exactly match the 153 installed files.
- [x] Audit path assumptions in tools, tests, editor configuration, automation, runtime assets, and documentation.
- [x] Fast validation and all 28 headless suites passed after correcting this note to LF line endings.
- [x] Baseline archive and payload_manifest.json saved under releases/migration_baseline; baseline archive now passes verification after fixing .agents and .claude exclusions.
- [x] Saved tracked repository checkpoint as releases/migration_baseline/repository_HEAD.zip at the recorded baseline commit. The baseline addon archive matches the installed payload byte for byte. Migration note and preparation changes are saved beside the checkpoint. Keep installed release in place until the junction step.

### 2. Separate The Addon Payload
- [x] Create `LsTweeks/` inside the repository and move the agreed addon payload into it.
- [x] Keep planning, project memory, tools, tests, packaging scripts, and repository configuration outside that folder.
- [x] Preserve addon name, TOC content and load order, relative paths, runtime assets, SavedVariables, version, and behavior.
- [x] Compare moved payload hashes against the baseline and explain intentional differences.

### 3. Update Development And Packaging Paths
- [x] Distinguish repository root from addon root in affected tools and tests.
- [x] Update package policy, builder, and verifier to consume the inner addon folder.
- [x] Update editor configuration, automation, and development commands where needed.
- [x] Update project memory, file maps, installation instructions, and superseded path references.
- [x] Run appropriate existing checks after the final path changes.
- [x] Build and verify a release; compare payload contents with the baseline and confirm one top-level `LsTweeks/` folder.

### 4. Apply Repository Naming
- [x] Confirmed both hosted repository and local workspace rename to dev_LsTweeks.
- [x] User renamed the outer local directory to dev_LsTweeks; old path is absent and new path verified.
- [x] Renamed GitHub repository to LockBall/dev_LsTweeks and updated origin; verified remotely. No push performed.
- [x] Verified Git, fast non-test checks, candidate package verification, and all 153 payload hashes from the renamed directory. Rebased annotation receipt paths offline.
- [x] Local relocation complete; game junction still pending.

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

Baseline commit: 19da6202818b132770b037c4e728d1bfca69c96a. Tested preparation commit: 581734a (committed by user). Rollback artifacts remain under releases/migration_baseline.

Validation after the split: all 153 moved payload hashes unchanged; all 28 headless suites and fast checks passed; isolated packaging regression checks passed; candidate zip under releases/migration_candidate verified and its entry contents matched the baseline exactly. Targeted LuaLS check of LsTweeks/core/init.lua completed with no problems.

Annotation receipts had stale absolute paths from the former game-directory workspace. Added sync_wow_annotations.ps1 -Relocate to validate cached source/generator/FrameXML commit identity before updating only receipt paths offline. Matching relocation and refusal-without-write regression checks passed. Run relocation again after the outer workspace rename. API snapshot and generation provenance are unchanged.

Remaining handoff: local outer directory rename and workspace reopen, then close WoW before replacing the installed release with a junction. WoW was running during this stage; no installation changes were attempted. Verify commands from the final location before switching the game path.

Outer rename attempt: Windows refused moving F:\from_git\LsTweeks to F:\from_git\dev_LsTweeks because another process holds the directory open. No relocation occurred. Close the active workspace/editor, rename the outer folder, and reopen it at the new location; then run the offline annotation relocation command and verify Git/tooling before creating the game junction. The destination did not already exist at preflight. This was an operating-system file lock, not an approval rejection.

Local rename verified: F:\from_git\dev_LsTweeks exists, old outer path is absent, origin is https://github.com/LockBall/dev_LsTweeks.git, and addon payload hashes and package verification remain clean. Annotation receipt paths rebased to the renamed workspace. No WoW process was detected at this verification; installed AddOns/LsTweeks remains a physical release directory. This session still has the old workspace write boundary, so writes to the renamed directory require escalation until the workspace is reopened/reselected.

Documentation naming: root README.md is the development guide; LsTweeks/ADDON_GUIDE.md is the complete original player README, renamed with its contents preserved byte for byte. Packaging rules, invariants, fixtures, editor configuration, and documentation routes updated. Baseline payload comparisons must map the original README.md entry to ADDON_GUIDE.md; this filename change is intentional.
