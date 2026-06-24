# Whole-Addon CPU Profiles

Long-term capture for broad LsTweeks in-game profiling runs. Use
`internal_dev/tests_tools/addon_cpu_profile.lua` when looking for true addon hot paths
across modules.

This profiler wraps addon-owned functions only. Do not wrap Blizzard/global APIs
such as `UnitPower`, `UnitHealthPercent`, or `C_UnitAuras` from this broad probe;
that can taint Blizzard unit-frame execution when secret values are involved.

## How To Collect

1. Temporarily load `internal_dev/tests_tools/addon_cpu_profile.lua` after
   `modules/aura_frames/af_main.lua` in `LsTweeks.toc`.
2. `/reload`.
3. Run `/lstprofile reset`, then `/lstprofile start aura` for an Aura Frames-only run.
4. Exercise normal gameplay and settings flows for 2-3 minutes:
   aura updates, CDM updates, Skyriding Vigor visibility, Sound Levels previews,
   Fishing Focus if relevant, and opening/changing addon settings.
5. Run `/lstprofile report 40`, copy the output here, then run `/lstprofile stop`.
6. Remove the temporary TOC line, run `check_fast.ps1` and `git diff --check`, then `/reload`.

## Runs

### 2026-06-06

Context: 213.3s broad addon run in Dornogal/Isle of Dorn with Aura Frames/CDM,
Skyriding Vigor, and Fishing Focus activity. Profiler wrapped addon-owned functions
only.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1598 | 521.483 | 0.3263 | 4.038 |
| `aura_frames.tick_visible_icons` | 1700 | 208.257 | 0.1225 | 1.632 |
| `aura_frames.render_aura_map` | 1598 | 163.138 | 0.1021 | 0.702 |
| `aura_frames.set_timer_text` | 5202 | 84.356 | 0.0162 | 1.399 |
| `skyriding_vigor.refresh` | 805 | 72.801 | 0.0904 | 0.298 |
| `aura_frames.add_cooldown_viewer_category_entries` | 1028 | 68.620 | 0.0668 | 0.396 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 3298 | 61.060 | 0.0185 | 0.386 |
| `aura_frames.unified_scan` | 128 | 60.017 | 0.4689 | 1.845 |
| `aura_frames.get_frame_activity_state` | 6419 | 55.846 | 0.0087 | 0.217 |
| `aura_frames.refresh_frame_ooc_fade` | 1600 | 45.836 | 0.0286 | 0.243 |
| `aura_frames.frame_needs_visible_icon_tick` | 8253 | 43.749 | 0.0053 | 0.258 |
| `aura_frames.get_timer_behavior` | 6800 | 39.056 | 0.0057 | 0.084 |
| `aura_frames.refresh_visible_icon_ticker` | 1598 | 37.114 | 0.0232 | 0.411 |
| `aura_frames.get_setting` | 15277 | 26.286 | 0.0017 | 0.066 |
| `aura_frames.normalize_timer_category` | 8398 | 22.745 | 0.0027 | 0.075 |
| `aura_frames.prepare_blizz_cdm_viewer` | 1028 | 18.565 | 0.0181 | 0.161 |
| `aura_frames.is_timer_text_enabled` | 1598 | 17.168 | 0.0107 | 0.059 |
| `aura_frames.get_frame_config_db` | 8021 | 11.249 | 0.0014 | 0.054 |
| `aura_frames.get_bar_bg_color` | 1598 | 9.964 | 0.0062 | 0.072 |
| `aura_frames.update_blizz_cdm_visibility` | 820 | 9.119 | 0.0111 | 0.072 |
| `aura_frames.mark_aura_scan_dirty` | 1119 | 7.725 | 0.0069 | 0.068 |
| `skyriding_vigor.set_slot_visible` | 3078 | 7.064 | 0.0023 | 0.049 |
| `skyriding_vigor.set_slot_state` | 3078 | 7.039 | 0.0023 | 0.128 |
| `aura_frames.get_frame_position_table` | 1039 | 6.342 | 0.0061 | 3.664 |
| `aura_frames.merge_aura_info` | 1035 | 4.981 | 0.0048 | 0.071 |
| `aura_frames.get_cdm_viewer_frame` | 3216 | 4.556 | 0.0014 | 0.042 |
| `skyriding_vigor.ensure_frame` | 1610 | 4.119 | 0.0026 | 0.042 |
| `skyriding_vigor.set_move_mode` | 805 | 3.764 | 0.0047 | 0.047 |
| `aura_frames.scan_custom_aura_map` | 114 | 3.723 | 0.0327 | 0.117 |
| `sound_levels.restore_fishing_focus` | 3 | 3.396 | 1.1320 | 1.282 |
| `sound_levels.apply_fishing_focus` | 3 | 3.222 | 1.0740 | 1.183 |
| `aura_frames.ensure_blizz_cdm_viewer_always_visible` | 684 | 2.814 | 0.0041 | 0.027 |
| `aura_frames.cdm_category_needs_viewer` | 136 | 2.653 | 0.0195 | 0.067 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1247 | 2.251 | 0.0018 | 0.063 |
| `aura_frames.uses_cooldown_icon_overlay` | 1598 | 2.181 | 0.0014 | 0.038 |
| `aura_frames.update_all_blizz_cdm_visibility` | 34 | 2.021 | 0.0595 | 0.082 |
| `aura_frames.ensure_visible_icon_ticker` | 1598 | 1.764 | 0.0011 | 0.015 |
| `aura_frames.ensure_blizz_cdm_loaded` | 1504 | 1.725 | 0.0011 | 0.025 |
| `player_frame.get_clamped_fade_value` | 336 | 1.507 | 0.0045 | 0.182 |
| `aura_frames.clear_custom_aura_scan_cache` | 1119 | 1.478 | 0.0013 | 0.042 |

Conclusion: The broad profile points to Aura Frames as the main runtime cost,
especially the inclusive `update_auras` path, visible-icon ticker, rendering, and
CDM entry reads. Absolute cost is still modest: the top inclusive function averaged
about 2.45ms per second over this run. Skyriding Vigor refresh was visible but small,
and Sound Levels only appeared on rare Fishing Focus transitions.

### 2026-06-06, Runtime Aliases At 0.2s

Context: 146.9s broad addon run after setting `aura_event_bucket`,
`aura_visible_icon_tick`, `aura_hover_check`, `player_frame_fade_tick`, and
`skyriding_vigor_tick` to `addon.UPDATE_INTERVALS.fifth_sec`.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1466 | 482.042 | 0.3288 | 1.782 |
| `aura_frames.render_aura_map` | 1466 | 152.382 | 0.1039 | 0.544 |
| `aura_frames.tick_visible_icons` | 708 | 88.737 | 0.1253 | 0.471 |
| `aura_frames.add_cooldown_viewer_category_entries` | 1016 | 65.386 | 0.0644 | 0.435 |
| `aura_frames.unified_scan` | 118 | 54.851 | 0.4648 | 1.022 |
| `aura_frames.get_frame_activity_state` | 5954 | 50.756 | 0.0085 | 1.140 |
| `skyriding_vigor.refresh` | 618 | 47.038 | 0.0761 | 0.459 |
| `aura_frames.refresh_frame_ooc_fade` | 1468 | 43.809 | 0.0298 | 1.163 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 2174 | 40.631 | 0.0187 | 0.130 |
| `aura_frames.set_timer_text` | 2761 | 40.370 | 0.0146 | 0.151 |
| `aura_frames.refresh_visible_icon_ticker` | 1466 | 33.812 | 0.0231 | 0.138 |
| `aura_frames.frame_needs_visible_icon_tick` | 5500 | 29.261 | 0.0053 | 0.111 |
| `aura_frames.get_setting` | 14056 | 23.653 | 0.0017 | 0.095 |
| `aura_frames.get_timer_behavior` | 4227 | 20.036 | 0.0047 | 0.061 |
| `aura_frames.prepare_blizz_cdm_viewer` | 1016 | 16.344 | 0.0161 | 0.161 |
| `aura_frames.is_timer_text_enabled` | 1466 | 15.912 | 0.0109 | 0.068 |
| `aura_frames.normalize_timer_category` | 5693 | 13.373 | 0.0023 | 0.057 |
| `aura_frames.get_frame_config_db` | 7424 | 10.286 | 0.0014 | 0.047 |
| `aura_frames.update_blizz_cdm_visibility` | 864 | 10.057 | 0.0116 | 0.176 |
| `aura_frames.get_bar_bg_color` | 1466 | 9.002 | 0.0061 | 0.088 |
| `aura_frames.mark_aura_scan_dirty` | 981 | 6.470 | 0.0066 | 0.082 |
| `aura_frames.cdm_category_needs_viewer` | 272 | 5.224 | 0.0192 | 0.066 |
| `aura_frames.get_cdm_viewer_frame` | 3064 | 4.579 | 0.0015 | 0.026 |
| `aura_frames.update_all_blizz_cdm_visibility` | 68 | 4.348 | 0.0639 | 0.213 |
| `aura_frames.scan_custom_aura_map` | 90 | 4.051 | 0.0450 | 0.225 |
| `skyriding_vigor.set_slot_state` | 1548 | 3.890 | 0.0025 | 0.058 |
| `aura_frames.merge_aura_info` | 792 | 3.658 | 0.0046 | 0.054 |
| `aura_frames.get_frame_position_table` | 852 | 3.492 | 0.0041 | 1.340 |
| `skyriding_vigor.set_slot_visible` | 1548 | 3.441 | 0.0022 | 0.046 |
| `skyriding_vigor.ensure_frame` | 1236 | 3.228 | 0.0026 | 0.051 |
| `skyriding_vigor.set_move_mode` | 618 | 2.779 | 0.0045 | 0.054 |
| `aura_frames.ensure_blizz_cdm_viewer_always_visible` | 592 | 2.576 | 0.0044 | 0.033 |
| `sound_levels.apply_fishing_focus` | 2 | 2.173 | 1.0867 | 1.258 |
| `aura_frames.uses_cooldown_icon_overlay` | 1466 | 1.993 | 0.0014 | 0.025 |
| `aura_frames.ensure_visible_icon_ticker` | 1466 | 1.919 | 0.0013 | 0.080 |
| `aura_frames.get_preset_keys` | 544 | 1.823 | 0.0034 | 0.044 |
| `aura_frames.set_height_for_growth` | 25 | 1.805 | 0.0722 | 0.116 |
| `sound_levels.restore_fishing_focus` | 2 | 1.782 | 0.8908 | 0.895 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1099 | 1.751 | 0.0016 | 0.065 |
| `aura_frames.ensure_blizz_cdm_loaded` | 1456 | 1.659 | 0.0011 | 0.029 |

Compared with the baseline, `aura_visible_icon_tick` at 0.2s produced a clear
ticker-path improvement: `tick_visible_icons` dropped from about 0.98ms/s to
0.60ms/s, and `set_timer_text` dropped from about 0.40ms/s to 0.27ms/s. The
overall `update_auras` and `render_aura_map` rates were higher in this run, so
the full-session totals are not apples-to-apples for those paths. The direct
ticker result supports keeping `aura_visible_icon_tick` at 0.2s if visual
smoothness remains acceptable, but does not prove that `aura_event_bucket` should
also stay at 0.2s.

### 2026-06-06, Update Path Cleanup

Context: 62.1s broad addon run after reducing repeated work in the Aura Frames
`update_auras()` path. Runtime timing aliases remained at the current test values.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 761 | 250.175 | 0.3287 | 2.348 |
| `aura_frames.render_aura_map` | 761 | 97.602 | 0.1283 | 0.807 |
| `aura_frames.tick_visible_icons` | 571 | 96.670 | 0.1693 | 0.570 |
| `aura_frames.set_timer_text` | 3602 | 42.553 | 0.0118 | 0.113 |
| `aura_frames.unified_scan` | 72 | 41.879 | 0.5817 | 1.316 |
| `skyriding_vigor.refresh` | 461 | 35.818 | 0.0777 | 0.879 |
| `aura_frames.add_cooldown_viewer_category_entries` | 436 | 28.815 | 0.0661 | 0.498 |
| `aura_frames.get_frame_activity_state` | 3004 | 21.783 | 0.0073 | 0.100 |
| `aura_frames.get_timer_behavior` | 4363 | 20.662 | 0.0047 | 0.076 |
| `aura_frames.get_setting` | 7241 | 15.730 | 0.0022 | 2.072 |
| `aura_frames.refresh_frame_ooc_fade` | 761 | 15.537 | 0.0204 | 2.116 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 571 | 12.326 | 0.0216 | 0.133 |
| `aura_frames.normalize_timer_category` | 5124 | 10.491 | 0.0020 | 0.070 |
| `aura_frames.frame_needs_visible_icon_tick` | 1432 | 8.928 | 0.0062 | 0.053 |
| `aura_frames.is_timer_text_enabled` | 761 | 8.432 | 0.0111 | 0.076 |
| `aura_frames.mark_aura_scan_dirty` | 786 | 5.138 | 0.0065 | 0.054 |
| `aura_frames.get_frame_config_db` | 3004 | 4.957 | 0.0017 | 0.061 |
| `aura_frames.scan_custom_aura_map` | 65 | 4.494 | 0.0691 | 0.259 |
| `aura_frames.get_bar_bg_color` | 761 | 4.457 | 0.0059 | 0.056 |
| `aura_frames.merge_aura_info` | 765 | 4.456 | 0.0058 | 0.118 |
| `aura_frames.prepare_blizz_cdm_viewer` | 436 | 3.571 | 0.0082 | 0.089 |
| `skyriding_vigor.set_slot_visible` | 960 | 2.503 | 0.0026 | 0.036 |
| `skyriding_vigor.set_slot_state` | 960 | 2.467 | 0.0026 | 0.057 |
| `skyriding_vigor.ensure_frame` | 922 | 2.310 | 0.0025 | 0.025 |
| `skyriding_vigor.set_move_mode` | 461 | 2.081 | 0.0045 | 0.029 |
| `aura_frames.get_cdm_viewer_frame` | 760 | 1.373 | 0.0018 | 0.031 |
| `aura_frames.update_blizz_cdm_visibility` | 116 | 1.323 | 0.0114 | 0.045 |
| `aura_frames.uses_cooldown_icon_overlay` | 761 | 1.265 | 0.0017 | 0.025 |
| `aura_frames.clear_sorted_aura_ids_cache` | 858 | 1.249 | 0.0015 | 0.017 |
| `aura_frames.clear_custom_aura_scan_cache` | 786 | 1.106 | 0.0014 | 0.045 |
| `aura_frames.refresh_visible_icon_ticker` | 761 | 0.917 | 0.0012 | 0.008 |
| `skyriding_vigor.apply_layout` | 461 | 0.831 | 0.0018 | 0.023 |
| `aura_frames.ensure_blizz_cdm_viewer_always_visible` | 104 | 0.559 | 0.0054 | 0.025 |
| `aura_frames.get_custom_aura_filter` | 65 | 0.464 | 0.0071 | 0.029 |
| `aura_frames.set_height_for_growth` | 6 | 0.364 | 0.0606 | 0.080 |
| `aura_frames.get_frame_position_table` | 189 | 0.359 | 0.0019 | 0.008 |
| `aura_frames.ensure_blizz_cdm_loaded` | 220 | 0.249 | 0.0011 | 0.006 |
| `aura_frames.cdm_category_needs_viewer` | 12 | 0.215 | 0.0180 | 0.032 |
| `aura_frames.update_all_blizz_cdm_visibility` | 3 | 0.181 | 0.0602 | 0.079 |
| `aura_frames.get_custom_modifier_def` | 65 | 0.148 | 0.0023 | 0.010 |

Compared with the prior 0.2s run, the cleanup significantly reduced the targeted
ticker-maintenance path: `refresh_visible_icon_ticker` fell from about 0.23ms/s
to 0.01ms/s, `any_frame_needs_visible_icon_tick` fell from about 0.28ms/s to
0.20ms/s, and `frame_needs_visible_icon_tick` fell from about 0.20ms/s to
0.14ms/s. Passing existing activity/config context into OOC fade also helped:
`refresh_frame_ooc_fade` fell from about 0.30ms/s to 0.25ms/s. This run had much
higher visible-icon ticker pressure, so `tick_visible_icons` is not comparable
to the prior run.

### 2026-06-06, Render Path Cleanup

Context: 87.7s broad addon run after Aura Frames render cleanup: precomputed timer
behavior reuse, cooldown overlay signature guard, guarded bar min/max writes, and
count-text anchor caching.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 783 | 237.463 | 0.3033 | 3.710 |
| `aura_frames.tick_visible_icons` | 826 | 94.347 | 0.1142 | 0.326 |
| `aura_frames.render_aura_map` | 783 | 90.258 | 0.1153 | 0.669 |
| `aura_frames.add_cooldown_viewer_category_entries` | 508 | 31.549 | 0.0621 | 0.346 |
| `aura_frames.unified_scan` | 77 | 29.083 | 0.3777 | 0.803 |
| `aura_frames.set_timer_text` | 3234 | 28.344 | 0.0088 | 0.156 |
| `aura_frames.refresh_frame_ooc_fade` | 783 | 16.440 | 0.0210 | 0.098 |
| `aura_frames.get_frame_activity_state` | 2240 | 15.493 | 0.0069 | 0.095 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 826 | 14.314 | 0.0173 | 0.092 |
| `aura_frames.get_setting` | 7483 | 13.621 | 0.0018 | 0.123 |
| `skyriding_vigor.refresh` | 203 | 13.167 | 0.0649 | 0.223 |
| `aura_frames.frame_needs_visible_icon_tick` | 1760 | 9.534 | 0.0054 | 0.076 |
| `aura_frames.prepare_blizz_cdm_viewer` | 508 | 9.132 | 0.0180 | 3.005 |
| `aura_frames.is_timer_text_enabled` | 783 | 8.054 | 0.0103 | 0.084 |
| `aura_frames.get_timer_behavior` | 1811 | 8.033 | 0.0044 | 0.078 |
| `aura_frames.get_cdm_viewer_frame` | 1332 | 5.302 | 0.0040 | 2.941 |
| `aura_frames.normalize_timer_category` | 2594 | 4.874 | 0.0019 | 0.029 |
| `aura_frames.get_bar_bg_color` | 783 | 4.754 | 0.0061 | 0.082 |
| `aura_frames.update_blizz_cdm_visibility` | 384 | 4.183 | 0.0109 | 0.041 |
| `aura_frames.get_frame_config_db` | 2240 | 3.628 | 0.0016 | 0.089 |
| `aura_frames.mark_aura_scan_dirty` | 609 | 3.627 | 0.0060 | 0.035 |
| `aura_frames.cdm_category_needs_viewer` | 164 | 2.681 | 0.0163 | 0.035 |
| `aura_frames.merge_aura_info` | 441 | 2.421 | 0.0055 | 0.030 |
| `aura_frames.update_all_blizz_cdm_visibility` | 41 | 2.278 | 0.0556 | 0.089 |
| `aura_frames.scan_custom_aura_map` | 55 | 2.093 | 0.0381 | 0.116 |
| `aura_frames.get_preset_keys` | 328 | 1.411 | 0.0043 | 0.085 |
| `aura_frames.uses_cooldown_icon_overlay` | 783 | 1.380 | 0.0018 | 0.024 |
| `aura_frames.refresh_visible_icon_ticker` | 783 | 1.138 | 0.0015 | 0.093 |
| `aura_frames.ensure_blizz_cdm_viewer_always_visible` | 220 | 0.987 | 0.0045 | 0.036 |
| `aura_frames.set_height_for_growth` | 13 | 0.950 | 0.0731 | 0.096 |
| `skyriding_vigor.ensure_frame` | 406 | 0.912 | 0.0022 | 0.016 |
| `aura_frames.clear_sorted_aura_ids_cache` | 686 | 0.892 | 0.0013 | 0.026 |
| `skyriding_vigor.set_move_mode` | 203 | 0.884 | 0.0044 | 0.019 |
| `aura_frames.clear_custom_aura_scan_cache` | 609 | 0.802 | 0.0013 | 0.025 |
| `player_frame.get_clamped_fade_value` | 200 | 0.758 | 0.0038 | 0.013 |
| `aura_frames.queue_wow_cooldown_refresh` | 55 | 0.730 | 0.0133 | 0.030 |
| `aura_frames.get_frame_position_table` | 365 | 0.677 | 0.0019 | 0.015 |
| `aura_frames.ensure_blizz_cdm_loaded` | 604 | 0.610 | 0.0010 | 0.007 |
| `skyriding_vigor.set_slot_visible` | 270 | 0.554 | 0.0021 | 0.027 |
| `skyriding_vigor.set_slot_state` | 270 | 0.536 | 0.0020 | 0.036 |

Compared with the update-path-cleanup run, the targeted render changes improved
the hot helper chain substantially. `set_timer_text` fell from about 0.69ms/s to
0.32ms/s, `get_timer_behavior` fell from about 0.33ms/s to 0.09ms/s, and
`normalize_timer_category` fell from about 0.17ms/s to 0.06ms/s. `render_aura_map`
also improved from about 1.57ms/s to 1.03ms/s, with average render cost falling
from 0.1283ms to 0.1153ms. This supports keeping the render cleanup.

### 2026-06-06, Follow-Up Render/CDM Baseline

Context: 69.9s broad addon run after render cleanup, used to decide the next CDM
read-path review target.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1169 | 349.672 | 0.2991 | 1.426 |
| `aura_frames.render_aura_map` | 1169 | 150.933 | 0.1291 | 0.865 |
| `aura_frames.tick_visible_icons` | 660 | 101.816 | 0.1543 | 2.398 |
| `aura_frames.unified_scan` | 110 | 52.405 | 0.4764 | 1.061 |
| `aura_frames.add_cooldown_viewer_category_entries` | 664 | 42.314 | 0.0637 | 0.310 |
| `aura_frames.set_timer_text` | 5829 | 32.065 | 0.0055 | 2.190 |
| `aura_frames.get_frame_activity_state` | 4686 | 31.048 | 0.0066 | 0.082 |
| `skyriding_vigor.refresh` | 585 | 26.719 | 0.0457 | 0.177 |
| `aura_frames.get_setting` | 11130 | 19.022 | 0.0017 | 0.038 |
| `aura_frames.refresh_frame_ooc_fade` | 1171 | 17.142 | 0.0146 | 0.083 |
| `aura_frames.get_timer_behavior` | 3237 | 13.545 | 0.0042 | 0.040 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 660 | 11.645 | 0.0176 | 0.057 |
| `aura_frames.is_timer_text_enabled` | 1169 | 11.564 | 0.0099 | 0.090 |
| `aura_frames.normalize_timer_category` | 4406 | 8.187 | 0.0019 | 0.071 |
| `aura_frames.frame_needs_visible_icon_tick` | 1390 | 8.043 | 0.0058 | 0.038 |
| `aura_frames.get_frame_config_db` | 4690 | 7.188 | 0.0015 | 0.076 |
| `aura_frames.mark_aura_scan_dirty` | 1164 | 7.071 | 0.0061 | 0.087 |
| `aura_frames.get_bar_bg_color` | 1169 | 6.360 | 0.0054 | 0.039 |
| `aura_frames.merge_aura_info` | 1152 | 5.993 | 0.0052 | 0.023 |
| `aura_frames.scan_custom_aura_map` | 101 | 5.904 | 0.0585 | 0.244 |
| `skyriding_vigor.ensure_frame` | 1170 | 2.223 | 0.0019 | 0.018 |
| `skyriding_vigor.set_move_mode` | 585 | 2.138 | 0.0037 | 0.035 |
| `aura_frames.uses_cooldown_icon_overlay` | 1169 | 1.887 | 0.0016 | 0.035 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1274 | 1.742 | 0.0014 | 0.023 |
| `aura_frames.clear_custom_aura_scan_cache` | 1164 | 1.499 | 0.0013 | 0.049 |
| `aura_frames.refresh_visible_icon_ticker` | 1169 | 1.484 | 0.0013 | 0.011 |
| `aura_frames.get_cdm_viewer_frame` | 700 | 1.312 | 0.0019 | 0.024 |
| `aura_frames.prepare_blizz_cdm_viewer` | 664 | 1.157 | 0.0017 | 0.032 |
| `skyriding_vigor.apply_layout` | 585 | 0.845 | 0.0014 | 0.008 |
| `aura_frames.get_custom_aura_filter` | 101 | 0.609 | 0.0060 | 0.012 |
| `aura_frames.update_blizz_cdm_visibility` | 20 | 0.225 | 0.0112 | 0.025 |
| `aura_frames.cdm_category_needs_viewer` | 12 | 0.205 | 0.0171 | 0.042 |
| `aura_frames.update_all_blizz_cdm_visibility` | 3 | 0.181 | 0.0604 | 0.077 |
| `aura_frames.get_custom_modifier_def` | 101 | 0.162 | 0.0016 | 0.004 |
| `aura_frames.queue_wow_cooldown_refresh` | 4 | 0.133 | 0.0332 | 0.104 |
| `aura_frames.get_preset_keys` | 24 | 0.122 | 0.0051 | 0.034 |
| `aura_frames.set_aura_frame_hovered` | 4 | 0.101 | 0.0253 | 0.062 |
| `player_frame.fade.on_enter_combat` | 1 | 0.054 | 0.0543 | 0.054 |
| `aura_frames.ensure_blizz_cdm_viewer_always_visible` | 8 | 0.030 | 0.0038 | 0.005 |
| `aura_frames.ensure_blizz_cdm_loaded` | 28 | 0.026 | 0.0009 | 0.002 |

Compared with the prior render-cleanup run, `set_timer_text` average cost improved
again, but this run had far more timer-text calls per second. CDM preparation and
viewer lookup were cheap in this run; the remaining CDM-specific review target is
`add_cooldown_viewer_category_entries`, about 0.61ms/s with a stable 0.064ms
average call cost.

### 2026-06-06, Longer Follow-Up Render/CDM Baseline

Context: 101.6s broad addon run after render cleanup, with more update/render
activity than the prior follow-up run.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1590 | 491.977 | 0.3094 | 2.190 |
| `aura_frames.render_aura_map` | 1590 | 212.559 | 0.1337 | 0.943 |
| `aura_frames.tick_visible_icons` | 962 | 159.282 | 0.1656 | 0.520 |
| `aura_frames.unified_scan` | 157 | 79.201 | 0.5045 | 1.516 |
| `aura_frames.add_cooldown_viewer_category_entries` | 880 | 55.834 | 0.0634 | 0.350 |
| `aura_frames.set_timer_text` | 9802 | 48.080 | 0.0049 | 0.142 |
| `aura_frames.get_frame_activity_state` | 6245 | 42.445 | 0.0068 | 0.135 |
| `skyriding_vigor.refresh` | 731 | 34.122 | 0.0467 | 0.181 |
| `aura_frames.get_setting` | 15139 | 27.764 | 0.0018 | 1.963 |
| `aura_frames.refresh_frame_ooc_fade` | 1596 | 23.349 | 0.0146 | 0.082 |
| `aura_frames.get_timer_behavior` | 4505 | 19.422 | 0.0043 | 0.066 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 962 | 17.090 | 0.0178 | 0.065 |
| `aura_frames.is_timer_text_enabled` | 1590 | 15.979 | 0.0100 | 0.067 |
| `aura_frames.frame_needs_visible_icon_tick` | 1996 | 12.103 | 0.0061 | 0.054 |
| `aura_frames.normalize_timer_category` | 6095 | 11.527 | 0.0019 | 0.035 |
| `aura_frames.get_bar_bg_color` | 1590 | 10.638 | 0.0067 | 1.972 |
| `aura_frames.mark_aura_scan_dirty` | 1713 | 10.332 | 0.0060 | 0.071 |
| `aura_frames.get_frame_config_db` | 6254 | 9.685 | 0.0015 | 0.050 |
| `aura_frames.merge_aura_info` | 1692 | 9.659 | 0.0057 | 0.082 |
| `aura_frames.scan_custom_aura_map` | 142 | 7.709 | 0.0543 | 0.257 |
| `skyriding_vigor.ensure_frame` | 1462 | 2.778 | 0.0019 | 0.033 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1870 | 2.639 | 0.0014 | 0.064 |
| `skyriding_vigor.set_move_mode` | 731 | 2.567 | 0.0035 | 0.027 |
| `aura_frames.uses_cooldown_icon_overlay` | 1590 | 2.383 | 0.0015 | 0.012 |
| `aura_frames.clear_custom_aura_scan_cache` | 1713 | 2.200 | 0.0013 | 0.014 |
| `aura_frames.refresh_visible_icon_ticker` | 1590 | 2.197 | 0.0014 | 0.239 |
| `aura_frames.get_cdm_viewer_frame` | 916 | 1.746 | 0.0019 | 0.010 |
| `aura_frames.prepare_blizz_cdm_viewer` | 880 | 1.631 | 0.0019 | 0.160 |
| `skyriding_vigor.apply_layout` | 731 | 1.070 | 0.0015 | 0.014 |
| `aura_frames.get_custom_aura_filter` | 142 | 0.941 | 0.0066 | 0.030 |
| `aura_frames.update_blizz_cdm_visibility` | 20 | 0.331 | 0.0165 | 0.141 |
| `aura_frames.set_aura_frame_hovered` | 6 | 0.289 | 0.0482 | 0.089 |
| `aura_frames.get_custom_modifier_def` | 142 | 0.271 | 0.0019 | 0.006 |
| `aura_frames.cdm_category_needs_viewer` | 12 | 0.179 | 0.0149 | 0.023 |
| `aura_frames.update_all_blizz_cdm_visibility` | 3 | 0.146 | 0.0486 | 0.054 |
| `aura_frames.get_preset_keys` | 24 | 0.093 | 0.0039 | 0.008 |
| `aura_frames.set_height_for_growth` | 1 | 0.083 | 0.0829 | 0.083 |
| `player_frame.fade.on_enter_combat` | 1 | 0.070 | 0.0699 | 0.070 |
| `aura_frames.queue_wow_cooldown_refresh` | 4 | 0.052 | 0.0129 | 0.026 |
| `aura_frames.ensure_blizz_cdm_viewer_always_visible` | 8 | 0.031 | 0.0039 | 0.005 |

Compared with the shorter follow-up baseline, average call costs stayed stable:
`add_cooldown_viewer_category_entries` stayed near 0.064ms/call, `set_timer_text`
improved to 0.0049ms/call, and `prepare_blizz_cdm_viewer` / `get_cdm_viewer_frame`
remained cheap. The next actionable CPU target is still the CDM entry read path,
but its absolute cost is modest.

CDM read-path follow-up: reviewed `add_cooldown_viewer_category_entries()` after
this run. No safe high-value cleanup was identified. The remaining cost is mainly
the necessary live walk of Blizzard CDM child state, plus cooldown identity/timing
fallbacks. Keep the current read-only approach unless a future profile shows a
material regression or a specific CDM behavior issue gives a narrower change target.

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

Conclusion: Aura Frames remains the largest broad runtime cost, with the inclusive
`update_auras` path around 4.4ms/s and visible-icon ticking around 2.2ms/s in this
run. Skyriding Vigor is now a meaningful secondary target: `refresh` averaged
0.443ms/call with visible nested costs in style/atlas lookup and filling-slot
updates. Because the profiler wraps nested addon functions, do not sum the rows as
exclusive module totals; use them to choose the next focused profile. Recommended
follow-up: run an Aura-only profile to confirm the current Aura hot path, then a
Skyriding-only profile while a node is filling to assess style lookup caching and
`set_slot_state` / progress update behavior.

### 2026-06-22, Aura Frames Only

Context: 90.6s run with only `PROFILE_TARGETS.aura_frames = true`.
Profiler wrapped Aura Frames addon-owned functions only.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1509 | 674.741 | 0.4471 | 3.580 |
| `aura_frames.render_aura_map` | 1509 | 268.251 | 0.1778 | 1.287 |
| `aura_frames.tick_visible_icons` | 836 | 247.537 | 0.2961 | 1.273 |
| `aura_frames.unified_scan` | 138 | 85.381 | 0.6187 | 2.910 |
| `aura_frames.add_cooldown_viewer_category_entries` | 944 | 85.081 | 0.0901 | 0.517 |
| `aura_frames.set_timer_text` | 13780 | 80.167 | 0.0058 | 0.616 |
| `aura_frames.scan_custom_aura_map` | 113 | 56.953 | 0.5040 | 1.256 |
| `aura_frames.get_frame_activity_state` | 5422 | 43.579 | 0.0080 | 0.129 |
| `aura_frames.refresh_frame_ooc_fade` | 1509 | 30.160 | 0.0200 | 0.256 |
| `aura_frames.get_setting` | 14402 | 29.670 | 0.0021 | 0.210 |
| `aura_frames.get_timer_behavior` | 5328 | 26.794 | 0.0050 | 0.066 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 836 | 17.870 | 0.0214 | 0.274 |
| `aura_frames.is_timer_text_enabled` | 1509 | 17.843 | 0.0118 | 0.072 |
| `aura_frames.is_runtime_enabled` | 2389 | 17.245 | 0.0072 | 0.109 |
| `aura_frames.normalize_timer_category` | 6837 | 14.939 | 0.0022 | 0.063 |
| `aura_frames.frame_needs_visible_icon_tick` | 1697 | 12.824 | 0.0076 | 0.262 |
| `aura_frames.get_bar_bg_color` | 1509 | 9.990 | 0.0066 | 0.071 |
| `aura_frames.get_frame_config_db` | 5422 | 9.966 | 0.0018 | 0.124 |
| `aura_frames.prepare_blizz_cdm_viewer` | 944 | 9.851 | 0.0104 | 0.339 |
| `aura_frames.mark_aura_scan_dirty` | 1323 | 9.554 | 0.0072 | 0.126 |
| `aura_frames.merge_aura_info` | 1197 | 6.928 | 0.0058 | 0.041 |
| `aura_frames.update_blizz_cdm_visibility` | 456 | 5.516 | 0.0121 | 0.039 |
| `aura_frames.get_cdm_viewer_frame` | 1960 | 4.383 | 0.0022 | 0.313 |
| `aura_frames.cdm_category_needs_viewer` | 176 | 3.310 | 0.0188 | 0.060 |
| `aura_frames.uses_cooldown_icon_overlay` | 1509 | 2.903 | 0.0019 | 0.028 |

Conclusion: Aura-only profiling confirms the broad-run hot path. `update_auras`
is still the main inclusive path, followed by rendering and visible-icon ticking.
`unified_scan`, CDM entry reads, timer text, and custom aura scans are secondary
contributors. Per-call costs are stable versus the broad run; the next practical
Aura performance review should inspect whether `update_auras()` can skip stable
work per frame, whether `render_aura_map()` can avoid redundant visual setters,
and whether custom scans can be extended/reused more cheaply for unchanged
filters.

### 2026-06-22, Aura Frames Only, Post-OOC Fast Path

Context: 90.1s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
the low-risk OOC fade early return for disabled/no-active-fade frames. Profiler
wrapped Aura Frames addon-owned functions only.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1309 | 590.951 | 0.4515 | 2.645 |
| `aura_frames.render_aura_map` | 1309 | 231.311 | 0.1767 | 1.463 |
| `aura_frames.tick_visible_icons` | 833 | 216.191 | 0.2595 | 1.181 |
| `aura_frames.add_cooldown_viewer_category_entries` | 824 | 79.223 | 0.0961 | 0.528 |
| `aura_frames.unified_scan` | 111 | 66.405 | 0.5982 | 1.508 |
| `aura_frames.set_timer_text` | 10583 | 62.127 | 0.0059 | 0.939 |
| `aura_frames.scan_custom_aura_map` | 97 | 48.777 | 0.5029 | 1.460 |
| `aura_frames.get_frame_activity_state` | 4858 | 38.211 | 0.0079 | 0.077 |
| `aura_frames.get_setting` | 12218 | 27.166 | 0.0022 | 0.237 |
| `aura_frames.refresh_frame_ooc_fade` | 1311 | 26.106 | 0.0199 | 0.090 |
| `aura_frames.get_timer_behavior` | 4414 | 22.734 | 0.0052 | 0.229 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 833 | 17.850 | 0.0214 | 0.141 |
| `aura_frames.is_runtime_enabled` | 2170 | 16.669 | 0.0077 | 0.193 |
| `aura_frames.is_timer_text_enabled` | 1309 | 16.506 | 0.0126 | 0.105 |
| `aura_frames.normalize_timer_category` | 5723 | 12.734 | 0.0022 | 0.055 |
| `aura_frames.frame_needs_visible_icon_tick` | 1784 | 12.164 | 0.0068 | 0.042 |
| `aura_frames.prepare_blizz_cdm_viewer` | 824 | 10.595 | 0.0129 | 0.201 |
| `aura_frames.get_bar_bg_color` | 1309 | 9.005 | 0.0069 | 0.033 |
| `aura_frames.get_frame_config_db` | 4865 | 8.770 | 0.0018 | 0.071 |
| `aura_frames.mark_aura_scan_dirty` | 1146 | 7.854 | 0.0069 | 0.274 |
| `aura_frames.merge_aura_info` | 1062 | 6.217 | 0.0059 | 0.113 |
| `aura_frames.update_blizz_cdm_visibility` | 396 | 5.050 | 0.0128 | 0.048 |
| `aura_frames.get_cdm_viewer_frame` | 1788 | 3.809 | 0.0021 | 0.037 |
| `aura_frames.uses_cooldown_icon_overlay` | 1309 | 2.626 | 0.0020 | 0.028 |
| `aura_frames.cdm_category_needs_viewer` | 112 | 2.271 | 0.0203 | 0.056 |

Conclusion: Compared with the prior 90.6s Aura-only baseline, total ms/sec fell
mostly because `update_auras` and render calls/sec were lower in this run
(`update_auras` about 7.45ms/s -> 6.56ms/s). Per-call costs stayed broadly
stable: `update_auras` 0.4471ms -> 0.4515ms and `render_aura_map` 0.1778ms ->
0.1767ms. `tick_visible_icons` improved on both total rate and average cost
(`0.2961ms` -> `0.2595ms`), but workload differences still make attribution
uncertain. Use this as the current comparison baseline before adding temporary
`update_auras` sub-step profiler labels.

### 2026-06-22, Aura Frames Only, Update Sub-Steps

Context: 77.2s run with only `PROFILE_TARGETS.aura_frames = true`, plus temporary
sub-step labels inside `M.update_auras()` to split inclusive update cost. Profiler
wrapped Aura Frames addon-owned functions only. Sub-step labels were removed after
the run.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1498 | 748.218 | 0.4995 | 3.484 |
| `aura_frames.update_auras.render` | 1498 | 311.485 | 0.2079 | 1.355 |
| `aura_frames.render_aura_map` | 1498 | 306.921 | 0.2049 | 1.350 |
| `aura_frames.update_auras.scan_map` | 1498 | 259.106 | 0.1730 | 2.844 |
| `aura_frames.tick_visible_icons` | 709 | 254.530 | 0.3590 | 1.710 |
| `aura_frames.unified_scan` | 149 | 101.481 | 0.6811 | 1.948 |
| `aura_frames.set_timer_text` | 17000 | 81.092 | 0.0048 | 1.251 |
| `aura_frames.add_cooldown_viewer_category_entries` | 828 | 76.121 | 0.0919 | 0.481 |
| `aura_frames.scan_custom_aura_map` | 134 | 74.637 | 0.5570 | 2.834 |
| `aura_frames.update_auras.config` | 1498 | 72.361 | 0.0483 | 0.184 |
| `aura_frames.get_frame_activity_state` | 6229 | 49.904 | 0.0080 | 0.068 |
| `aura_frames.get_timer_behavior` | 6014 | 30.396 | 0.0051 | 0.216 |
| `aura_frames.get_setting` | 13835 | 29.154 | 0.0021 | 0.338 |
| `aura_frames.update_auras.ooc_fade` | 1498 | 28.310 | 0.0189 | 0.354 |
| `aura_frames.refresh_frame_ooc_fade` | 1498 | 25.031 | 0.0167 | 0.353 |
| `aura_frames.is_timer_text_enabled` | 1498 | 17.772 | 0.0119 | 0.071 |
| `aura_frames.update_auras.activity` | 1498 | 16.649 | 0.0111 | 0.069 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 709 | 16.427 | 0.0232 | 0.278 |
| `aura_frames.is_runtime_enabled` | 2210 | 16.284 | 0.0074 | 0.036 |
| `aura_frames.normalize_timer_category` | 7512 | 16.178 | 0.0022 | 0.056 |
| `aura_frames.update_auras.layout_shell` | 1498 | 12.198 | 0.0081 | 0.149 |
| `aura_frames.get_frame_config_db` | 6229 | 11.829 | 0.0019 | 0.055 |
| `aura_frames.frame_needs_visible_icon_tick` | 1464 | 11.642 | 0.0080 | 0.120 |
| `aura_frames.mark_aura_scan_dirty` | 1614 | 11.610 | 0.0072 | 0.260 |
| `aura_frames.get_bar_bg_color` | 1498 | 10.129 | 0.0068 | 0.041 |

Conclusion: The split shows the next best Aura Frames CPU target is not generic
settings resolution. Render dominates the inclusive update path, followed by
scan/map fill. `update_auras.config` is visible but much smaller, about 0.94ms/s
versus about 4.03ms/s for render and 3.36ms/s for scan/map fill in this run.
Next implementation pass should focus on render skipping/redundant render work
and scan-map narrowing before adding a broader runtime config cache.

### 2026-06-22, Aura Frames Only, Render Timer Behavior Cache

Context: 78.7s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
`render_aura_map()` to reuse one timer behavior for preset frames and cache timer
behaviors by category for custom frames during each render pass.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1457 | 712.382 | 0.4889 | 2.505 |
| `aura_frames.render_aura_map` | 1457 | 284.441 | 0.1952 | 1.125 |
| `aura_frames.tick_visible_icons` | 728 | 252.601 | 0.3470 | 0.920 |
| `aura_frames.unified_scan` | 141 | 102.302 | 0.7255 | 1.641 |
| `aura_frames.set_timer_text` | 15294 | 78.261 | 0.0051 | 0.180 |
| `aura_frames.add_cooldown_viewer_category_entries` | 812 | 77.623 | 0.0956 | 0.516 |
| `aura_frames.scan_custom_aura_map` | 129 | 74.680 | 0.5789 | 1.438 |
| `aura_frames.get_frame_activity_state` | 5865 | 51.673 | 0.0088 | 0.180 |
| `aura_frames.get_setting` | 13464 | 30.194 | 0.0022 | 0.084 |
| `aura_frames.refresh_frame_ooc_fade` | 1457 | 26.691 | 0.0183 | 0.151 |
| `aura_frames.is_timer_text_enabled` | 1457 | 19.566 | 0.0134 | 0.687 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 728 | 17.470 | 0.0240 | 0.095 |
| `aura_frames.is_runtime_enabled` | 2190 | 17.144 | 0.0078 | 0.052 |
| `aura_frames.get_timer_behavior` | 3042 | 16.480 | 0.0054 | 0.069 |
| `aura_frames.mark_aura_scan_dirty` | 1551 | 12.537 | 0.0081 | 0.221 |
| `aura_frames.frame_needs_visible_icon_tick` | 1502 | 12.475 | 0.0083 | 0.052 |
| `aura_frames.get_frame_config_db` | 5865 | 12.020 | 0.0020 | 0.168 |
| `aura_frames.normalize_timer_category` | 4499 | 11.610 | 0.0026 | 0.606 |
| `aura_frames.get_bar_bg_color` | 1457 | 10.810 | 0.0074 | 0.053 |
| `aura_frames.merge_aura_info` | 1530 | 10.182 | 0.0067 | 0.141 |
| `aura_frames.uses_cooldown_icon_overlay` | 1457 | 3.083 | 0.0021 | 0.024 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1692 | 3.012 | 0.0018 | 0.120 |
| `aura_frames.prepare_blizz_cdm_viewer` | 812 | 2.958 | 0.0036 | 0.222 |
| `aura_frames.clear_custom_aura_scan_cache` | 1551 | 2.448 | 0.0016 | 0.085 |
| `aura_frames.get_cdm_viewer_frame` | 928 | 2.413 | 0.0026 | 0.091 |

Conclusion: The targeted helper change worked: compared with the update sub-step
run, `get_timer_behavior` fell from 6014 calls / 30.396ms to 3042 calls /
16.480ms despite similar render/update volume. `render_aura_map` average also
fell from 0.2049ms to 0.1952ms in this run. The main render path remains a large
cost, so the next render review should look for broader display-signature or
redundant-work skips, then reprofile.

### 2026-06-23, Aura Frames Only, Render Display Signature

Context: 117.3s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
a conservative display-signature skip to `render_aura_map()`. NumyAddonProfiler
reported `scriptProfile` enabled, so use this run for relative shape more than
absolute timing.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 2215 | 1011.583 | 0.4567 | 3.454 |
| `aura_frames.render_aura_map` | 2215 | 419.992 | 0.1896 | 2.023 |
| `aura_frames.tick_visible_icons` | 1095 | 372.792 | 0.3404 | 1.253 |
| `aura_frames.unified_scan` | 214 | 135.244 | 0.6320 | 1.606 |
| `aura_frames.set_timer_text` | 24921 | 116.204 | 0.0047 | 0.267 |
| `aura_frames.add_cooldown_viewer_category_entries` | 1240 | 111.338 | 0.0898 | 0.610 |
| `aura_frames.scan_custom_aura_map` | 195 | 103.253 | 0.5295 | 2.809 |
| `aura_frames.get_frame_activity_state` | 9134 | 73.025 | 0.0080 | 0.229 |
| `aura_frames.get_setting` | 20475 | 42.821 | 0.0021 | 0.217 |
| `aura_frames.refresh_frame_ooc_fade` | 2215 | 37.564 | 0.0170 | 0.242 |
| `aura_frames.is_timer_text_enabled` | 2215 | 26.305 | 0.0119 | 0.156 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 1095 | 24.128 | 0.0220 | 0.253 |
| `aura_frames.get_timer_behavior` | 4625 | 23.978 | 0.0052 | 0.149 |
| `aura_frames.is_runtime_enabled` | 3313 | 23.746 | 0.0072 | 0.443 |
| `aura_frames.frame_needs_visible_icon_tick` | 2226 | 17.034 | 0.0077 | 0.233 |
| `aura_frames.get_frame_config_db` | 9134 | 16.631 | 0.0018 | 0.074 |
| `aura_frames.mark_aura_scan_dirty` | 2334 | 16.514 | 0.0071 | 0.173 |
| `aura_frames.normalize_timer_category` | 6840 | 15.096 | 0.0022 | 0.068 |
| `aura_frames.get_bar_bg_color` | 2215 | 14.977 | 0.0068 | 0.057 |
| `aura_frames.merge_aura_info` | 2322 | 14.254 | 0.0061 | 0.185 |
| `aura_frames.uses_cooldown_icon_overlay` | 2215 | 4.695 | 0.0021 | 0.118 |
| `aura_frames.clear_sorted_aura_ids_cache` | 2548 | 4.104 | 0.0016 | 0.080 |
| `aura_frames.clear_custom_aura_scan_cache` | 2334 | 3.396 | 0.0015 | 0.030 |
| `aura_frames.refresh_visible_icon_ticker` | 2215 | 3.277 | 0.0015 | 0.074 |
| `aura_frames.get_cdm_viewer_frame` | 1252 | 2.935 | 0.0023 | 0.029 |

Conclusion: The conservative display-signature skip did not produce a large
step change. `render_aura_map` average improved modestly versus the previous
render-cache run, from 0.1952ms to 0.1896ms, but the run also had external
script profiling enabled and different activity pressure. Treat item 6 as a
small measured win unless later in-game behavior shows stale icon visuals. The
next higher-value target remains scan/map fill.

### 2026-06-23, Aura Frames Only, Preset Bucket Direct Render

Context: 84.7s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
preset static/short/long/debuff frames to render directly from scan-built category
buckets when no test-preview mutation is needed. NumyAddonProfiler again reported
`scriptProfile` enabled.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1523 | 728.070 | 0.4781 | 3.433 |
| `aura_frames.render_aura_map` | 1523 | 310.403 | 0.2038 | 1.765 |
| `aura_frames.tick_visible_icons` | 787 | 280.501 | 0.3564 | 0.985 |
| `aura_frames.unified_scan` | 155 | 98.559 | 0.6359 | 1.730 |
| `aura_frames.set_timer_text` | 18443 | 87.511 | 0.0047 | 0.494 |
| `aura_frames.add_cooldown_viewer_category_entries` | 828 | 74.643 | 0.0901 | 0.752 |
| `aura_frames.scan_custom_aura_map` | 139 | 74.114 | 0.5332 | 2.634 |
| `aura_frames.get_frame_activity_state` | 6427 | 52.192 | 0.0081 | 0.444 |
| `aura_frames.get_setting` | 14050 | 29.516 | 0.0021 | 0.084 |
| `aura_frames.refresh_frame_ooc_fade` | 1523 | 26.176 | 0.0172 | 0.113 |
| `aura_frames.is_timer_text_enabled` | 1523 | 19.549 | 0.0128 | 0.406 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 787 | 18.241 | 0.0232 | 0.246 |
| `aura_frames.get_timer_behavior` | 3185 | 17.882 | 0.0056 | 0.187 |
| `aura_frames.is_runtime_enabled` | 2313 | 17.208 | 0.0074 | 0.101 |
| `aura_frames.frame_needs_visible_icon_tick` | 1638 | 12.737 | 0.0078 | 0.226 |
| `aura_frames.get_frame_config_db` | 6427 | 11.632 | 0.0018 | 0.046 |
| `aura_frames.normalize_timer_category` | 4708 | 11.434 | 0.0024 | 0.391 |
| `aura_frames.mark_aura_scan_dirty` | 1659 | 11.392 | 0.0069 | 0.062 |
| `aura_frames.get_bar_bg_color` | 1523 | 10.284 | 0.0068 | 0.049 |
| `aura_frames.merge_aura_info` | 1647 | 9.799 | 0.0059 | 0.292 |
| `aura_frames.uses_cooldown_icon_overlay` | 1523 | 3.083 | 0.0020 | 0.035 |
| `aura_frames.refresh_visible_icon_ticker` | 1523 | 2.712 | 0.0018 | 0.202 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1814 | 2.690 | 0.0015 | 0.014 |
| `aura_frames.clear_custom_aura_scan_cache` | 1659 | 2.320 | 0.0014 | 0.011 |
| `aura_frames.get_cdm_viewer_frame` | 864 | 2.154 | 0.0025 | 0.031 |

Conclusion: This broad Aura-only profile did not show a clear improvement from
direct bucket rendering. `update_auras` and `render_aura_map` averages were higher
than the previous display-signature run, but activity pressure and `scriptProfile`
make the comparison noisy. The likely issue is that this profile does not isolate
the scan/map-fill sub-step, and preset test-preview paths may prevent the direct
bucket fast path for frames with previews enabled. Revisit item 7 with targeted
sub-step labels or a narrower profile before marking it complete.

### 2026-06-23, Aura Frames Only, Scan/Map Sub-Steps

Context: 64.9s run with only `PROFILE_TARGETS.aura_frames = true`, plus temporary
sub-step labels around Aura Frames scan/map fill branches. No test auras were
enabled. NumyAddonProfiler again reported `scriptProfile` enabled.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1117 | 512.267 | 0.4586 | 6.247 |
| `aura_frames.render_aura_map` | 1117 | 208.738 | 0.1869 | 1.098 |
| `aura_frames.tick_visible_icons` | 607 | 189.438 | 0.3121 | 0.810 |
| `aura_frames.update_auras.scan_shared` | 106 | 66.846 | 0.6306 | 5.180 |
| `aura_frames.unified_scan` | 106 | 66.280 | 0.6253 | 5.169 |
| `aura_frames.update_auras.map_cdm` | 632 | 61.866 | 0.0979 | 0.615 |
| `aura_frames.add_cooldown_viewer_category_entries` | 632 | 59.387 | 0.0940 | 0.606 |
| `aura_frames.set_timer_text` | 11599 | 55.397 | 0.0048 | 0.198 |
| `aura_frames.update_auras.map_custom` | 97 | 49.982 | 0.5153 | 1.366 |
| `aura_frames.scan_custom_aura_map` | 97 | 49.357 | 0.5088 | 1.354 |
| `aura_frames.get_frame_activity_state` | 4648 | 39.909 | 0.0086 | 1.231 |
| `aura_frames.get_setting` | 10333 | 21.758 | 0.0021 | 0.082 |
| `aura_frames.refresh_frame_ooc_fade` | 1117 | 19.512 | 0.0175 | 0.206 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 607 | 14.530 | 0.0239 | 0.107 |
| `aura_frames.is_timer_text_enabled` | 1117 | 13.790 | 0.0123 | 0.067 |
| `aura_frames.is_runtime_enabled` | 1727 | 13.302 | 0.0077 | 0.104 |
| `aura_frames.get_timer_behavior` | 2331 | 12.801 | 0.0055 | 0.062 |
| `aura_frames.frame_needs_visible_icon_tick` | 1296 | 10.430 | 0.0080 | 0.076 |
| `aura_frames.get_frame_config_db` | 4648 | 8.721 | 0.0019 | 0.034 |
| `aura_frames.mark_aura_scan_dirty` | 1146 | 8.156 | 0.0071 | 0.106 |
| `aura_frames.normalize_timer_category` | 3448 | 7.894 | 0.0023 | 0.035 |
| `aura_frames.get_bar_bg_color` | 1117 | 7.525 | 0.0067 | 0.076 |
| `aura_frames.merge_aura_info` | 1134 | 7.201 | 0.0064 | 0.442 |

Conclusion: The direct preset-bucket path is not the meaningful scan/map cost:
`map_preset_bucket`, `map_preset_copy`, `preview_copy`, and `preview_append` were
below the report cutoff. Scan/map cost is dominated by `unified_scan`,
`add_cooldown_viewer_category_entries`, and `scan_custom_aura_map`. Keep the
direct-bucket cleanup because it is safe and removes avoidable work, but future
CPU work should target custom scan reuse or CDM/custom routing rather than preset
bucket copying.

### 2026-06-23, Aura Frames Only, Clean Follow-Up

Context: 88.1s run with only `PROFILE_TARGETS.aura_frames = true`, after removing
the external addon condition that caused the NumyAddonProfiler `scriptProfile`
warning. No temporary scan/map sub-step labels were active in this run.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1250 | 566.765 | 0.4534 | 2.912 |
| `aura_frames.tick_visible_icons` | 821 | 224.691 | 0.2737 | 1.329 |
| `aura_frames.render_aura_map` | 1250 | 221.207 | 0.1770 | 1.407 |
| `aura_frames.add_cooldown_viewer_category_entries` | 840 | 78.268 | 0.0932 | 0.675 |
| `aura_frames.unified_scan` | 104 | 65.535 | 0.6301 | 1.768 |
| `aura_frames.set_timer_text` | 9882 | 63.937 | 0.0065 | 1.133 |
| `aura_frames.scan_custom_aura_map` | 82 | 35.919 | 0.4380 | 1.103 |
| `aura_frames.get_frame_activity_state` | 4169 | 33.741 | 0.0081 | 0.162 |
| `aura_frames.refresh_frame_ooc_fade` | 1250 | 26.945 | 0.0216 | 0.238 |
| `aura_frames.get_setting` | 11716 | 25.863 | 0.0022 | 0.459 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 821 | 19.501 | 0.0238 | 0.284 |
| `aura_frames.is_runtime_enabled` | 2129 | 16.836 | 0.0079 | 0.216 |
| `aura_frames.is_timer_text_enabled` | 1250 | 16.506 | 0.0132 | 0.692 |
| `aura_frames.get_timer_behavior` | 2576 | 14.914 | 0.0058 | 0.679 |
| `aura_frames.prepare_blizz_cdm_viewer` | 840 | 14.877 | 0.0177 | 2.187 |
| `aura_frames.frame_needs_visible_icon_tick` | 1938 | 13.456 | 0.0069 | 0.148 |
| `aura_frames.update_blizz_cdm_visibility` | 608 | 9.887 | 0.0163 | 2.152 |
| `aura_frames.normalize_timer_category` | 3826 | 8.948 | 0.0023 | 0.080 |
| `aura_frames.get_bar_bg_color` | 1250 | 8.928 | 0.0071 | 0.466 |
| `aura_frames.get_frame_config_db` | 4169 | 7.722 | 0.0019 | 0.156 |
| `aura_frames.mark_aura_scan_dirty` | 978 | 7.137 | 0.0073 | 0.107 |
| `aura_frames.merge_aura_info` | 873 | 5.044 | 0.0058 | 0.024 |
| `aura_frames.get_cdm_viewer_frame` | 2200 | 4.575 | 0.0021 | 0.160 |
| `aura_frames.cdm_category_needs_viewer` | 232 | 4.373 | 0.0188 | 0.044 |
| `aura_frames.update_all_blizz_cdm_visibility` | 58 | 3.784 | 0.0652 | 0.116 |

Conclusion: This is the cleaner post-item-7 comparison point. `render_aura_map`
averaged 0.1770ms, lower than the prior render-cache and display-signature runs,
while `update_auras` averaged 0.4534ms. The direct preset-bucket change still
does not show as an isolated CPU win; the next meaningful review target should be
CDM/custom scan-map work or trigger-specific refresh routing.

### 2026-06-23, Aura Frames Only, Category-Scoped CDM Hook Refresh

Context: 61.1s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
hook-driven CDM refreshes to carry the child viewer category and refresh only that
category when known. Startup, settings, and combat-entry refreshes still use the
broad pass.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 998 | 495.116 | 0.4961 | 4.651 |
| `aura_frames.render_aura_map` | 998 | 198.474 | 0.1989 | 1.674 |
| `aura_frames.tick_visible_icons` | 555 | 182.413 | 0.3287 | 1.733 |
| `aura_frames.unified_scan` | 92 | 65.234 | 0.7091 | 1.226 |
| `aura_frames.add_cooldown_viewer_category_entries` | 593 | 59.733 | 0.1007 | 0.474 |
| `aura_frames.set_timer_text` | 10226 | 52.584 | 0.0051 | 0.226 |
| `aura_frames.scan_custom_aura_map` | 81 | 45.905 | 0.5667 | 1.169 |
| `aura_frames.get_frame_activity_state` | 3969 | 35.259 | 0.0089 | 0.210 |
| `aura_frames.get_setting` | 9265 | 20.872 | 0.0023 | 0.057 |
| `aura_frames.refresh_frame_ooc_fade` | 998 | 19.611 | 0.0196 | 0.201 |
| `aura_frames.is_timer_text_enabled` | 998 | 15.944 | 0.0160 | 2.626 |
| `aura_frames.is_runtime_enabled` | 1557 | 13.577 | 0.0087 | 1.392 |
| `aura_frames.any_frame_needs_visible_icon_tick` | 555 | 13.042 | 0.0235 | 0.211 |
| `aura_frames.get_timer_behavior` | 2077 | 12.182 | 0.0059 | 0.104 |
| `aura_frames.normalize_timer_category` | 3075 | 10.075 | 0.0033 | 2.593 |
| `aura_frames.frame_needs_visible_icon_tick` | 1110 | 9.396 | 0.0085 | 0.188 |
| `aura_frames.get_frame_config_db` | 3969 | 8.047 | 0.0020 | 0.100 |
| `aura_frames.get_bar_bg_color` | 998 | 7.961 | 0.0080 | 0.281 |
| `aura_frames.mark_aura_scan_dirty` | 993 | 7.914 | 0.0080 | 0.306 |
| `aura_frames.merge_aura_info` | 972 | 6.287 | 0.0065 | 0.231 |
| `aura_frames.prepare_blizz_cdm_viewer` | 593 | 2.521 | 0.0043 | 0.204 |
| `aura_frames.uses_cooldown_icon_overlay` | 998 | 2.230 | 0.0022 | 0.020 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1085 | 1.817 | 0.0017 | 0.016 |
| `aura_frames.get_cdm_viewer_frame` | 744 | 1.767 | 0.0024 | 0.026 |
| `aura_frames.clear_custom_aura_scan_cache` | 993 | 1.580 | 0.0016 | 0.012 |

Conclusion: Category-scoped hook refresh is a low-risk routing cleanup with a
small measured support-cost win. Compared with the clean follow-up run,
`prepare_blizz_cdm_viewer` dropped from 14.877ms over 88.1s to 2.521ms over
61.1s, and `get_cdm_viewer_frame` dropped from 4.575ms to 1.767ms. The core CDM
map walk did not improve per call: `add_cooldown_viewer_category_entries`
averaged 0.1007ms versus 0.0932ms in the clean follow-up, so further CDM work
needs to target the map walk itself or reduce how often visible CDM frames need a
full rebuild.

### 2026-06-23, Aura Frames Only, Visible Ticker Return State

Context: 60.3s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
`tick_visible_icons()` to return whether any visible icon still needs ticking so
the ticker callback can avoid a second full `any_frame_needs_visible_icon_tick()`
scan after each tick.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 927 | 460.546 | 0.4968 | 2.913 |
| `aura_frames.render_aura_map` | 927 | 185.192 | 0.1998 | 1.213 |
| `aura_frames.tick_visible_icons` | 549 | 184.989 | 0.3370 | 0.858 |
| `aura_frames.add_cooldown_viewer_category_entries` | 552 | 58.672 | 0.1063 | 0.505 |
| `aura_frames.unified_scan` | 82 | 57.880 | 0.7059 | 1.880 |
| `aura_frames.set_timer_text` | 10192 | 51.626 | 0.0051 | 0.196 |
| `aura_frames.scan_custom_aura_map` | 75 | 44.583 | 0.5944 | 1.878 |
| `aura_frames.get_frame_activity_state` | 3736 | 33.486 | 0.0090 | 0.292 |
| `aura_frames.get_setting` | 8609 | 20.423 | 0.0024 | 0.706 |
| `aura_frames.refresh_frame_ooc_fade` | 928 | 18.188 | 0.0196 | 0.278 |
| `aura_frames.is_timer_text_enabled` | 927 | 12.426 | 0.0134 | 0.044 |
| `aura_frames.is_runtime_enabled` | 1479 | 12.360 | 0.0084 | 0.108 |
| `aura_frames.get_timer_behavior` | 1929 | 11.411 | 0.0059 | 0.046 |
| `aura_frames.get_frame_config_db` | 3738 | 7.674 | 0.0021 | 0.032 |
| `aura_frames.normalize_timer_category` | 2856 | 7.183 | 0.0025 | 0.038 |
| `aura_frames.mark_aura_scan_dirty` | 894 | 7.026 | 0.0079 | 0.082 |
| `aura_frames.get_bar_bg_color` | 927 | 6.672 | 0.0072 | 0.036 |
| `aura_frames.merge_aura_info` | 882 | 5.430 | 0.0062 | 0.039 |
| `aura_frames.uses_cooldown_icon_overlay` | 927 | 2.160 | 0.0023 | 0.104 |
| `aura_frames.clear_sorted_aura_ids_cache` | 976 | 1.705 | 0.0017 | 0.031 |
| `aura_frames.get_cdm_viewer_frame` | 564 | 1.627 | 0.0029 | 0.035 |
| `aura_frames.refresh_visible_icon_ticker` | 927 | 1.516 | 0.0016 | 0.015 |
| `aura_frames.clear_custom_aura_scan_cache` | 894 | 1.358 | 0.0015 | 0.014 |
| `aura_frames.prepare_blizz_cdm_viewer` | 552 | 1.092 | 0.0020 | 0.022 |
| `aura_frames.get_custom_aura_filter` | 75 | 0.596 | 0.0080 | 0.022 |

Conclusion: The intended redundant eligibility scan was removed from the profile:
`any_frame_needs_visible_icon_tick` no longer appears in the report, while
`refresh_visible_icon_ticker` is only 1.516ms over 60.3s. The ticker's own per-call
cost stayed in the same range, as expected, because the live timer/bar update work
is unchanged.

### Template

Context:

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `example.metric` | 0 | 0.000 | 0.0000 | 0.000 |

Conclusion:

