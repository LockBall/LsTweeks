# Performance Profiling Workflow
Use this file for reusable in-game CPU profiling workflow. Keep raw run output in
`internal_dev/tests_tools/cpu_profiles/` and keep module-specific conclusions
in that module's memory file under `internal_dev/working_docs/proj_mem/modules/`.


## Table of Contents
- [Whole-Addon Profiler](#whole-addon-profiler)
- [Optimization Lessons](#optimization-lessons)
- [Performance Review Checklist](#performance-review-checklist)
- [Validation After Profiling Changes](#validation-after-profiling-changes)


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
- Raw CPU run history is split by scope under
  `internal_dev/tests_tools/cpu_profiles/`: use `addon_cpu_profiles.md` for
  broad multi-module runs, and module-prefixed files such as
  `af_cpu_profiles.md` or `sv_cpu_profiles.md` for focused runs.


## Optimization Lessons
- Separate high-frequency runtime paths from setup/configuration work. If a path
  runs every frame, every tick, or many times per second, it should reuse values
  prepared by a lower-frequency refresh path where the module's behavior allows
  it.
- Do not assume a helper is harmless just because each call is cheap. Repeated
  style lookup, validation, layout-table lookup, atlas resolution, DB access, and
  similar setup work can become visible when multiplied by progress/ticker/event
  cadence.
- Prefer a single authoritative setup path over duplicated cheap lookups. Resolve
  style/config/state once in a refresh/render pass, then pass the resolved values
  or stamp them onto the object that the hot path already owns.
- Make mutability boundaries explicit before caching or reusing state. Skyriding
  Vigor improved safely only after real in-flight settings edits were rejected
  while Fill Test stayed editable only as a controlled simulated state that stops
  when real flight starts. Other modules should identify their equivalent "state
  is stable during this hot loop" boundary before adding reuse.
- Use profiling to verify the intended shape, not just total time. The Skyriding
  Vigor win was confirmed because `get_render_context` and style/atlas helpers
  dropped from progress-tick cadence to refresh cadence.
- Avoid broad persistent caches until there is a concrete invalidation contract.
  Pass-local context or object-local render state is often enough and has a
  smaller correctness surface.


## Performance Review Checklist
- Does the module have an always-running or active-only ticker?
- Does the hot path repeatedly call settings, style, profile, default, or
  normalization helpers?
- Are GUI/control sync calls happening during runtime refresh when nothing
  user-facing can change?
- Can a refresh pass compute context once and pass it through child updates?
- Can per-frame, per-slot, or per-button state hold the resolved values the hot
  path needs?
- Is there a clear rule for when settings or profile edits are allowed while the
  runtime path is active?
- Did the profile confirm helper calls dropped to the intended cadence?


## Validation After Profiling Changes
- Run `fast validation`.
- For Blizzard API or FrameXML-sensitive changes, also run the Ketho/LuaLS helper.
- Copy/paste commands live in `code_map.md` `## Fast Commands`.
