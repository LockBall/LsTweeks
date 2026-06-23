# Aura Frames Performance Review

Active review items only. Move completed outcomes to `internal_dev/completed_features/aura_frames.md` or `internal_dev/working_docs/proj_mem/aura_frames.md`, then remove them from this file.

## Current CPU Baseline

Source: `internal_dev/tests_tools/logs/addon_cpu_profiles.md`

- 2026-06-22 broad run: Aura Frames remained the largest runtime cost, while Skyriding Vigor became a meaningful secondary target.
- 2026-06-22 Aura-only run: hot path matched the broad run, so Aura-specific profiling is stable enough to guide review.
- 2026-06-22 Aura-only post-OOC-fast-path run: per-call update/render costs stayed stable, but calls/sec and total ms/sec were lower; use this as the current comparison baseline before adding sub-step profiling.
- 2026-06-22 Aura-only update sub-step run: render was the largest `update_auras` sub-step, followed by scan/map fill. Config resolution was visible but smaller.
- 2026-06-22 Aura-only render timer-behavior cache run: `get_timer_behavior` calls and total time dropped substantially; render remains the top implementation target.
- Profiling wraps addon-owned functions only. Rows are inclusive when wrapped functions call other wrapped functions, so do not sum rows as exclusive module totals.

Aura-only post-OOC-fast-path run, 90.1s:

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1309 | 590.951 | 0.4515 | 2.645 |
| `aura_frames.render_aura_map` | 1309 | 231.311 | 0.1767 | 1.463 |
| `aura_frames.tick_visible_icons` | 833 | 216.191 | 0.2595 | 1.181 |
| `aura_frames.add_cooldown_viewer_category_entries` | 824 | 79.223 | 0.0961 | 0.528 |
| `aura_frames.unified_scan` | 111 | 66.405 | 0.5982 | 1.508 |
| `aura_frames.set_timer_text` | 10583 | 62.127 | 0.0059 | 0.939 |
| `aura_frames.scan_custom_aura_map` | 97 | 48.777 | 0.5029 | 1.460 |

## Completed This Pass

- 2026-06-22 update-path review: `M.update_auras()` still needs the current scan/render pipeline for enabled frames because live aura data, CDM child state, custom filter results, test previews, timer/bar metadata, display count, height, and ticker eligibility can change independently.

- Low-risk change kept: `M.refresh_frame_ooc_fade()` now returns early when OOC fade is disabled, no fade timer/state is active, and the frame alpha is already at the tracked default. Reprofile Aura-only and compare `refresh_frame_ooc_fade`, `update_auras`, and `get_setting` rates before pursuing more update-path work.

- Discrepancy fixed: `LsTweeks.toc` still loaded temporary `internal_dev\tests_tools\addon_cpu_profile.lua`; the profiler line was removed after profiling as required by the workflow.

- 2026-06-22 sub-step profiling completed and temporary instrumentation removed. `update_auras.render` was about 311.485ms over 77.2s, `update_auras.scan_map` about 259.106ms, and `update_auras.config` about 72.361ms.

- Render first pass: `render_aura_map()` now reuses one timer behavior for preset frames and caches timer behaviors by category for custom frames during each render. Reprofile Aura-only and compare `get_timer_behavior`, `render_aura_map`, `set_timer_text`, and `update_auras.render` if temporary sub-step labels are re-added.

- Render first pass measured: `get_timer_behavior` dropped from 6014 calls / 30.396ms in the sub-step run to 3042 calls / 16.480ms after caching. `render_aura_map` average dropped from 0.2049ms to 0.1952ms in a comparable Aura-only run.

## Ordered CPU Work Queue

1. Priority: High | Expected CPU Efficiency Impact: High | Change Risk: Medium - Review `M.render_aura_map()` in `modules/aura_frames/af_render.lua` for a display-signature skip. Timer text and bar progress already have `tick_visible_icons()`, so an unchanged ordered display list may not need a full render pass. A safe signature must include ordered entry identity, count/stack text, spell ID/icon/name identity, bar/icon mode, cooldown/grey state, max limit, sort mode, and CDM order. Treat secret values, test previews, CDM active-to-cooldown transitions, and stack-count changes as skip blockers.

2. Priority: High | Expected CPU Efficiency Impact: High | Change Risk: Medium - Review scan/map fill in `M.update_auras()` and `modules/aura_frames/af_scan.lua`. The sub-step profile showed scan/map fill as the second-largest update cost. Look for safe map-copy reductions, CDM/custom scan narrowing, and trigger-specific refresh routing before changing scan semantics.

3. Priority: High | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review a per-frame resolved runtime config cache for stable settings used by `M.update_auras()`: bar mode, width, spacing, growth, max icons, colors, tooltip, timer flags, background, fade settings, sort mode, and cooldown overlay state. Invalidate conservatively on frame setting changes, profile load/reset, module re-enable, custom frame edits, width/drag/resize changes, and global Aura Frames settings changes. This targets repeated `get_setting`, `get_bar_bg_color`, `is_timer_text_enabled`, and layout-decision work, but should follow render/scan work based on the sub-step profile.

4. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review trigger-specific refresh routing. CDM hook refreshes should refresh only CDM-backed frames; custom filter changes should refresh the affected custom frame; settings/layout changes should refresh affected frames only. Helpful aura payloads can still require static/short/long group refresh because classification can move between buckets; harmful-only payloads may route to debuff/custom harmful frames when payload data is reliable.

5. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review `M.tick_visible_icons()` and visible-icon ticker eligibility in `modules/aura_frames/af_core.lua`. Confirm the ticker only runs for displayed icons that need live timer/bar/preview/CDM cooldown updates, and look for cheap early exits before per-icon work. Do this after render/scan work unless a future profile shows ticker maintenance is the clearer win.

6. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review custom aura scan reuse in `modules/aura_frames/af_scan.lua`. `scan_custom_aura_map()` is smaller than render/ticker but visible in the 2026-06-22 baseline. Check whether unchanged custom filters and reliable UNIT_AURA payloads can skip or narrow custom rescans; fall back to current cache behavior on full updates, ambiguous secret data, or filter/threshold/limit changes.

7. Priority: Low | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Test update-frequency changes only after the structural wins above. `aura_visible_icon_tick` can stay around 0.2s if visual smoothness is acceptable; `aura_event_bucket` should be tested gradually, such as 0.15s then 0.2s, because increasing it reduces scan/render bursts at the cost of visible aura-update latency.

8. Priority: Low | Expected CPU Efficiency Impact: Low | Change Risk: High - Revisit CDM entry reads only if a narrow safe change is visible. New/public `C_CooldownViewer` APIs still do not appear to expose live rendered child order, active aura instance IDs, per-item active state, or cooldown widget timing. Keep the Blizzard child read/hook path unless Blizzard adds public live-state APIs.

## Guardrails

- Preserve Aura Frames behavior before optimizing. The current absolute cost is modest, so avoid invasive rewrites without a clear measured win.
- Use `internal_dev/tests_tools/addon_cpu_profile.lua` with only `PROFILE_TARGETS.aura_frames = true` for comparable follow-up runs.
- If changing duration/timer paths, cross-check `internal_dev/tests_tools/logs/aura_frames_cpu_profiles.md`; previous data showed `C_UnitAuras.GetAuraDuration` was not a meaningful hotspot.
- CDM-backed categories still need live Blizzard viewer child state for active aura display and cooldown fallback behavior.
- Do not pursue public `C_CooldownViewer` API replacement as a performance shortcut unless new API review proves it exposes rendered live child state, not only static/category/settings data.
- Module re-enable must continue to mark the aura scan dirty, restart runtime services, and refresh/rebind existing frames.
