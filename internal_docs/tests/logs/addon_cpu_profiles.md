# Whole-Addon CPU Profiles

Long-term capture for broad LsTweeks in-game profiling runs. Use
`internal_docs/tests/addon_cpu_profile.lua` when looking for true addon hot paths
across modules.

This profiler wraps addon-owned functions only. Do not wrap Blizzard/global APIs
such as `UnitPower`, `UnitHealthPercent`, or `C_UnitAuras` from this broad probe;
that can taint Blizzard unit-frame execution when secret values are involved.

## How To Collect

1. Temporarily load `internal_docs/tests/addon_cpu_profile.lua` after
   `modules/aura_frames/af_main.lua` in `LsTweeks.toc`.
2. `/reload`.
3. Run `/lstprofile start`.
4. Exercise normal gameplay and settings flows for 2-3 minutes:
   aura updates, CDM updates, Skyriding Vigor visibility, Sound Levels previews,
   Fishing Focus if relevant, and opening/changing addon settings.
5. Run `/lstprofile report 40`, copy the output here, then run `/lstprofile stop`.
6. Remove the temporary TOC line and `/reload`.

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

### Template

Context:

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `example.metric` | 0 | 0.000 | 0.0000 | 0.000 |

Conclusion:
