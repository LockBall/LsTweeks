# Aura Frames Performance Review

## Status

No active Aura Frames performance work is required from the current Skyriding
review pass. Keep this file as the restart point only if Aura Frames profiling is
reopened.

Durable Aura conclusions live in `internal_dev/working_docs/proj_mem/aura_frames.md`.
Focused run history lives in `internal_dev/tests_tools/cpu_profiles/af_cpu_profiles.md`.


## Dormant Targets

- Do not skip the whole `update_auras()` path without a new narrow proof. Live
  aura data, CDM child state, custom filter results, test previews, timer/bar
  metadata, display count, height, and ticker eligibility can change
  independently.

- If render cost regresses, start with focused profiles around
  `render_aura_map()` and the conservative display-signature skip. Stable visual
  setters are already guarded where practical; timer countdown and bar progress
  must remain live.

- If scan/map cost becomes the target again, focus on `unified_scan`,
  `add_cooldown_viewer_category_entries`, and `scan_custom_aura_map`. Preset
  bucket copying was below the focused-profile report cutoff and should not be
  treated as the next meaningful CPU target.

- Custom-scan narrowing from `UNIT_AURA` payloads remains higher risk because
  custom filters/modifiers, secret values, full updates, and threshold/category
  changes can invalidate simple affected-aura routing.

- Avoid central dispatcher or invasive CDM rewrites unless a focused profile
  shows a material regression or a concrete behavior issue gives a narrower
  target.


## Profiling Notes

- Use focused Aura CPU profiles for helper-level decisions. Broad addon profiles
  can identify module targets, but `af_cpu_profiles.md` captures detailed Aura
  timings.

- Apply `performance_profiling.md`'s review checklist before changing hot paths:
  identify cadence, setup work, mutability boundaries, and the intended
  before/after profile shape.
