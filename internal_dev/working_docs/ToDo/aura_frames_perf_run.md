# Aura Frames Performance Run
Reminder: collect a fresh in-game Aura Frames CPU profile using the improved profiler (per-row `cb_msps`/`cb_callsps` combat normalization plus a paste-ready `cpu-profile-run` metadata line in the report output).


## Open Items
- Setup is already in place: `LsTweeks.toc` has the temporary probe line and `addon_cpu_profile.lua` targets `aura_frames` only. Follow the `/lstprofile` flow in `cpu_profiles/profiling_workflow.md` (~60-100s sustained combat, note the Timer Tick setting).
- Paste the report into a session for capture in `af_cpu_profiles.md` and `analyze_af_cpu_profiles.ps1` comparison against the 2026-06-27 baseline (`update_auras` 6.50 ms/sec combat-normalized, "no new obvious cleanup target").
- Remove the temporary probe line from `LsTweeks.toc` when performance work closes.
