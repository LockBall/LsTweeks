# Performance Profiling Memory

Use this file for reusable in-game CPU profiling workflow. Keep raw run output in
`internal_dev/tests_tools/logs/` and keep module-specific conclusions in that
module's `proj_mem/*.md` file.


## Whole-Addon Profiler

- Main probe: `internal_dev/tests_tools/addon_cpu_profile.lua`.

- Load it from `LsTweeks.toc` after the normal addon files while profiling. Remove
  that temporary TOC line before release/package cleanup, unless the active review
  explicitly still needs more in-game runs.

- Select target modules by editing `PROFILE_TARGETS` near the top of
  `addon_cpu_profile.lua`, then `/reload`. Prefer one focused module target when
  comparing before/after changes; use broader targets only to find the next hot
  module.

- Supported targets are `core`, `settings`, `player_frame`, `sound_levels`,
  `skyriding_vigor`, and `aura_frames`.

- In-game command flow:
  1. `/lstprofile reset`
  2. `/lstprofile start`
  3. Exercise the relevant gameplay/settings path.
  4. `/lstprofile report 40`
  5. `/lstprofile stop`

- The profiler prints clear start/report/stop markers and tracks combat time.
  Prefer combat-normalized comparisons for combat-driven modules:
  `metric total ms / combat seconds`, plus `metric calls / combat seconds`.

- Do not sum nested rows as exclusive module totals. Wrapped functions can call
  other wrapped functions, so use rows to identify hot paths and compare the same
  metric across similar runs.

- Keep conditions comparable when measuring a change: same target set, same setting
  value under test, similar combat/activity duration, and the same profiler/tooling
  state. If a run has a false start or wrong setting, mark it noisy or discard it.

- Raw broad/focused run history lives in
  `internal_dev/tests_tools/logs/addon_cpu_profiles.md`.


## Validation After Profiling Changes

- Fast validation:
  `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1`

- Whitespace validation: `git diff --check`

- For Blizzard API or FrameXML-sensitive changes, also run the Ketho/LuaLS helper:
  `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/lua_checks/kethos/run_luals_ketho.ps1`
