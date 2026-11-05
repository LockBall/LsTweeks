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
- All 153 original file contents verified across source, live link, final package, and rollback, allowing the intentional README.md to ADDON_GUIDE.md rename.
- All 28 headless suites, fast checks, full LuaLS, package verification, and packaging/annotation-relocation regressions passed. Stale helper-environment paths and documentation references were corrected.
- Structural checkpoint: e17ac19. Baseline checkpoint: 19da6202818b132770b037c4e728d1bfca69c96a.


## Remaining Gameplay Observation
- [ ] Use the addon normally over several sessions, watching for missing assets, unexpected settings changes, or new Lua errors.
- [ ] Investigate specific reproducible issues if any appear; do not repeat the broad migration audit without new evidence.
- [ ] Once comfortable with normal gameplay, review backup retention and retire this completed follow-up note.

Loading and live reload are verified. Extended gameplay observation is still in progress; the migration checks do not establish exhaustive combat, taint, or module-scenario coverage.


## Rollback and Retention
Keep these until extended gameplay observation is satisfactory; no automatic deletion is planned:
- Previous physical installation: G:\Games\Blizzard\World of Warcraft\_retail_\Interface\LsTweeks_dev_backups\20261104_210036_release_00.24.00.
- Local baseline payload, manifest, and repository snapshot: internal_dev/local_artifacts/migration_baseline/.
- Final package: releases/LsTweeks-00.24.00.zip.
- Audit logs and development-environment repair backups: internal_dev/local_artifacts/final_audit/.

Rollback with WoW closed: inspect and remove only the AddOns/LsTweeks junction itself, then move the preserved physical installation back to AddOns/LsTweeks. Never recursively delete the junction target. SavedVariables identity and files were left unchanged; runtime rollback is not a saved-data restore.


## Permanent Documentation
- [Project memory](../proj_mem/project.md): layout, payload ownership, packaging, and verified live workflow.
- [Tool notes](../../tests_tools/tools_notes.md): environment diagnosis and relocation recovery; command routing remains in code_map.md.
- dev_foundation: core_policy/project_layout.md owns reusable organization/migration guidance; environments/powershell/ps_shell_setup.md owns Windows link semantics.
- Git history retains the detailed migration checklist and investigation. Keep this note focused on the remaining observation and local rollback references.
