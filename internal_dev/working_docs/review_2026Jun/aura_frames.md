# Aura Frames Performance Review

Active review items only. Move completed outcomes to `internal_dev/completed_features/aura_frames.md` or `internal_dev/working_docs/proj_mem/aura_frames.md`, then remove them from this file.

## Current CPU Baseline

Source: `internal_dev/tests_tools/logs/addon_cpu_profiles.md`

- 2026-06-22 broad run: Aura Frames remained the largest runtime cost, while Skyriding Vigor became a meaningful secondary target.
- 2026-06-22 Aura-only run: hot path matched the broad run, so Aura-specific profiling is stable enough to guide review.
- Profiling wraps addon-owned functions only. Rows are inclusive when wrapped functions call other wrapped functions, so do not sum rows as exclusive module totals.

Aura-only run, 90.6s:

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1509 | 674.741 | 0.4471 | 3.580 |
| `aura_frames.render_aura_map` | 1509 | 268.251 | 0.1778 | 1.287 |
| `aura_frames.tick_visible_icons` | 836 | 247.537 | 0.2961 | 1.273 |
| `aura_frames.unified_scan` | 138 | 85.381 | 0.6187 | 2.910 |
| `aura_frames.add_cooldown_viewer_category_entries` | 944 | 85.081 | 0.0901 | 0.517 |
| `aura_frames.set_timer_text` | 13780 | 80.167 | 0.0058 | 0.616 |
| `aura_frames.scan_custom_aura_map` | 113 | 56.953 | 0.5040 | 1.256 |

## Review Targets

1. Priority: High | Impact: Medium | Change Risk: Medium - Review `M.update_auras()` in `modules/aura_frames/af_core.lua` for stable per-frame work that can be skipped when activity, layout inputs, and display data are unchanged. Avoid changing combat/positioning guards without in-game validation.

2. Priority: High | Impact: Medium | Change Risk: Medium - Review `M.render_aura_map()` in `modules/aura_frames/af_render.lua` for redundant visual setters or metadata writes. Prefer guarded setters or cached signatures only where they remove measured repeated work without breaking live timer/bar updates.

3. Priority: Medium | Impact: Medium | Change Risk: Medium - Review `M.tick_visible_icons()` and visible-icon ticker eligibility in `modules/aura_frames/af_core.lua`. Confirm the ticker only runs for displayed icons that need live timer/bar/preview/CDM cooldown updates, and look for cheap early exits before per-icon work.

4. Priority: Medium | Impact: Medium | Change Risk: Medium - Review custom aura scan reuse in `modules/aura_frames/af_scan.lua`. `scan_custom_aura_map()` is a smaller but visible cost; check whether unchanged custom filters and limits can reuse or extend existing cache safely.

5. Priority: Medium | Impact: Medium | Change Risk: High - Revisit CDM entry reads only if a narrow safe change is visible. `add_cooldown_viewer_category_entries()` remains a recurring cost, but prior review found the live Blizzard child walk necessary. Do not replace child reads/hooks with public `C_CooldownViewer` APIs.

## Guardrails

- Preserve Aura Frames behavior before optimizing. The current absolute cost is modest, so avoid invasive rewrites without a clear measured win.
- Use `internal_dev/tests_tools/addon_cpu_profile.lua` with only `PROFILE_TARGETS.aura_frames = true` for comparable follow-up runs.
- If changing duration/timer paths, cross-check `internal_dev/tests_tools/logs/aura_frames_cpu_profiles.md`; previous data showed `C_UnitAuras.GetAuraDuration` was not a meaningful hotspot.
- CDM-backed categories still need live Blizzard viewer child state for active aura display and cooldown fallback behavior.
- Module re-enable must continue to mark the aura scan dirty, restart runtime services, and refresh/rebind existing frames.
