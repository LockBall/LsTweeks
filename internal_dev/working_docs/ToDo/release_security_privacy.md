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
SHA256: 9E83EDA1F0A88956F3DD3A64155F53EFBD7D1981F2B48D89ADDC1C5F12EFBB65


## Findings
- Distribution boundaries: the current addon zip excludes internal_dev, Git/editor state, local environments, and SavedVariables. No unsafe paths, duplicate entries, or archive symlinks were found in the inspected archives.
- Older 0.9.5/0.9.6 zips contained local audio-conversion paths, not detected credentials. These and the other obsolete historical package copies were deliberately deleted locally during retention cleanup; no hosted assets were removed.
- Two small PNG documentation graphics contain Adobe editing timestamps, software identifiers, and document IDs. No email, local path, creator identity, or GPS metadata was found. This is optional metadata minimization, not a detected personal-data breach.
- SVGs showed no detected scripts, event-handler attributes, or external image-fetch references. Font name tables and OGG comments showed no detected private local paths or credential indicators. The two PNGs were also visually inspected.
- ChatCopySghetti copies readable chat on user action, omits private-name escape payloads, and clears popup text on close. It does not persist chat text or send it elsewhere in the reviewed code. Manually copied chat can still contain player names or private conversation; users should review it before sharing.
- Repository snapshots and environment repair archives are private development data. Redundant copies were removed after confirming Git recovery and successful repair; none should be included in distribution output.
- At the November 4 review, GitHub source visibility was public, no hosted GitHub releases existed, and local zips were untracked. On November 5, the owner requested Git-tracked release zips with README download links; current and retained previous-version zips are now eligible for commit and will become public when pushed. The deleted historical zips are not being restored.


## Asset Organization
Completed: current package candidates are separate from private local data, and the live addon payload is unchanged. The initial move preserved all files; a subsequent deliberate retention cleanup discarded 11 obsolete packaged builds, Git-recoverable duplicate snapshots/patches, successful audit logs, and verified-repair backups.

The redundant local evidence folder was removed after checking its manifest against the recorded Git checkpoint, source, current release, and external rollback. Conclusions are retained in this note and the migration follow-up; content history remains in Git. The current release and known-good physical rollback beside the game installation remain. Disposable work stays under ignored internal_dev/scratch/ and is removed by its owning test. New-version builds retain prior public addon zips in releases/previous_versions/; development evidence and audit logs are not archived automatically. Keep extra material only for a concrete current purpose and retire it when that purpose ends.

Packaging still verifies candidates before replacement, rejects unsafe/linked output, propagates failure, and moves prior addon-version zips unchanged into releases/previous_versions/ after a verified new version is published locally. Updated regression checks passed. Same-version rebuilds do not retain extra copies; older archives are pruned deliberately.


## Publication Decisions
These are preparation choices, not evidence of a current credential leak:
- [x] All 11 obsolete historical release copies deliberately removed after review; only version 00.24.00 remains in releases.
- [x] Private data separated, then reduced to compact evidence. Duplicate snapshots/repair backups were removed; the external known-good rollback remains.
- [ ] Decide whether to strip nonessential image editing metadata before broader distribution.
- [ ] Consider a concise player-guide reminder to review manually exported chat before sharing.
- [ ] If source-repository privacy is part of the launch scope, review tracked development documents/logs and Git history separately; release-file exclusion does not make the public repository private.


## Evidence and Limits
Evidence conclusions and scope are retained in this note; Git checkpoint e17ac19 retains the baseline addon contents. Successful raw logs and detailed transient scan reports were removed after their conclusions and scope were recorded here.

Defender was enabled; its installed signature timestamp was November 3, 2026. Non-remediating custom scans of the addon folder and 12 top-level release zips completed with exit 0 and no detections reported. No Defender settings were changed. Restricted-context status access failed; approved access worked.

Static checks covered selected credential patterns, sensitive filenames/paths, package contents, asset metadata, and relevant Lua APIs. They do not prove the absence of all secrets, exploitability, maliciously crafted assets, or vulnerabilities in dependencies/client parsers. Upstream dependency authenticity and Git history were not fully audited. No uploads to public scanning services, release publication/removal, or visibility changes were performed. A later authorized cleanup corrected the LICENSE heading to L's Tweeks and normalized its line endings to LF; license wording otherwise remains unchanged. The rebuilt zip matched all 153 current payload files and passed package verification and a fresh non-remediating Defender scan. Packaging stages exclusively in repository scratch and cleans normal runs on success or failure.

Recheck the actual artifact after any changes; this fingerprint applies only to the file named above. The directory-junction workflow is a development installation choice, not an added capability in the public release.
