# Pre-Public Release Security and Privacy Review

## Table of Contents
- [Scope and Result](#scope-and-result)
- [Findings](#findings)
- [Asset Organization](#asset-organization)
- [Publication Decisions](#publication-decisions)
- [Evidence and Limits](#evidence-and-limits)


## Scope and Result
Reviewed November 4, 2026: the 153-file LsTweeks payload, all 12 top-level release zips, local backup archive boundaries, public repository/release metadata, and relevant Lua behavior. This is preparation for broader distribution; only the owner and one friend have used the addon so far.

No obvious credentials, private keys, personal saved settings, unexpected executable files, or outbound telemetry/message-sending/dynamic-code-loading calls were identified in the current payload. The current release matches that screened payload byte for byte. This is a scoped screening result, not a guarantee against vulnerabilities.

Screened current artifact: releases/LsTweeks-00.24.00.zip
SHA256: 63EAD0250619EC5F6F4634727D77DFDECEEE3F62EAB5D1B3AF51963B636E9903


## Findings
- Distribution boundaries: the current addon zip excludes internal_dev, Git/editor state, local environments, and SavedVariables. No unsafe paths, duplicate entries, or archive symlinks were found in the inspected archives.
- Older 0.9.5 and 0.9.6 zips contain audio-conversion logs with local drive/project paths. These disclose local organization, not detected passwords or account tokens. Retain as historical/private unless deliberately cleaned and rebuilt; do not silently replace an old published artifact.
- Two small PNG documentation graphics contain Adobe editing timestamps, software identifiers, and document IDs. No email, local path, creator identity, or GPS metadata was found. This is optional metadata minimization, not a detected personal-data breach.
- SVGs showed no detected scripts, event-handler attributes, or external image-fetch references. Font name tables and OGG comments showed no detected private local paths or credential indicators. The two PNGs were also visually inspected.
- ChatCopySghetti copies readable chat on user action, omits private-name escape payloads, and clears popup text on close. It does not persist chat text or send it elsewhere in the reviewed code. Manually copied chat can still contain player names or private conversation; users should review it before sharing.
- internal_dev/local_artifacts/migration_baseline/repository_HEAD.zip is a development-repository snapshot. internal_dev/local_artifacts/final_audit/venv_launchers_before.zip contains environment executables and local path metadata. Neither is a player distribution. Share the individually verified addon zip, not the entire releases directory.
- GitHub source visibility is public. GitHub has no hosted releases, and local release zips are not Git-tracked; releases/.gitkeep is the only tracked item there. Local archive age does not itself imply public exposure.


## Asset Organization
Executed plan:
1. Preserve all existing files and record source/destination SHA256 values before moving anything.
2. Keep releases/LsTweeks-00.24.00.zip as the current distributable candidate.
3. Move 11 older zips into internal_dev/local_artifacts/release_history/, without changing archived contents.
4. Move migration_baseline and final_audit under internal_dev/local_artifacts/; leave the game rollback copy outside AddOns unchanged.
5. Move disposable test fixtures into local_artifacts/test_runs, update ignore/docs, and enforce the release/private boundary in packaging.
6. Verify staged candidates before replacing the current package; archive older output only after successful verification, with collision refusal and hash checks.

The move preserved all 25 moved files byte for byte, and the 153-file runtime payload remains unchanged. Extended regressions passed for output boundaries, identical/different history collisions, linked output refusal, and verification failure preserving both current and older zips. The final rebuilt archive passed package verification and a fresh non-remediating Defender scan; its updated fingerprint is recorded above. Private move manifest: internal_dev/local_artifacts/asset_organization_20261104.json. That entire tree is ignored by Git. No hosted releases, repository visibility, runtime payloads, or historical archive contents were changed by this organization.

## Publication Decisions
These are preparation choices, not evidence of a current credential leak:
- [x] All 11 older local release zips moved unchanged to private release_history; only version 00.24.00 remains in releases.
- [x] Migration snapshots and audit/repair backups moved out of releases into ignored internal_dev/local_artifacts.
- [ ] Decide whether to strip nonessential image editing metadata before broader distribution.
- [ ] Consider a concise player-guide reminder to review manually exported chat before sharing.
- [ ] If source-repository privacy is part of the launch scope, review tracked development documents/logs and Git history separately; release-file exclusion does not make the public repository private.


## Evidence and Limits
Local findings report: internal_dev/local_artifacts/final_audit/security_privacy_scan.json. Defender results: internal_dev/local_artifacts/final_audit/defender_security_scan.json. Reports contain paths/categories and scan results, not extracted credential values.

Defender was enabled; its installed signature timestamp was November 3, 2026. Non-remediating custom scans of the addon folder and 12 top-level release zips completed with exit 0 and no detections reported. No Defender settings were changed. Restricted-context status access failed; approved access worked.

Static checks covered selected credential patterns, sensitive filenames/paths, package contents, asset metadata, and relevant Lua APIs. They do not prove the absence of all secrets, exploitability, maliciously crafted assets, or vulnerabilities in dependencies/client parsers. Upstream dependency authenticity and Git history were not fully audited. No uploads to public scanning services, release publication/removal, visibility changes, or payload edits were performed.

Organization verification: internal_dev/local_artifacts/final_audit/asset_organization_verification.json. Recheck the actual artifact after any changes; this fingerprint applies only to the file named above. The directory-junction workflow is a development installation choice, not an added capability in the public release.
