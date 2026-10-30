A few things needed correction:

- Reviewed: API refresh network failure. The same read-only Git request failed in the restricted context with HTTP_PROXY/HTTPS_PROXY/ALL_PROXY targeting 127.0.0.1:9, and succeeded in the approved context with those variables absent; no matching Git proxy configuration was reported. This establishes a context-dependent proxy restriction, not a GitHub outage or updater defect; the host's injection implementation was not investigated.

- Persistent prevention added to `F:\from_git\dev_foundation\environments\powershell\ps_shell_setup.md`, section `Network Access in Restricted Tool Hosts`, with evidence in `internal_dev/memory/extraction_provenance.md`, section `Restricted Network Execution Lesson`. Use the approved network context from the outset when active policy explicitly restricts known network work; preserve normal local execution and do not bypass proxy/security controls. Foundation changes are uncommitted; add the commit reference here after committing. No workstation configuration repair was needed to complete the refresh.

- The updater correctly stopped when it found the newer WoW interface. Its research override let me complete the review before updating the TOC.

- I made a few command-format mistakes with section-reader arguments and Windows wildcard paths. Corrected commands worked.

- Some large outputs were truncated; I followed up with narrower reads.

- The most useful improvement now is a repeatable release routine: source/API review, version and changelog update, automated checks, then a short in-game acceptance pass before publishing. We now have the checklist and documentation to support that.
