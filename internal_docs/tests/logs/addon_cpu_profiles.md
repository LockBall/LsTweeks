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

### Template

Context:

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `example.metric` | 0 | 0.000 | 0.0000 | 0.000 |

Conclusion:
