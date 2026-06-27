# Whole-Addon CPU Profiles

Long-term capture for broad LsTweeks in-game profiling runs. Use
`internal_dev/tests_tools/addon_cpu_profile.lua` when looking for true addon hot
paths across modules.

This profiler wraps addon-owned functions only. Do not wrap Blizzard/global APIs
such as `UnitPower`, `UnitHealthPercent`, or `C_UnitAuras` from this broad probe;
that can taint Blizzard unit-frame execution when secret values are involved.


## Table of Contents
- [How To Collect](#how-to-collect)
- [Archived Broad Run Summary](#archived-broad-run-summary)
- [Runs](#runs)


## How To Collect

1. Temporarily load `internal_dev/tests_tools/addon_cpu_profile.lua` after the
   normal addon files in `LsTweeks.toc`.

2. Set `PROFILE_TARGETS` in `addon_cpu_profile.lua`, then `/reload`.

3. Run `/lstprofile reset` and `/lstprofile start`.

4. Exercise normal gameplay and settings flows for 2-3 minutes: aura updates,
   CDM updates, Skyriding Vigor visibility, Sound Levels previews, Fishing Focus
   if relevant, and opening/changing addon settings.

5. Run `/lstprofile report 40`, copy the output here, then run `/lstprofile stop`.

6. Remove the temporary TOC line before release cleanup. While an active profiling
   review is still in progress, keeping the temporary load staged is acceptable.

## Archived Broad Run Summary

### 2026-06-06 Series

The detailed June 6 broad tables were condensed because their useful decisions
are now captured in focused module profile files and durable project memory. Keep
this section as the broad profiling trail rather than a full row-by-row archive.

Runs in this series:

- **Initial broad baseline, 213.3s:** Aura Frames dominated broad runtime cost.
  `aura_frames.update_auras`, visible-icon ticking, `render_aura_map`, timer text,
  and CDM entry reads were the primary hot paths. Skyriding Vigor was visible but
  smaller, and Sound Levels only appeared on rare Fishing Focus transitions.

- **Runtime aliases at 0.2s, 146.9s:** Reducing ticker cadence improved the direct
  visible-icon ticker path. `tick_visible_icons` and `set_timer_text` improved,
  but the broader update/render rates were not comparable enough to generalize
  every alias change.

- **Aura update-path cleanup, 62.1s:** Targeted cleanup reduced repeated
  ticker-maintenance work and helped OOC fade context reuse. The run had higher
  visible-icon ticker pressure, so some rows were intentionally treated as noisy.

- **Aura render-path cleanup, 87.7s:** Precomputed timer behavior reuse, cooldown
  overlay signature guards, guarded bar min/max writes, and count-text anchor
  caching improved the render helper chain. `render_aura_map`, `set_timer_text`,
  `get_timer_behavior`, and `normalize_timer_category` all improved enough to
  keep the render cleanup.

- **Render/CDM comparison baselines, 69.9s and 101.6s:** Average call costs stayed
  stable after render cleanup. Follow-up review found no safe high-value rewrite
  for `add_cooldown_viewer_category_entries`; the remaining cost was mostly
  necessary live reads of Blizzard CDM child state. Aura performance target notes
  live in `internal_dev/working_docs/review_2026Jun/aura_frames_performance_review.md`.

Conclusion: The June 6 broad series established Aura Frames as the primary addon
runtime target and led to focused Aura profiling. It also established the
principle of using broad runs to choose modules, then moving detailed helper
analysis into module-specific files.

## Runs

### 2026-06-22

Context: 181.8s broad addon run with all profiler targets enabled after recent
runtime/status/Aura Frames changes. Profiler wrapped addon-owned functions only.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1769 | 799.555 | 0.4520 | 2.458 |
| `aura_frames.tick_visible_icons` | 1666 | 408.563 | 0.2452 | 0.798 |
| `skyriding_vigor.refresh` | 788 | 349.067 | 0.4430 | 6.016 |
| `aura_frames.render_aura_map` | 1769 | 309.617 | 0.1750 | 1.071 |
| `skyriding_vigor.set_slot_state` | 1597 | 262.585 | 0.1644 | 4.466 |
| `skyriding_vigor.get_bar_style` | 3993 | 208.223 | 0.0521 | 1.419 |
| `skyriding_vigor.update_filling_slot_progress` | 1137 | 203.285 | 0.1788 | 1.363 |
| `skyriding_vigor.get_frame_atlas` | 1597 | 109.091 | 0.0683 | 4.027 |
| `aura_frames.unified_scan` | 158 | 98.745 | 0.6250 | 1.760 |
| `aura_frames.add_cooldown_viewer_category_entries` | 1084 | 98.301 | 0.0907 | 0.447 |
| `aura_frames.set_timer_text` | 16192 | 92.648 | 0.0057 | 0.198 |
| `skyriding_vigor.get_style_layout_table` | 1597 | 83.790 | 0.0525 | 1.515 |
| `aura_frames.scan_custom_aura_map` | 137 | 63.411 | 0.4629 | 1.542 |
| `skyriding_vigor.get_valid_bar_style_key` | 1597 | 62.467 | 0.0391 | 1.493 |
| `aura_frames.get_frame_activity_state` | 6396 | 49.863 | 0.0078 | 0.191 |
| `skyriding_vigor.get_spark_atlas` | 4236 | 49.285 | 0.0116 | 2.221 |
| `aura_frames.is_runtime_enabled` | 3479 | 40.884 | 0.0118 | 0.215 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 1666 | 39.794 | 0.0239 | 0.109 |
| `aura_frames.refresh_frame_ooc_fade` | 1769 | 37.196 | 0.0210 | 0.407 |
| `aura_frames.get_setting` | 16871 | 35.551 | 0.0021 | 0.105 |
| `aura_frames.get_timer_behavior` | 6513 | 31.993 | 0.0049 | 0.358 |
| `addon.is_module_enabled` | 4313 | 29.337 | 0.0068 | 0.054 |
| `aura_frames.frame_needs_visible_icon_tick` | 4202 | 28.557 | 0.0068 | 0.098 |
| `skyriding_vigor.get_charge_info` | 788 | 23.684 | 0.0301 | 0.167 |
| `aura_frames.is_timer_text_enabled` | 1769 | 21.341 | 0.0121 | 0.275 |

Conclusion: Aura Frames remains the largest broad runtime cost, with the
inclusive `update_auras` path around 4.4ms/s and visible-icon ticking around
2.2ms/s in this run. Skyriding Vigor became a meaningful secondary target:
`refresh` averaged 0.443ms/call with visible nested costs in style/atlas lookup
and filling-slot updates. Because the profiler wraps nested addon functions, do
not sum rows as exclusive module totals; use them to choose the next focused
profile. Follow-up focused Aura and Skyriding runs belong in `af_cpu_profiles.md`
and `sv_cpu_profiles.md`.
