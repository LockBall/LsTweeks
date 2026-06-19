# Player Frame Review - 2026 Jun

Rating format: `Priority` is review order, `Impact` is expected addon/user impact if the issue is real, and `Change Risk` is the risk of making changes in that area.

1. Priority: High | Impact: High | Change Risk: High - Health fade depends on pass-through `UnitHealthPercent("player", true, curve)` and avoids arithmetic on secret health values. Preserve this pattern; do not rewrite to direct health comparisons.

2. Priority: Medium | Impact: Medium | Change Risk: Medium - `pf_fade.lua` installs the `PlayerFrame:HookScript("OnShow")` hook only when fade is enabled, which matches project memory. Verify disable/re-enable cycles restore alpha and do not leave pending timers.

3. Priority: Medium | Impact: Medium | Change Risk: Low - `pf_main.lua` unregisters fade events when OOC fade is disabled; test toggling fade while already out of combat and while entering/exiting combat.
