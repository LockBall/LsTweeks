A few things needed correction:

1) Reviewed: API refresh network failure. The same read-only Git request failed in the restricted context with HTTP_PROXY/HTTPS_PROXY/ALL_PROXY targeting 127.0.0.1:9, and succeeded in the approved context with those variables absent; no matching Git proxy configuration was reported. This establishes a context-dependent proxy restriction, not a GitHub outage or updater defect; the host's injection implementation was not investigated.

    - Persistent prevention added to `F:\from_git\dev_foundation\environments\powershell\ps_shell_setup.md`, section `Network Access in Restricted Tool Hosts`, with evidence in `internal_dev/memory/extraction_provenance.md`, section `Restricted Network Execution Lesson`. Use the approved network context from the outset when active policy explicitly restricts known network work; preserve normal local execution and do not bypass proxy/security controls. Foundation changes are uncommitted; add the commit reference here after committing. No workstation configuration repair was needed to complete the refresh.

2) Reviewed: the interface-mismatch stop is intentional. The guidance was too narrow: the override also supports an explicitly requested review of a newer live patch, after confirming the intended channel/build. Foundation `environments/wow/wow_addons.md` and both updater diagnostics now explain this; local adoption is recorded in `internal_dev/tests_tools/tools_notes.md`. Do not bump the TOC just to prepare references, make the override a startup default, or trust annotations left stale after a partial source update.

    - Foundation evidence is in `internal_dev/memory/extraction_provenance.md`, section `WoW Interface Mismatch Review Lesson`. Default mismatch rejection and origin/branch/dirty-cache checks are unchanged. Both local-origin updater suites passed all 7 cases; no live refresh was repeated. These changes are uncommitted; add the foundation commit reference after committing.
    - Verification environment incident: both suites initially failed because Git sh.exe could not create a signal pipe (Win32 error 5) in the restricted context. Both passed in the approved context. This is separate from item 1's proxy failure: these tests clone local fixtures and use no internet. The precise tool-host cause remains unverified; no machine configuration was changed.

3) I made a few command-format mistakes with section-reader arguments and Windows wildcard paths. Corrected commands worked.

4) Some large outputs were truncated; I followed up with narrower reads.

5) The most useful improvement now is a repeatable release routine: source/API review, version and changelog update, automated checks, then a short in-game acceptance pass before publishing. We now have the checklist and documentation to support that.
