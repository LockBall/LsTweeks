# Packaging
Tools in this folder build the public CurseForge/manual release zip.


## Table of Contents
- [Files](#files)
- [Release Routine](#release-routine)
- [Build](#build)
- [Package Rules](#package-rules)
- [Verify](#verify)


## Files
- `package.ps1`: builds the release zip.
- `package-policy.json`: single source of truth for package include/exclude behavior.
- `verify-package.ps1`: verifies a generated release zip against `package-policy.json`.
- `test_packaging.ps1`: isolated fixture checks for exclusions, release/private boundaries, historical archive preservation/collisions, and failure propagation. Run with `pwsh.exe -NoProfile -File internal_dev/tests_tools/packaging/test_packaging.ps1`; its deliberate failure case prints an expected verification exception before the final pass message.


## Release Routine

Use this sequence for an addon release. Internal tooling or documentation maintenance alone does not require an addon version bump or public changelog entry. Commands are owned by `code_map.md` `## Fast Commands`; the build and verifier commands below own packaging details.

1. Establish scope: review the diff and working-tree status, intended client family/channel/build, and current TOC version/interfaces. Identify unrelated or untracked files before packaging; resolve their disposition explicitly rather than including them by accident.
2. For a client compatibility update or patch-sensitive API change, follow project memory's Ketho / LuaLS refresh procedure. Compare the previous and refreshed Blizzard API/FrameXML snapshots for affected addon paths, record source and annotation provenance, and investigate required migrations. A successful refresh or interface-mismatch override does not establish support.
3. For a release containing public behavior or declared compatibility changes, choose the next addon version using the existing TOC format and add a matching newest-first changelog entry. Record concrete user-facing changes; distinguish source review from in-game verification. Add TOC interface declarations only when supported by the compatibility review, not to silence a preparation guard.
4. Validate the final candidate: run impact-selected headless tests and fast checks, plus LuaLS against the appropriate refreshed annotations when Lua/API compatibility is affected. A broad client compatibility review warrants all headless suites and full LuaLS. Record passes, failures, and deliberate skips against the candidate; rerun affected checks if subsequent edits invalidate them. Static/headless passes do not prove combat, taint, rendering, or event-order behavior.
5. Track in-game acceptance in a focused compatibility/feature review under `working_docs/ToDo/`, with client build, addon version, affected scenarios, and results. Cover reload, relevant combat transitions, settings/module toggles, and normal gameplay as applicable. Keep pending items explicit; only claim acceptance after their results are recorded. Consolidate durable findings and retire the review when complete.
6. Build the release zip and require its automatic verifier to pass. Confirm its filename/version, public changelog, and intended contents. Packaging can prepare a candidate while in-game checks are pending; it is not publication approval. Rebuild after changes to packaged files so the final artifact matches the tested candidate.
7. Before publication, confirm the final candidate has passing required checks and recorded in-game acceptance, review the final diff/status, and identify the exact artifact and version being released. Commit, push, tag, or upload only within the user's authorized scope. Report remaining limitations and the actual publication outcome separately from package creation.


## Build
Run from the repository root:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/package.ps1
```

Output:

```text
releases/<toc-name>-<version>.zip
```

`releases/` contains the current generated package and temporary staging only. After candidate verification succeeds, the builder replaces the current zip and moves older output zips into ignored `internal_dev/local_artifacts/release_history/`. Same-name history with different contents fails visibly; identical archived copies are reused. Failed verification preserves the prior current zip and leaves older packages in place.

Private rollback snapshots, audit reports, repair backups, and disposable test runs live under `internal_dev/local_artifacts/`, outside distributable output. Nothing in that private tree is automatically published or packaged. Legacy archives are retained unchanged and are not approved for public distribution by being archived.

The optional OutputDir must remain under releases. Output/private-history paths and staging refuse filesystem links; unexpected non-package output files/directories fail preflight. KeepStage retains the addon staging tree for inspection. Publication remains separate from building.

The addon package name comes from the addon-root `.toc` filename. The version comes from `## Version:` in that `.toc` file.

`package.ps1` automatically runs `verify-package.ps1` after building.
Verifier failure produces a nonzero builder exit; fast validation also fails when its package step fails.


## Package Rules
The zip must contain one top-level folder matching the addon-root `.toc` filename.

Included and excluded paths are defined in `package-policy.json` relative to the inner `LsTweeks/` directory. Repository development files are outside the source boundary.
Top-level files or folders ignored by `.gitignore` are treated as excluded by the verifier, so local cache/build artifacts do not need duplicate entries in `package-policy.json`.

Currently included public roots:

- `core/`
- `functions/`
- `libs/`
- `media/`
- `modules/`

Currently included public files:

- `LICENSE`
- `ADDON_GUIDE.md`
- `CHANGELOG.md`
- `sources.md`
- `<toc>` placeholder, resolved to the addon-root `.toc` filename

Currently excluded workspace/private paths:

- `.git/`
- `.agents/`
- `.claude/`
- `.github/`
- `internal_dev/`
- `releases/`
- `.gitignore`

Common ignored dev-only paths are excluded through `.gitignore`, including local virtual environments, editor caches, LuaLS check output, package build output, OS junk, and temporary/compiler output.

README image assets under `media/readme_images/` and `media/svg/` are public-facing and included. Audio Volumes reference/log files under `modules/audio_volumes/sounds/` are public-facing and included.


## Verify
Run verification directly with:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/packaging/verify-package.ps1 releases/<toc-name>-<version>.zip
```

The verifier checks:

- the zip opens successfully
- the zip has one top-level folder matching the addon-root `.toc` filename
- required included roots/files from `package-policy.json` are present
- excluded roots/files from `package-policy.json` are absent
- every top-level addon file/folder is accounted for by an include rule, an explicit exclude rule, or `.gitignore`
- the zip file count matches the number of policy-included workspace files
- invariant required public files/roots are present even if the policy is edited incorrectly
- invariant forbidden private/workspace roots are absent even if the policy is edited incorrectly
- all Lua/XML files referenced by the addon-root `.toc` file exist inside the zip
- entries do not use unsafe rooted or parent-traversal paths

After building, inspect `releases/<toc-name>-<version>.zip` externally if desired.
