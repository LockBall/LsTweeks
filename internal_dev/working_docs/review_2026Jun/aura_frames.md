# Aura Frames Performance Review

Active review items only. Move completed outcomes to `internal_dev/completed_features/aura_frames.md` or `internal_dev/working_docs/proj_mem/aura_frames.md`, then remove them from this file.

## Current CPU Baseline

Source: `internal_dev/tests_tools/logs/addon_cpu_profiles.md`

- 2026-06-22 broad run: Aura Frames remained the largest runtime cost, while Skyriding Vigor became a meaningful secondary target.
- 2026-06-22 Aura-only run: hot path matched the broad run, so Aura-specific profiling is stable enough to guide review.
- 2026-06-22 Aura-only post-OOC-fast-path run: per-call update/render costs stayed stable, but calls/sec and total ms/sec were lower; use this as the current comparison baseline before adding sub-step profiling.
- 2026-06-22 Aura-only update sub-step run: render was the largest `update_auras` sub-step, followed by scan/map fill. Config resolution was visible but smaller.
- 2026-06-22 Aura-only render timer-behavior cache run: `get_timer_behavior` calls and total time dropped substantially; render remains the top implementation target.
- 2026-06-23 Aura-only render display-signature run: render average improved modestly, but the run had external `scriptProfile` enabled. Treat as a small measured win and watch for stale icon visuals.
- 2026-06-23 Aura-only preset bucket direct render run: no clear broad-profile improvement. Targeted scan/map sub-step measurement later showed preset bucket copying below the report cutoff.
- 2026-06-23 Aura-only scan/map sub-step run: preset bucket copying was below the report cutoff; meaningful scan/map cost is unified scan, CDM map, and custom map work.
- 2026-06-23 Aura-only clean follow-up run: after removing the external `scriptProfile` warning, `render_aura_map` averaged 0.1770ms and `update_auras` averaged 0.4534ms. Use this as the cleaner post-item-7 comparison point.
- 2026-06-23 Aura-only category-scoped CDM hook refresh run: support-cost rows improved, especially `prepare_blizz_cdm_viewer`, but the core CDM map walk did not improve per call.
- 2026-06-23 Aura-only visible ticker return-state run: removed the redundant post-tick eligibility scan; `any_frame_needs_visible_icon_tick` no longer appeared in the report.
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

## Ordered CPU Work Queue

- [x] 1. Priority: High | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review `M.update_auras()` in `modules/aura_frames/af_core.lua` for stable per-frame work that can be skipped. Result: `update_auras()` still needs the current scan/render pipeline for enabled frames because live aura data, CDM child state, custom filter results, test previews, timer/bar metadata, display count, height, and ticker eligibility can change independently.

- [x] 2. Priority: Medium | Expected CPU Efficiency Impact: Low | Change Risk: Low - Add the low-risk OOC fade fast path. Result: `M.refresh_frame_ooc_fade()` now returns early when OOC fade is disabled, no fade timer/state is active, and the frame alpha is already at the tracked default.

- [x] 3. Priority: High | Expected CPU Efficiency Impact: High | Change Risk: Low - Add temporary profiler labels around `M.update_auras()` sub-steps. Result: sub-step profiling completed and temporary instrumentation removed. `update_auras.render` was about 311.485ms over 77.2s, `update_auras.scan_map` about 259.106ms, and `update_auras.config` about 72.361ms.

- [x] 4. Priority: High | Expected CPU Efficiency Impact: Medium | Change Risk: Low - Reduce repeated timer behavior work in `render_aura_map()`. Result: `render_aura_map()` now reuses one timer behavior for preset frames and caches timer behaviors by category for custom frames during each render. `get_timer_behavior` dropped from 6014 calls / 30.396ms in the sub-step run to 3042 calls / 16.480ms after caching. `render_aura_map` average dropped from 0.2049ms to 0.1952ms in a comparable Aura-only run.

- [x] 5. Priority: Medium | Expected CPU Efficiency Impact: Low | Change Risk: Low - Remove the temporary test-tool TOC line after profiling. Result: `LsTweeks.toc` no longer loads `internal_dev\tests_tools\addon_cpu_profile.lua` for normal use. During this active performance pass, the profiler line may be temporarily re-added and left loaded until final cleanup.

- [x] 6. Priority: High | Expected CPU Efficiency Impact: High | Change Risk: Medium - Review `M.render_aura_map()` in `modules/aura_frames/af_render.lua` for a display-signature skip. Result: unchanged safe display signatures now skip per-icon live timing, visual setters, timer/bar updates, and unused-icon cleanup. The skip is blocked by test previews, secret values, `scan_remaining`, unstable timing, and changed identity/visual/cooldown/stack/order data. Clean follow-up profiling showed `render_aura_map` at 0.1770ms average; watch for stale icon visuals.

- [x] 7. Priority: High | Expected CPU Efficiency Impact: High | Change Risk: Medium - Review scan/map fill in `M.update_auras()` and `modules/aura_frames/af_scan.lua`. Result: preset static/short/long/debuff frames now render directly from scan-built category buckets when no test preview mutation is needed, avoiding a per-frame wipe and per-entry copy. Targeted sub-step profiling showed preset bucket copying was below the report cutoff, so this is a safe cleanup rather than a meaningful CPU win. Meaningful scan/map cost is `unified_scan`, `add_cooldown_viewer_category_entries`, and `scan_custom_aura_map`.

- [x] 8. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review trigger-specific refresh routing. Result: hook-driven CDM refreshes now carry the child viewer category and queue only that CDM category when known; startup/settings/combat refreshes remain broad. Profiling showed a small support-cost win: `prepare_blizz_cdm_viewer` dropped from 14.877ms over 88.1s to 2.521ms over 61.1s, but `add_cooldown_viewer_category_entries` did not improve per call.

- [x] 9. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review custom aura scan reuse in `modules/aura_frames/af_scan.lua`. Result: no low-risk code change kept. `scan_custom_aura_map()` already caches the indexed aura walk by custom aura filter and short-threshold within a dirty batch, so same-filter custom frames reuse the expensive scan. Custom filter UI changes refresh only the affected custom frame. Narrowing custom scans from `UNIT_AURA` payloads remains higher risk because custom filters/modifiers, secret values, full updates, and threshold/category changes can invalidate the simple affected-aura path.

- [x] 10. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Review `M.tick_visible_icons()` and visible-icon ticker eligibility in `modules/aura_frames/af_core.lua`. Result: `tick_visible_icons()` now returns whether any visible icon still needs ticking, so the ticker callback avoids a second full `any_frame_needs_visible_icon_tick()` scan after every tick. Profiling confirmed `any_frame_needs_visible_icon_tick` no longer appeared in the report; `refresh_visible_icon_ticker` was only 1.516ms over 60.3s.

- [x] 11. Priority: High | Expected CPU Efficiency Impact: Medium | Change Risk: Low - Review-only pass for repeated `M.update_auras()` config reads. Result: no code change kept. Safe cache candidates exist for scalar/layout values read on every update (`bar_mode`, width, spacing, growth, max icons, tooltip flag, timer text/swipe booleans, sort mode, cooldown overlay state), but settings invalidation is not centralized enough yet. `setup_layout()` also re-resolves some of the same values, so a useful cache should be shared with layout setup rather than only inserted into `update_auras()`. Color tables remain separate because UI controls may mutate them in place.

- [x] 12. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Audit runtime config cache invalidation before implementing a cache. Result: a frame-local invalidation path is viable. Preset and custom frame setting panels already funnel common controls through shared update callbacks; profile load/reset refreshes each frame; module re-enable rebinds and refreshes frames; resize saves width then refreshes the frame; custom frame create/destroy already rebuilds or removes frame ownership. Item 13 should add a small helper that clears a frame runtime-config cache and layout cache, then call it from these existing refresh/update paths rather than adding a broad global cache.

- [ ] 13. Priority: Medium | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Implement a layout/static runtime config cache using frame-local invalidation. Candidate values: `bar_mode`, width, spacing, growth, max icons, tooltip flag, timer text/swipe booleans, sort mode, and cooldown overlay state. Share resolved values with `setup_layout()` where practical. Avoid color tables in this pass.

- [ ] 14. Priority: Medium | Expected CPU Efficiency Impact: Low | Change Risk: Medium - Review color/runtime value caching separately. Color tables can be mutated in place by UI controls, so only cache copied scalar color components if invalidation is clear and profiling still justifies it.

- [ ] 15. Priority: Low | Expected CPU Efficiency Impact: Medium | Change Risk: Medium - Test update-frequency changes only after the structural wins above. `aura_visible_icon_tick` can stay around 0.2s if visual smoothness is acceptable; `aura_event_bucket` should be tested gradually, such as 0.15s then 0.2s, because increasing it reduces scan/render bursts at the cost of visible aura-update latency.

- [ ] 16. Priority: Low | Expected CPU Efficiency Impact: Low | Change Risk: High - Revisit CDM entry reads only if a narrow safe change is visible. New/public `C_CooldownViewer` APIs still do not appear to expose live rendered child order, active aura instance IDs, per-item active state, or cooldown widget timing. Keep the Blizzard child read/hook path unless Blizzard adds public live-state APIs.

## Guardrails

- Preserve Aura Frames behavior before optimizing. The current absolute cost is modest, so avoid invasive rewrites without a clear measured win.
- Use `internal_dev/tests_tools/addon_cpu_profile.lua` with only `PROFILE_TARGETS.aura_frames = true` for comparable follow-up runs.
- If changing duration/timer paths, cross-check `internal_dev/tests_tools/logs/aura_frames_cpu_profiles.md`; previous data showed `C_UnitAuras.GetAuraDuration` was not a meaningful hotspot.
- CDM-backed categories still need live Blizzard viewer child state for active aura display and cooldown fallback behavior.
- Do not pursue public `C_CooldownViewer` API replacement as a performance shortcut unless new API review proves it exposes rendered live child state, not only static/category/settings data.
- Module re-enable must continue to mark the aura scan dirty, restart runtime services, and refresh/rebind existing frames.
