# Development Migration Follow-Up

## Table of Contents
- [Completed](#completed)
- [Remaining Gameplay Observation](#remaining-gameplay-observation)
- [Rollback and Retention](#rollback-and-retention)
- [Permanent Documentation](#permanent-documentation)


## Completed
Migration and live-edit workflow accepted November 4, 2026.
- Development workspace and repository: dev_LsTweeks; installable payload: LsTweeks/.
- AddOns/LsTweeks is a Windows junction to F:\from_git\dev_LsTweeks\LsTweeks. Development files remain outside its target.
- Full player documentation preserved as LsTweeks/ADDON_GUIDE.md; root README.md explains development.
- User confirmed successful game loading, no issues so far, and a visible working-copy edit after /reload. The temporary edit was restored exactly.
- At the structural checkpoint, all 153 original file contents matched across source, live link, package, and rollback, allowing the README.md to ADDON_GUIDE.md rename. The later LICENSE heading/line-ending correction is documented in release_security_privacy.md; the current package matches the current payload.
- All 28 headless suites, fast checks, full LuaLS, package verification, and packaging/annotation-relocation regressions passed. Stale helper-environment paths and documentation references were corrected.
- Structural checkpoint: e17ac19. Baseline checkpoint: 19da6202818b132770b037c4e728d1bfca69c96a.


## Remaining Gameplay Observation
- [ ] Use the addon normally over several sessions, watching for missing assets, unexpected settings changes, or new Lua errors.
- [ ] Investigate specific reproducible issues if any appear; do not repeat the broad migration audit without new evidence.
- [ ] Once comfortable with normal gameplay, review backup retention and retire this completed follow-up note.

Loading and live reload are verified. Extended gameplay observation is still in progress; the migration checks do not establish exhaustive combat, taint, or module-scenario coverage.


## Rollback and Retention
Keep the known-good physical installation until extended gameplay observation is satisfactory:
- Rollback: G:\Games\Blizzard\World of Warcraft\_retail_\Interface\LsTweeks_dev_backups\20261104_210036_release_00.24.00.
- Current package: releases/LsTweeks-00.24.00.zip.

Obsolete packaged versions, duplicate Git-recoverable snapshots/patches, successful test logs, and verified-repair backups were deliberately removed. Packaging retains earlier public addon zips in releases/previous_versions/ when a new version is built; disposable development evidence is not archived. Audit conclusions remain in the existing migration/security notes; baseline content is recoverable from the recorded Git checkpoints. The redundant evidence folder was removed. Disposable tests use ignored internal_dev/scratch/ and clean up after themselves.

Rollback with WoW closed: inspect and remove only the AddOns/LsTweeks junction itself, then move the preserved physical installation back to AddOns/LsTweeks. Never recursively delete the junction target. SavedVariables identity and files were left unchanged; runtime rollback is not a saved-data restore.


## Permanent Documentation
- [Project memory](../proj_mem/project.md): layout, payload ownership, packaging, and verified live workflow.
- [Tool notes](../../tests_tools/tools_notes.md): environment diagnosis and relocation recovery; command routing remains in code_map.md.
- dev_foundation: core_policy/project_layout.md owns reusable organization/migration guidance; environments/powershell/ps_shell_setup.md owns Windows link semantics.
- Git history retains the detailed migration checklist and investigation. Keep this note focused on the remaining observation and local rollback references.
