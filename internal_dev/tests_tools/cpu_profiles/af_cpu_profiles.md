# Aura Frames CPU Profiles
Long-term capture for Aura Frames focused in-game profiling runs.

Whole-addon run sections include `cpu-profile-run` metadata comments so
`analyze_af_cpu_profiles.ps1` can rebuild
time-normalized and ticker-normalized comparisons from the saved data.


## Table of Contents
- [Historical June Improvement Summary](#historical-june-improvement-summary)
- [Whole-Addon Profiler Runs](#whole-addon-profiler-runs)
- [Aura Frames Duration Probe](#aura-frames-duration-probe)
- [Current Decision](#current-decision)
- [How To Collect](#how-to-collect)
- [Runs](#runs)


## Historical June Improvement Summary
Historical table generated with `analyze_af_cpu_profiles.ps1`. Baseline is
`2026-06-22, Aura Frames Only`. Raw elapsed `ms/sec` is the measured CPU rate
for each run; ticker-normalized values estimate what `af.tick_visible_icons`
would cost at the reference `0.10s` ticker cadence. This table documents the
June optimization sequence; current decisions use the 2026-08-31 post-migration
baseline archived below.

| Run | Elapsed | Combat | Tick | `af.update_auras` ms/sec | Change | `af.render_aura_map` ms/sec | Change | `af.tick_visible_icons` ms/sec | Change | Tick norm ms/sec | Change | `af.get_setting` ms/sec | Change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `2026-06-27, Current Combat Check` | 98.6 | 97.5 | 0.15 | 6.43 | -13.7% | 2.97 | +0.4% | 1.91 | -29.9% | 2.87 | +5.1% | 0.12 | -62.3% |
| `2026-06-24, Tick 0.20s Combat Test` | 62.0 | 60.1 | 0.20 | 6.03 | -19.0% | 2.82 | -4.9% | 1.45 | -46.8% | 2.91 | +6.4% | 0.12 | -64.3% |
| `2026-06-24, Tick 0.15s Combat Test` | 51.0 | 49.2 | 0.15 | 6.70 | -10.1% | 3.07 | +3.5% | 1.95 | -28.6% | 2.93 | +7.1% | 0.13 | -60.4% |
| `2026-06-24, Provisional Slider Test` | 67.3 |  |  | 5.61 | -24.7% | 2.59 | -12.6% | 1.72 | -36.9% |  |  | 0.11 | -66.5% |
| `2026-06-24, Tick 0.10s Combat Baseline` | 75.5 | 72.2 | 0.10 | 6.90 | -7.4% | 3.14 | +5.9% | 2.85 | +4.4% | 2.85 | +4.4% | 0.13 | -59.0% |
| `2026-06-23, Runtime Color Cache` | 107.1 |  | 0.10 | 5.36 | -28.1% | 2.46 | -16.8% | 2.59 | -5.2% | 2.59 | -5.2% | 0.10 | -68.3% |
| `2026-06-23, Runtime Config Cache` | 133.4 |  | 0.10 | 5.31 | -28.7% | 2.35 | -20.7% | 2.56 | -6.4% | 2.56 | -6.4% | 0.20 | -40.3% |
| `2026-06-23, Visible Ticker Return State` | 60.3 |  | 0.10 | 7.64 | +2.6% | 3.07 | +3.7% | 3.07 | +12.3% | 3.07 | +12.3% | 0.34 | +3.4% |
| `2026-06-23, Category-Scoped CDM Hook Refresh` | 61.1 |  | 0.10 | 8.10 | +8.8% | 3.25 | +9.7% | 2.99 | +9.3% | 2.99 | +9.3% | 0.34 | +4.3% |
| `2026-06-23, Clean Comparison` | 88.1 |  | 0.10 | 6.43 | -13.6% | 2.51 | -15.2% | 2.55 | -6.7% | 2.55 | -6.7% | 0.29 | -10.4% |
| `2026-06-23, Scan/Map Sub-Steps` | 64.9 |  | 0.10 | 7.89 | +6.0% | 3.22 | +8.6% | 2.92 | +6.8% | 2.92 | +6.8% | 0.34 | +2.4% |
| `2026-06-23, Preset Bucket Direct Render` | 84.7 |  | 0.10 | 8.60 | +15.4% | 3.66 | +23.8% | 3.31 | +21.2% | 3.31 | +21.2% | 0.35 | +6.4% |
| `2026-06-23, Render Display Signature` | 117.3 |  | 0.10 | 8.62 | +15.8% | 3.58 | +20.9% | 3.18 | +16.3% | 3.18 | +16.3% | 0.37 | +11.5% |
| `2026-06-22, Render Timer Behavior Cache` | 78.7 |  | 0.10 | 9.05 | +21.5% | 3.61 | +22.1% | 3.21 | +17.5% | 3.21 | +17.5% | 0.38 | +17.2% |
| `2026-06-22, Update Sub-Steps` | 77.2 |  | 0.10 | 9.69 | +30.1% | 3.98 | +34.3% | 3.30 | +20.7% | 3.30 | +20.7% | 0.38 | +15.3% |
| `2026-06-22, Post-OOC Fast Path` | 90.1 |  | 0.10 | 6.56 | -11.9% | 2.57 | -13.3% | 2.40 | -12.2% | 2.40 | -12.2% | 0.30 | -7.9% |
| `2026-06-22, Baseline` | 90.6 |  | 0.10 | 7.45 | 0.0% | 2.96 | 0.0% | 2.73 | 0.0% | 2.73 | 0.0% | 0.33 | 0.0% |

Result: `af.update_auras` and `af.get_setting` show real sustained improvement.
`af.tick_visible_icons` raw CPU rate is much lower in newer runs, but the
ticker-normalized column shows most of that win comes from the slower ticker
cadence rather than lower per-tick cost.


## Whole-Addon Profiler Runs
Use `../addon_cpu_profile.lua` with only `PROFILE_TARGETS.aura_frames = true` for these runs.


### 2026-09-01, Aura Frames Only, Post Event-Routing Optimization
<!-- cpu-profile-run: elapsed=92.2 combat=90.8 timer_tick=0.15 -->

Context: 92.2s accepted post-change run with 90.8s combat (98.5%), one segment,
and the report captured while combat remained active. Timer Tick was `0.15s`,
both Essential and Utility used Cooldown Mode, and no Test Auras or Custom
Filtered frames were enabled. The user completed the documented Tracked Aura,
first-cast, managed Aura-overlay, expiration/handoff, and charged-ability live
checks before saving the validation inbox; no behavior issue was reported.

| Event | Category | Mode | Received | Scheduled | Coalesced | Ignored |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Essential | Cooldown | 32 | 15 | 17 | 0 |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Tracked Bars | Aura | 32 | 29 | 3 | 0 |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Tracked Buffs | Aura | 32 | 29 | 3 | 0 |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Utility | Cooldown | 32 | 15 | 17 | 0 |
| `PLAYER_REGEN_DISABLED` | Essential | Cooldown | 1 | 1 | 0 | 0 |
| `PLAYER_REGEN_DISABLED` | Tracked Bars | Aura | 1 | 1 | 0 | 0 |
| `PLAYER_REGEN_DISABLED` | Tracked Buffs | Aura | 1 | 1 | 0 | 0 |
| `PLAYER_REGEN_DISABLED` | Utility | Cooldown | 1 | 1 | 0 | 0 |
| `SPELL_UPDATE_CHARGES` | Essential | Cooldown | 69 | 26 | 43 | 0 |
| `SPELL_UPDATE_CHARGES` | Tracked Bars | Aura | 69 | 0 | 0 | 69 |
| `SPELL_UPDATE_CHARGES` | Tracked Buffs | Aura | 69 | 0 | 0 | 69 |
| `SPELL_UPDATE_CHARGES` | Utility | Cooldown | 69 | 26 | 43 | 0 |
| `SPELL_UPDATE_COOLDOWN` | Essential | Cooldown | 928 | 208 | 720 | 0 |
| `SPELL_UPDATE_COOLDOWN` | Tracked Bars | Aura | 928 | 0 | 0 | 928 |
| `SPELL_UPDATE_COOLDOWN` | Tracked Buffs | Aura | 928 | 0 | 0 | 928 |
| `SPELL_UPDATE_COOLDOWN` | Utility | Cooldown | 928 | 208 | 720 | 0 |
| `UNIT_AURA` | Essential | Cooldown | 228 | 0 | 0 | 228 |
| `UNIT_AURA` | Tracked Bars | Aura | 228 | 0 | 0 | 228 |
| `UNIT_AURA` | Tracked Buffs | Aura | 228 | 0 | 0 | 228 |
| `UNIT_AURA` | Utility | Cooldown | 228 | 0 | 0 | 228 |

| Metric | Calls | Total ms | Avg ms | Max ms | Combat ms/sec | Combat calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `af.update_auras` | 572 | 610.277 | 1.0669 | 3.717 | 6.723 | 6.30 |
| `af.add_cooldown_viewer_category_entries` | 506 | 345.405 | 0.6826 | 3.180 | 3.805 | 5.57 |
| `af.render_aura_map` | 572 | 187.626 | 0.3280 | 1.479 | 2.067 | 6.30 |
| `af.get_ordered_cdm_records` | 506 | 102.004 | 0.2016 | 2.707 | 1.124 | 5.57 |
| `af.get_frame_activity_state` | 5608 | 76.677 | 0.0137 | 0.115 | 0.845 | 61.78 |
| `af.tick_visible_icons` | 577 | 47.191 | 0.0818 | 0.243 | 0.520 | 6.36 |
| `af.is_global_test_aura_enabled` | 5607 | 23.458 | 0.0042 | 0.087 | 0.258 | 61.77 |
| `af.refresh_frame_ooc_fade` | 572 | 13.949 | 0.0244 | 0.216 | 0.154 | 6.30 |
| `af.is_runtime_enabled` | 1728 | 11.710 | 0.0068 | 0.061 | 0.129 | 19.04 |
| `af.refresh_visible_icon_ticker` | 572 | 11.607 | 0.0203 | 0.131 | 0.128 | 6.30 |
| `af.any_frame_needs_visible_icon_tick` | 572 | 9.023 | 0.0158 | 0.126 | 0.099 | 6.30 |
| `af.get_frame_config_db` | 5612 | 7.739 | 0.0014 | 0.065 | 0.085 | 61.83 |
| `af.frame_supports_test_aura` | 5608 | 7.407 | 0.0013 | 0.047 | 0.082 | 61.78 |
| `af.refresh_managed_cdm_backend` | 572 | 5.913 | 0.0103 | 0.034 | 0.065 | 6.30 |
| `af.frame_needs_visible_icon_tick` | 2288 | 5.699 | 0.0025 | 0.111 | 0.063 | 25.21 |
| `af.prewarm_aura_tooltip_cache` | 576 | 5.192 | 0.0090 | 0.066 | 0.057 | 6.35 |
| `af.should_process_aura_frame_event` | 5032 | 5.167 | 0.0010 | 0.048 | 0.057 | 55.44 |
| `af.update_aura_frame_move_controls` | 572 | 4.860 | 0.0085 | 0.232 | 0.054 | 6.30 |
| `af.get_setting` | 2205 | 4.017 | 0.0018 | 0.058 | 0.044 | 24.29 |
| `af.set_managed_aura_backend_enabled` | 572 | 4.013 | 0.0070 | 0.025 | 0.044 | 6.30 |
| `af.apply_addon_frame_background` | 572 | 3.732 | 0.0065 | 0.087 | 0.041 | 6.30 |
| `af.get_timer_behavior` | 572 | 3.653 | 0.0064 | 0.035 | 0.040 | 6.30 |
| `af.set_managed_cdm_move_outline_shown` | 572 | 3.335 | 0.0058 | 0.023 | 0.037 | 6.30 |
| `af.set_shown_if_changed` | 1144 | 2.938 | 0.0026 | 0.219 | 0.032 | 12.60 |
| `af.normalize_timer_category` | 572 | 2.148 | 0.0038 | 0.033 | 0.024 | 6.30 |
| `af.get_aura_frame_height` | 572 | 1.720 | 0.0030 | 0.040 | 0.019 | 6.30 |
| `af.update_combat_background` | 572 | 1.403 | 0.0025 | 0.056 | 0.015 | 6.30 |
| `af.queue_learned_buff_scan` | 228 | 1.377 | 0.0060 | 0.027 | 0.015 | 2.51 |
| `af.apply_aura_frame_shell_transform` | 572 | 0.871 | 0.0015 | 0.015 | 0.010 | 6.30 |
| `af.invalidate_aura_scan_caches` | 135 | 0.863 | 0.0064 | 0.061 | 0.010 | 1.49 |
| `af.ensure_blizz_cdm_loaded` | 506 | 0.663 | 0.0013 | 0.015 | 0.007 | 5.57 |
| `af.ensure_visible_icon_ticker` | 572 | 0.587 | 0.0010 | 0.011 | 0.006 | 6.30 |
| `af.get_frame_def` | 506 | 0.572 | 0.0011 | 0.013 | 0.006 | 5.57 |
| `af.learn_helpful_aura_durations_ooc` | 169 | 0.554 | 0.0033 | 0.029 | 0.006 | 1.86 |
| `af.clear_custom_aura_scan_cache` | 135 | 0.269 | 0.0020 | 0.055 | 0.003 | 1.49 |
| `af.clear_sorted_aura_ids_cache` | 135 | 0.177 | 0.0013 | 0.016 | 0.002 | 1.49 |
| `af.register_managed_frame_background_row` | 10 | 0.170 | 0.0170 | 0.026 | 0.002 | 0.11 |
| `af.refresh_frame_fade_for_combat_state` | 4 | 0.148 | 0.0369 | 0.073 | 0.002 | 0.04 |
| `af.resolve_text_color` | 10 | 0.135 | 0.0135 | 0.057 | 0.001 | 0.11 |
| `af.resolve_bar_color` | 10 | 0.133 | 0.0133 | 0.022 | 0.001 | 0.11 |

Assessment: the accepted event predicate produced the exact intended routing.
All CDM `UNIT_AURA` events were ignored; Tracked Aura-mode cooldown/charge
events were ignored; Essential/Utility cooldown-mode cooldown/charge events
remained scheduled or coalesced. Against the 2026-08-31 baseline,
`af.update_auras` call rate fell from `10.56` to `6.30 calls/sec` (40.3%) and
combat-normalized cost fell from `9.245` to `6.723ms/sec` (27.3%). CDM map,
render, ticker, and activity-state costs also fell. The event predicate itself
cost only `0.057ms/sec`. Remaining CDM work is tied to relevant cooldown events;
further caching would add a broader invalidation contract for only
`1.124ms/sec` of measured record discovery, so no additional optimization is
accepted in this pass.


### 2026-09-01, Aura Frames Only, Event and Mode Attribution
<!-- cpu-profile-run: elapsed=95.9 combat=73.2 timer_tick=0.15 -->

Context: 95.9s diagnostic run with both Essential and Utility Cooldown Mode
settings restored. Combat was active for 73.2s (76.4%), so this run is not a
matched CPU comparison. Its event/category/mode counters remain valid for event
ownership: the temporary probe counted each delivered event after the existing
handler and distinguished scheduled, coalesced, and ignored scans.

| Event | Category | Mode | Received | Scheduled | Coalesced | Ignored |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Essential | Cooldown | 33 | 15 | 18 | 0 |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Tracked Bars | Aura | 33 | 15 | 18 | 0 |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Tracked Buffs | Aura | 33 | 15 | 18 | 0 |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Utility | Cooldown | 33 | 15 | 18 | 0 |
| `PLAYER_REGEN_DISABLED` | Essential | Cooldown | 1 | 1 | 0 | 0 |
| `PLAYER_REGEN_DISABLED` | Tracked Bars | Aura | 1 | 1 | 0 | 0 |
| `PLAYER_REGEN_DISABLED` | Tracked Buffs | Aura | 1 | 1 | 0 | 0 |
| `PLAYER_REGEN_DISABLED` | Utility | Cooldown | 1 | 1 | 0 | 0 |
| `SPELL_UPDATE_CHARGES` | Essential | Cooldown | 64 | 11 | 53 | 0 |
| `SPELL_UPDATE_CHARGES` | Tracked Bars | Aura | 64 | 11 | 53 | 0 |
| `SPELL_UPDATE_CHARGES` | Tracked Buffs | Aura | 64 | 11 | 53 | 0 |
| `SPELL_UPDATE_CHARGES` | Utility | Cooldown | 64 | 11 | 53 | 0 |
| `SPELL_UPDATE_COOLDOWN` | Essential | Cooldown | 809 | 100 | 709 | 0 |
| `SPELL_UPDATE_COOLDOWN` | Tracked Bars | Aura | 809 | 100 | 709 | 0 |
| `SPELL_UPDATE_COOLDOWN` | Tracked Buffs | Aura | 809 | 100 | 709 | 0 |
| `SPELL_UPDATE_COOLDOWN` | Utility | Cooldown | 809 | 100 | 709 | 0 |
| `UNIT_AURA` | Essential | Cooldown | 197 | 89 | 108 | 0 |
| `UNIT_AURA` | Tracked Bars | Aura | 197 | 89 | 108 | 0 |
| `UNIT_AURA` | Tracked Buffs | Aura | 197 | 89 | 108 | 0 |
| `UNIT_AURA` | Utility | Cooldown | 197 | 89 | 108 | 0 |

| Metric | Calls | Total ms | Avg ms | Max ms | Combat ms/sec | Combat calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `af.update_auras` | 876 | 593.561 | 0.6776 | 3.670 | 8.106 | 11.96 |
| `af.add_cooldown_viewer_category_entries` | 438 | 293.997 | 0.6712 | 3.033 | 4.015 | 5.98 |
| `af.render_aura_map` | 876 | 170.509 | 0.1946 | 0.612 | 2.328 | 11.96 |
| `af.get_ordered_cdm_records` | 438 | 89.848 | 0.2051 | 2.254 | 1.227 | 5.98 |
| `af.get_frame_activity_state` | 5296 | 73.087 | 0.0138 | 0.232 | 0.998 | 72.32 |
| `af.tick_visible_icons` | 597 | 48.186 | 0.0807 | 0.182 | 0.658 | 8.15 |
| `af.refresh_managed_cdm_backend` | 876 | 38.104 | 0.0435 | 2.080 | 0.520 | 11.96 |
| `af.is_global_test_aura_enabled` | 5295 | 21.676 | 0.0041 | 0.212 | 0.296 | 72.31 |
| `af.for_each_accessible_managed_aura_button` | 40 | 21.284 | 0.5321 | 0.912 | 0.291 | 0.55 |
| `af.refresh_frame_ooc_fade` | 876 | 16.543 | 0.0189 | 0.193 | 0.226 | 11.96 |
| `af.refresh_visible_icon_ticker` | 876 | 15.889 | 0.0181 | 0.071 | 0.217 | 11.96 |
| `af.is_runtime_enabled` | 2356 | 12.554 | 0.0053 | 0.069 | 0.171 | 32.17 |
| `af.any_frame_needs_visible_icon_tick` | 876 | 12.290 | 0.0140 | 0.066 | 0.168 | 11.96 |
| `af.is_managed_aura_button_accessible` | 5660 | 9.614 | 0.0017 | 0.052 | 0.131 | 77.29 |
| `af.apply_managed_icon_swipe_style` | 20 | 8.622 | 0.4311 | 0.621 | 0.118 | 0.27 |
| `af.frame_needs_visible_icon_tick` | 3504 | 7.402 | 0.0021 | 0.049 | 0.101 | 47.85 |
| `af.get_frame_config_db` | 5300 | 7.366 | 0.0014 | 0.050 | 0.101 | 72.38 |
| `af.frame_supports_test_aura` | 5296 | 7.288 | 0.0014 | 0.115 | 0.100 | 72.32 |
| `af.prewarm_aura_tooltip_cache` | 880 | 6.499 | 0.0074 | 0.125 | 0.089 | 12.02 |
| `af.update_aura_frame_move_controls` | 876 | 5.982 | 0.0068 | 0.064 | 0.082 | 11.96 |
| `af.set_managed_aura_backend_enabled` | 876 | 5.403 | 0.0062 | 0.024 | 0.074 | 11.96 |
| `af.get_setting` | 3103 | 5.368 | 0.0017 | 0.057 | 0.073 | 42.38 |
| `af.invalidate_aura_scan_caches` | 927 | 5.343 | 0.0058 | 0.108 | 0.073 | 12.66 |
| `af.apply_addon_frame_background` | 876 | 4.819 | 0.0055 | 0.043 | 0.066 | 11.96 |
| `af.get_timer_behavior` | 876 | 4.761 | 0.0054 | 0.070 | 0.065 | 11.96 |
| `af.set_managed_cdm_move_outline_shown` | 876 | 4.696 | 0.0054 | 0.024 | 0.064 | 11.96 |
| `af.set_shown_if_changed` | 1752 | 3.347 | 0.0019 | 0.057 | 0.046 | 23.93 |
| `af.normalize_timer_category` | 876 | 2.550 | 0.0029 | 0.059 | 0.035 | 11.96 |
| `af.get_aura_frame_height` | 876 | 2.098 | 0.0024 | 0.023 | 0.029 | 11.96 |
| `af.update_combat_background` | 876 | 1.741 | 0.0020 | 0.020 | 0.024 | 11.96 |
| `af.set_managed_presentation_bar_color` | 1375 | 1.714 | 0.0012 | 0.006 | 0.023 | 18.78 |
| `af.apply_aura_frame_shell_transform` | 876 | 1.605 | 0.0018 | 0.061 | 0.022 | 11.96 |
| `af.apply_managed_presentation_chrome` | 10 | 1.429 | 0.1429 | 0.170 | 0.020 | 0.14 |
| `af.apply_number_font_style` | 20 | 1.255 | 0.0628 | 0.190 | 0.017 | 0.27 |
| `af.set_managed_presentation_bar_width` | 1375 | 1.241 | 0.0009 | 0.016 | 0.017 | 18.78 |
| `af.clear_custom_aura_scan_cache` | 927 | 1.166 | 0.0013 | 0.086 | 0.016 | 12.66 |
| `af.clear_sorted_aura_ids_cache` | 927 | 1.118 | 0.0012 | 0.103 | 0.015 | 12.66 |
| `af.apply_managed_frame_background` | 10 | 1.077 | 0.1077 | 0.130 | 0.015 | 0.14 |
| `af.queue_learned_buff_scan` | 197 | 0.956 | 0.0049 | 0.022 | 0.013 | 2.69 |
| `af.ensure_visible_icon_ticker` | 876 | 0.893 | 0.0010 | 0.017 | 0.012 | 11.96 |

Assessment: Aura-mode Tracked Buffs/Bars each scheduled 200 scans from
`UNIT_AURA`, spell-cooldown, and charge events; cooldown-mode Essential/Utility
each scheduled 89 scans from `UNIT_AURA`. These 578 scans were 66.0% of the 876
measured `update_auras` calls. They are owned by managed Aura transport or do not
drive the active addon layer. The accepted change rejects `UNIT_AURA` for every
CDM shell and rejects spell-cooldown/charge events when the shell is in Aura
mode, while retaining viewer-data/override, specialization, world-entry, combat,
and cooldown-mode spell events.


### 2026-09-01, Aura Frames Only, Essential and Utility Cooldown Modes Disabled
<!-- cpu-profile-run: elapsed=81.7 combat=79.5 timer_tick=0.15 -->

Context: 81.7s matched control with only `PROFILE_TARGETS.aura_frames = true`.
Combat was active for 79.5s, 97.3% of elapsed time, one segment, and the report
was captured while combat remained active. Timer Tick was `0.15s`; Retribution
specialization (`70`) was active; Essential and Utility remained enabled but
both Cooldown Mode settings were disabled. Tracked Buffs, Tracked Bars, and
Debuffs were unchanged. No Test Auras or Custom Filtered frames were enabled.

| Metric | Calls | Total ms | Avg ms | Max ms | Combat ms/sec | Combat calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `af.update_auras` | 832 | 123.879 | 0.1489 | 0.475 | 1.558 | 10.47 |
| `af.get_frame_activity_state` | 4873 | 68.572 | 0.0141 | 0.285 | 0.863 | 61.30 |
| `af.render_aura_map` | 832 | 29.119 | 0.0350 | 0.132 | 0.366 | 10.47 |
| `af.refresh_visible_icon_ticker` | 832 | 21.449 | 0.0258 | 0.108 | 0.270 | 10.47 |
| `af.is_global_test_aura_enabled` | 4872 | 19.610 | 0.0040 | 0.068 | 0.247 | 61.29 |
| `af.any_frame_needs_visible_icon_tick` | 832 | 18.264 | 0.0220 | 0.101 | 0.230 | 10.47 |
| `af.refresh_frame_ooc_fade` | 832 | 14.124 | 0.0170 | 0.214 | 0.178 | 10.47 |
| `af.frame_needs_visible_icon_tick` | 6656 | 10.661 | 0.0016 | 0.050 | 0.134 | 83.73 |
| `af.refresh_managed_cdm_backend` | 832 | 7.521 | 0.0090 | 0.152 | 0.095 | 10.47 |
| `af.get_frame_config_db` | 4878 | 7.241 | 0.0015 | 0.265 | 0.091 | 61.37 |
| `af.frame_supports_test_aura` | 4873 | 7.033 | 0.0014 | 0.062 | 0.088 | 61.30 |
| `af.update_aura_frame_move_controls` | 832 | 5.847 | 0.0070 | 0.092 | 0.074 | 10.47 |
| `af.is_runtime_enabled` | 1671 | 5.761 | 0.0034 | 0.030 | 0.072 | 21.02 |
| `af.invalidate_aura_scan_caches` | 947 | 5.103 | 0.0054 | 0.026 | 0.064 | 11.91 |
| `af.set_managed_aura_backend_enabled` | 832 | 4.803 | 0.0058 | 0.148 | 0.060 | 10.47 |
| `af.get_setting` | 2721 | 4.537 | 0.0017 | 0.018 | 0.057 | 34.23 |
| `af.apply_addon_frame_background` | 832 | 4.373 | 0.0053 | 0.031 | 0.055 | 10.47 |
| `af.set_managed_cdm_move_outline_shown` | 832 | 4.290 | 0.0052 | 0.027 | 0.054 | 10.47 |
| `af.prewarm_aura_tooltip_cache` | 836 | 4.265 | 0.0051 | 0.033 | 0.054 | 10.52 |
| `af.get_timer_behavior` | 832 | 3.859 | 0.0046 | 0.028 | 0.049 | 10.47 |
| `af.set_shown_if_changed` | 1664 | 3.354 | 0.0020 | 0.085 | 0.042 | 20.93 |
| `af.normalize_timer_category` | 832 | 1.968 | 0.0024 | 0.017 | 0.025 | 10.47 |
| `af.update_combat_background` | 832 | 1.689 | 0.0020 | 0.026 | 0.021 | 10.47 |
| `af.get_aura_frame_height` | 832 | 1.550 | 0.0019 | 0.124 | 0.019 | 10.47 |
| `af.apply_aura_frame_shell_transform` | 832 | 1.406 | 0.0017 | 0.013 | 0.018 | 10.47 |
| `af.clear_custom_aura_scan_cache` | 947 | 1.075 | 0.0011 | 0.017 | 0.014 | 11.91 |
| `af.clear_sorted_aura_ids_cache` | 947 | 1.037 | 0.0011 | 0.014 | 0.013 | 11.91 |
| `af.queue_learned_buff_scan` | 207 | 0.843 | 0.0041 | 0.018 | 0.011 | 2.60 |
| `af.stop_visible_icon_ticker` | 832 | 0.704 | 0.0008 | 0.010 | 0.009 | 10.47 |
| `af.learn_helpful_aura_durations_ooc` | 144 | 0.444 | 0.0031 | 0.006 | 0.006 | 1.81 |
| `af.register_managed_frame_background_row` | 10 | 0.168 | 0.0168 | 0.023 | 0.002 | 0.13 |
| `af.refresh_frame_fade_for_combat_state` | 4 | 0.151 | 0.0379 | 0.063 | 0.002 | 0.05 |
| `af.resolve_bar_color` | 10 | 0.135 | 0.0135 | 0.018 | 0.002 | 0.13 |
| `af.update_all_blizz_cdm_visibility` | 3 | 0.132 | 0.0440 | 0.062 | 0.002 | 0.04 |
| `af.update_blizz_cdm_visibility` | 12 | 0.100 | 0.0084 | 0.023 | 0.001 | 0.15 |
| `af.resolve_text_color` | 10 | 0.090 | 0.0090 | 0.012 | 0.001 | 0.13 |
| `af.get_preset_keys` | 12 | 0.085 | 0.0071 | 0.026 | 0.001 | 0.15 |
| `af.get_color_consumer_group` | 20 | 0.080 | 0.0040 | 0.008 | 0.001 | 0.25 |
| `af.get_bar_bg_color` | 10 | 0.057 | 0.0057 | 0.010 | 0.001 | 0.13 |
| `af.queue_wow_cooldown_refresh` | 4 | 0.056 | 0.0141 | 0.029 | 0.001 | 0.05 |

Assessment: disabling only the two cooldown modes left `af.update_auras` call
rate effectively unchanged (`10.47` versus `10.56 calls/sec`) but reduced its
combat-normalized cost from `9.245` to `1.558ms/sec` (83.1%).
`af.render_aura_map` fell from `2.725` to `0.366ms/sec` (86.6%), and
`af.add_cooldown_viewer_category_entries` plus `af.get_ordered_cdm_records`
disappeared from the top 40 entirely. Individual managed-backend refresh and
enable paths remained immaterial. This isolates the major cost to rebuilding
the addon cooldown maps, not to cooldown mode increasing event frequency. It
does not support record-sharing or broad backend invalidation work as the first
change; event/mode attribution should determine which updates unnecessarily
rebuild those maps before changing scan ownership.


### 2026-08-31, Aura Frames Only, Post-Migration Baseline
<!-- cpu-profile-run: elapsed=100.2 combat=98.5 timer_tick=0.15 -->

Context: 100.2s run with only `PROFILE_TARGETS.aura_frames = true`. Combat was
active for 98.5s, 98.3% of elapsed time, one segment, and the report was captured
while combat remained active. Timer Tick was `0.15s`; Retribution specialization
(`70`) was active; Essential and Utility cooldown modes were enabled; no Test
Auras or Custom Filtered frames were enabled. Seven of eight Aura Frames were
shown. Managed AuraButtons reported `accessible=0` because status was captured
in combat.

| Metric | Calls | Total ms | Avg ms | Max ms | Combat ms/sec | Combat calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1040 | 910.462 | 0.8754 | 5.538 | 9.245 | 10.56 |
| `af.add_cooldown_viewer_category_entries` | 520 | 476.573 | 0.9165 | 4.611 | 4.839 | 5.28 |
| `af.render_aura_map` | 1040 | 268.383 | 0.2581 | 0.775 | 2.725 | 10.56 |
| `af.get_ordered_cdm_records` | 520 | 139.906 | 0.2691 | 3.341 | 1.421 | 5.28 |
| `af.get_frame_activity_state` | 6124 | 115.833 | 0.0189 | 0.244 | 1.176 | 62.18 |
| `af.tick_visible_icons` | 601 | 60.451 | 0.1006 | 1.035 | 0.614 | 6.10 |
| `af.is_global_test_aura_enabled` | 6123 | 34.602 | 0.0057 | 0.224 | 0.351 | 62.17 |
| `af.refresh_frame_ooc_fade` | 1040 | 28.387 | 0.0273 | 0.401 | 0.288 | 10.56 |
| `af.refresh_visible_icon_ticker` | 1040 | 26.071 | 0.0251 | 0.070 | 0.265 | 10.56 |
| `af.any_frame_needs_visible_icon_tick` | 1040 | 20.184 | 0.0194 | 0.064 | 0.205 | 10.56 |
| `af.is_runtime_enabled` | 2688 | 19.296 | 0.0072 | 0.551 | 0.196 | 27.29 |
| `af.refresh_managed_cdm_backend` | 1040 | 14.430 | 0.0139 | 0.609 | 0.147 | 10.56 |
| `af.frame_needs_visible_icon_tick` | 4160 | 12.757 | 0.0031 | 0.039 | 0.130 | 42.24 |
| `af.get_frame_config_db` | 6128 | 11.767 | 0.0019 | 0.111 | 0.119 | 62.22 |
| `af.frame_supports_test_aura` | 6124 | 11.100 | 0.0018 | 0.028 | 0.113 | 62.18 |
| `af.prewarm_aura_tooltip_cache` | 1044 | 10.973 | 0.0105 | 0.044 | 0.111 | 10.60 |
| `af.set_managed_aura_backend_enabled` | 1040 | 9.798 | 0.0094 | 0.599 | 0.099 | 10.56 |
| `af.update_aura_frame_move_controls` | 1040 | 9.580 | 0.0092 | 0.046 | 0.097 | 10.56 |
| `af.apply_addon_frame_background` | 1040 | 8.496 | 0.0082 | 0.196 | 0.086 | 10.56 |
| `af.get_timer_behavior` | 1040 | 8.068 | 0.0078 | 0.035 | 0.082 | 10.56 |
| `af.set_managed_cdm_move_outline_shown` | 1040 | 7.683 | 0.0074 | 0.038 | 0.078 | 10.56 |
| `af.invalidate_aura_scan_caches` | 1107 | 7.602 | 0.0069 | 0.043 | 0.077 | 11.24 |
| `af.get_setting` | 3396 | 7.459 | 0.0022 | 0.021 | 0.076 | 34.48 |
| `af.set_shown_if_changed` | 2080 | 5.140 | 0.0025 | 0.038 | 0.052 | 21.12 |
| `af.normalize_timer_category` | 1040 | 4.419 | 0.0042 | 0.030 | 0.045 | 10.56 |
| `af.get_aura_frame_height` | 1040 | 3.673 | 0.0035 | 0.028 | 0.037 | 10.56 |
| `af.update_combat_background` | 1040 | 3.115 | 0.0030 | 0.185 | 0.032 | 10.56 |
| `af.apply_aura_frame_shell_transform` | 1040 | 2.132 | 0.0020 | 0.026 | 0.022 | 10.56 |
| `af.clear_custom_aura_scan_cache` | 1107 | 1.622 | 0.0015 | 0.016 | 0.016 | 11.24 |
| `af.clear_sorted_aura_ids_cache` | 1107 | 1.589 | 0.0014 | 0.016 | 0.016 | 11.24 |
| `af.ensure_visible_icon_ticker` | 1040 | 1.485 | 0.0014 | 0.022 | 0.015 | 10.56 |
| `af.queue_learned_buff_scan` | 238 | 1.481 | 0.0062 | 0.043 | 0.015 | 2.42 |
| `af.ensure_blizz_cdm_loaded` | 520 | 0.877 | 0.0017 | 0.022 | 0.009 | 5.28 |
| `af.get_frame_def` | 520 | 0.790 | 0.0015 | 0.005 | 0.008 | 5.28 |
| `af.learn_helpful_aura_durations_ooc` | 173 | 0.774 | 0.0045 | 0.009 | 0.008 | 1.76 |
| `af.register_managed_frame_background_row` | 10 | 0.363 | 0.0363 | 0.055 | 0.004 | 0.10 |
| `af.resolve_bar_color` | 10 | 0.260 | 0.0260 | 0.044 | 0.003 | 0.10 |
| `af.resolve_text_color` | 10 | 0.190 | 0.0190 | 0.023 | 0.002 | 0.10 |
| `af.refresh_frame_fade_for_combat_state` | 4 | 0.173 | 0.0431 | 0.100 | 0.002 | 0.04 |
| `af.get_color_consumer_group` | 20 | 0.171 | 0.0085 | 0.013 | 0.002 | 0.20 |

Assessment: `af.update_auras` was the dominant inclusive path at `9.245ms/sec`
combat-normalized. CDM map construction was the clearest attributed cost:
`af.add_cooldown_viewer_category_entries` used `4.839ms/sec`, with ordered CDM
record discovery at `1.421ms/sec`. Rendering was secondary at `2.725ms/sec`.
The visible-icon ticker was only `0.614ms/sec`, so cadence comparison is not
warranted from this baseline. Activity-state lookup reached `62.18 calls/sec`
and `1.176ms/sec`; individual managed-backend enable/refresh paths stayed below
`0.15ms/sec`. `scan_custom_aura_map` was inactive because no Custom Filtered
frame existed, while OOC accessible-button setup could not be measured by this
in-combat run. The next matched control should disable Essential and Utility
cooldown modes to isolate the material CDM scan/map contribution before code
changes or event-attribution probes.


### 2026-06-27, Aura Frames Only, Current Combat Check
<!-- cpu-profile-run: elapsed=98.6 combat=97.5 timer_tick=0.15 -->

Context: 98.6s run with only `PROFILE_TARGETS.aura_frames = true`. Combat was
active for 97.5s, 98.9% of elapsed time, one segment. This was a current-state
check before deciding whether to reopen Aura Frames performance work. Timer Tick
was set to `0.15s`; `tick_visible_icons` cadence matches that setting and is the
right comparison point for this run.

| Metric | Calls | Total ms | Avg ms | Max ms | Combat ms/sec | Combat calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1795 | 633.808 | 0.3531 | 3.185 | 6.50 | 18.41 |
| `af.render_aura_map` | 1795 | 293.013 | 0.1632 | 0.987 | 3.01 | 18.41 |
| `af.tick_visible_icons` | 615 | 188.717 | 0.3069 | 0.796 | 1.94 | 6.31 |
| `af.unified_scan` | 174 | 95.024 | 0.5461 | 2.995 | 0.97 | 1.78 |
| `af.add_cooldown_viewer_category_entries` | 1020 | 82.572 | 0.0810 | 0.804 | 0.85 | 10.46 |
| `af.scan_custom_aura_map` | 155 | 62.711 | 0.4046 | 1.142 | 0.64 | 1.59 |
| `af.set_timer_text` | 14114 | 61.799 | 0.0044 | 0.157 | 0.63 | 144.76 |
| `af.get_frame_activity_state` | 7258 | 50.334 | 0.0069 | 0.090 | 0.52 | 74.44 |
| `af.refresh_frame_ooc_fade` | 1795 | 26.644 | 0.0148 | 0.052 | 0.27 | 18.41 |
| `af.is_runtime_enabled` | 2413 | 15.890 | 0.0066 | 0.047 | 0.16 | 24.75 |
| `af.get_setting` | 6715 | 12.181 | 0.0018 | 0.024 | 0.12 | 68.87 |
| `af.get_timer_behavior` | 2105 | 11.611 | 0.0055 | 0.048 | 0.12 | 21.59 |
| `af.get_frame_config_db` | 7258 | 11.328 | 0.0016 | 0.059 | 0.12 | 74.44 |
| `af.mark_aura_scan_dirty` | 1794 | 10.752 | 0.0060 | 0.038 | 0.11 | 18.40 |
| `af.merge_aura_info` | 1782 | 9.171 | 0.0051 | 0.038 | 0.09 | 18.28 |
| `af.normalize_timer_category` | 2105 | 5.700 | 0.0027 | 0.044 | 0.06 | 21.59 |
| `af.update_test_preview_state` | 615 | 3.034 | 0.0049 | 0.023 | 0.03 | 6.31 |
| `af.clear_sorted_aura_ids_cache` | 1968 | 2.662 | 0.0014 | 0.030 | 0.03 | 20.18 |
| `af.append_test_aura` | 155 | 2.633 | 0.0170 | 0.036 | 0.03 | 1.59 |
| `af.get_cdm_viewer_frame` | 1032 | 2.474 | 0.0024 | 0.043 | 0.03 | 10.58 |
| `af.refresh_visible_icon_ticker` | 1795 | 2.145 | 0.0012 | 0.027 | 0.02 | 18.41 |
| `af.clear_custom_aura_scan_cache` | 1794 | 2.087 | 0.0012 | 0.006 | 0.02 | 18.40 |
| `af.prepare_blizz_cdm_viewer` | 1020 | 1.499 | 0.0015 | 0.053 | 0.02 | 10.46 |

Conclusion: Current Aura Frames performance does not show a new obvious cleanup
target. Compared with the prior clean combat-timed runs, `update_auras` and
`render_aura_map` average costs are lower, scan/CDM/custom-scan rows remain the
expected secondary costs, and config/helper rows are small. `tick_visible_icons`
is the largest live ticker row at about 1.94ms/sec combat-normalized, close to
the prior `0.15s` combat run's 2.02ms/sec and 6.54 calls/sec. This appears
cadence-driven rather than a new helper hotspot. Reopen Aura performance work
only with a stronger signal than this run alone.


### Visible Icon Tick Comparison Scratch
Use only combat-timed runs for final interval selection.

| Tick setting | Combat timed? | Combat calls/sec | Combat CPU ms/sec | Elapsed CPU ms/sec | Tick-normalized ms/sec | Notes |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `0.10` | Yes | 9.57 | 2.98 | 2.85 | 2.85 | 72.2s combat out of 75.5s elapsed. |
| `0.15` | Yes | 6.54 | 2.02 | 1.95 | 2.93 | 49.2s combat out of 51.0s elapsed. |
| `0.20` | Yes | 4.98 | 1.50 | 1.45 | 2.91 | 60.1s combat out of 62.0s elapsed. |


### 2026-06-24, Aura Frames Only, Visible Icon Tick 0.20s Combat Test
<!-- cpu-profile-run: elapsed=62.0 combat=60.1 timer_tick=0.20 -->

Context: 62.0s run with only `PROFILE_TARGETS.aura_frames = true`, `Timer Tick
Sec` set to `0.20`, and combat timing enabled. Combat was active for 60.1s
(96.8% of elapsed time), one segment, and the report was captured while still
in combat.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1007 | 374.010 | 0.3714 | 1.666 |
| `af.render_aura_map` | 1007 | 174.627 | 0.1734 | 0.962 |
| `af.tick_visible_icons` | 299 | 90.119 | 0.3014 | 0.697 |
| `af.unified_scan` | 96 | 56.815 | 0.5918 | 1.124 |
| `af.add_cooldown_viewer_category_entries` | 592 | 47.600 | 0.0804 | 0.309 |
| `af.scan_custom_aura_map` | 83 | 37.675 | 0.4539 | 0.829 |
| `af.set_timer_text` | 7577 | 30.225 | 0.0040 | 0.138 |
| `af.get_frame_activity_state` | 4239 | 29.975 | 0.0071 | 0.047 |
| `af.refresh_frame_ooc_fade` | 1007 | 15.950 | 0.0158 | 0.070 |
| `af.is_runtime_enabled` | 1309 | 8.105 | 0.0062 | 0.158 |
| `af.get_setting` | 3779 | 7.244 | 0.0019 | 0.043 |
| `af.mark_aura_scan_dirty` | 1083 | 6.734 | 0.0062 | 0.039 |
| `af.get_frame_config_db` | 4239 | 6.589 | 0.0016 | 0.015 |
| `af.get_timer_behavior` | 1090 | 6.294 | 0.0058 | 0.076 |
| `af.merge_aura_info` | 1071 | 5.368 | 0.0050 | 0.098 |
| `af.normalize_timer_category` | 1090 | 2.922 | 0.0027 | 0.027 |
| `af.clear_sorted_aura_ids_cache` | 1179 | 1.721 | 0.0015 | 0.025 |
| `af.get_cdm_viewer_frame` | 604 | 1.497 | 0.0025 | 0.014 |
| `af.refresh_visible_icon_ticker` | 1007 | 1.464 | 0.0015 | 0.016 |
| `af.clear_custom_aura_scan_cache` | 1083 | 1.307 | 0.0012 | 0.016 |
| `af.prepare_blizz_cdm_viewer` | 592 | 0.881 | 0.0015 | 0.015 |
| `af.get_custom_aura_filter` | 83 | 0.589 | 0.0071 | 0.021 |
| `af.cdm_category_needs_viewer` | 12 | 0.184 | 0.0154 | 0.021 |
| `af.get_custom_modifier_def` | 83 | 0.171 | 0.0021 | 0.005 |
| `af.update_all_blizz_cdm_visibility` | 3 | 0.150 | 0.0501 | 0.057 |

Conclusion: The `0.20` setting produced the expected ticker reduction in a
combat-heavy run. `tick_visible_icons` ran about 4.82 calls/sec elapsed, or
4.98 calls/sec combat-normalized, versus about 9.57 calls/sec in the clean
`0.10` combat baseline. Ticker CPU dropped from about 2.98ms/sec at `0.10` to
about 1.45ms/sec elapsed, or 1.50ms/sec combat-normalized, a roughly 50% ticker
CPU/sec reduction. This is a strong candidate if visual smoothness was acceptable.


### 2026-06-24, Aura Frames Only, Visible Icon Tick 0.15s Combat Test
<!-- cpu-profile-run: elapsed=51.0 combat=49.2 timer_tick=0.15 -->

Context: 51.0s run with only `PROFILE_TARGETS.aura_frames = true`, `Timer Tick
Sec` set to `0.15`, and combat timing enabled. Combat was active for 49.2s
(96.4% of elapsed time), one segment, and the report was captured after combat
ended.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 894 | 341.620 | 0.3821 | 2.124 |
| `af.render_aura_map` | 894 | 156.339 | 0.1749 | 0.815 |
| `af.tick_visible_icons` | 322 | 99.484 | 0.3090 | 0.654 |
| `af.unified_scan` | 83 | 54.699 | 0.6590 | 1.756 |
| `af.add_cooldown_viewer_category_entries` | 529 | 43.252 | 0.0818 | 0.351 |
| `af.scan_custom_aura_map` | 73 | 34.652 | 0.4747 | 1.118 |
| `af.set_timer_text` | 7695 | 31.616 | 0.0041 | 0.138 |
| `af.get_frame_activity_state` | 3544 | 25.627 | 0.0072 | 0.188 |
| `af.refresh_frame_ooc_fade` | 895 | 14.759 | 0.0165 | 0.109 |
| `af.is_runtime_enabled` | 1220 | 7.770 | 0.0064 | 0.165 |
| `af.get_setting` | 3366 | 6.616 | 0.0020 | 0.057 |
| `af.get_frame_config_db` | 3553 | 6.095 | 0.0017 | 0.089 |
| `af.get_timer_behavior` | 967 | 5.600 | 0.0058 | 0.028 |
| `af.mark_aura_scan_dirty` | 903 | 5.479 | 0.0061 | 0.046 |
| `af.merge_aura_info` | 882 | 4.696 | 0.0053 | 0.201 |
| `af.normalize_timer_category` | 967 | 2.633 | 0.0027 | 0.016 |
| `af.get_cdm_viewer_frame` | 560 | 1.406 | 0.0025 | 0.026 |
| `af.refresh_visible_icon_ticker` | 894 | 1.393 | 0.0016 | 0.062 |
| `af.clear_sorted_aura_ids_cache` | 986 | 1.364 | 0.0014 | 0.025 |
| `af.clear_custom_aura_scan_cache` | 903 | 1.177 | 0.0013 | 0.026 |
| `af.prepare_blizz_cdm_viewer` | 529 | 0.897 | 0.0017 | 0.033 |
| `af.get_custom_aura_filter` | 73 | 0.484 | 0.0066 | 0.013 |
| `af.update_blizz_cdm_visibility` | 21 | 0.289 | 0.0138 | 0.034 |
| `af.update_all_blizz_cdm_visibility` | 4 | 0.282 | 0.0704 | 0.092 |
| `af.cdm_category_needs_viewer` | 13 | 0.244 | 0.0188 | 0.031 |

Conclusion: The clean `0.15` combat-timed run reduced ticker CPU/sec versus
the clean `0.10` combat baseline, but not as much as `0.20`. `tick_visible_icons`
ran about 6.31 calls/sec elapsed, or 6.54 calls/sec combat-normalized. Ticker
CPU was about 1.95ms/sec elapsed, or 2.02ms/sec combat-normalized, about 32%
lower than the clean `0.10` combat baseline. Compared with `0.15`, the `0.20`
run was about 24% lower in ticker calls/sec and about 26% lower in ticker CPU/sec.


### 2026-06-24, Aura Frames Only, Visible Icon Tick Provisional Slider Test
<!-- cpu-profile-run: elapsed=67.3 timer_tick=unknown notes=slider_value_not_captured -->

Context: 67.3s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
the temporary main UI slider for `aura_visible_icon_tick` (`0.10` to `0.20`
seconds, `0.01` increments). The slider value was not captured in the pasted
report; expected test value was `0.15`. Combat timing was not available for this
run, so do not use it as the final `0.15` comparison.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1030 | 377.284 | 0.3663 | 3.774 |
| `af.render_aura_map` | 1030 | 174.227 | 0.1692 | 1.053 |
| `af.tick_visible_icons` | 423 | 116.039 | 0.2743 | 0.782 |
| `af.unified_scan` | 91 | 53.085 | 0.5834 | 1.337 |
| `af.add_cooldown_viewer_category_entries` | 620 | 49.863 | 0.0804 | 0.712 |
| `af.scan_custom_aura_map` | 82 | 40.308 | 0.4916 | 3.191 |
| `af.set_timer_text` | 8704 | 34.213 | 0.0039 | 0.046 |
| `af.get_frame_activity_state` | 4068 | 28.635 | 0.0070 | 0.085 |
| `af.refresh_frame_ooc_fade` | 1030 | 16.506 | 0.0160 | 0.214 |
| `af.is_runtime_enabled` | 1456 | 9.277 | 0.0064 | 0.034 |
| `af.get_setting` | 3874 | 7.379 | 0.0019 | 0.030 |
| `af.get_frame_config_db` | 4068 | 6.639 | 0.0016 | 0.048 |
| `af.mark_aura_scan_dirty` | 993 | 6.181 | 0.0062 | 0.026 |
| `af.get_timer_behavior` | 1112 | 6.119 | 0.0055 | 0.026 |
| `af.merge_aura_info` | 972 | 5.238 | 0.0054 | 0.040 |
| `af.normalize_timer_category` | 1112 | 2.920 | 0.0026 | 0.016 |
| `af.refresh_visible_icon_ticker` | 1030 | 1.609 | 0.0016 | 0.093 |
| `af.clear_sorted_aura_ids_cache` | 1084 | 1.539 | 0.0014 | 0.012 |
| `af.get_cdm_viewer_frame` | 680 | 1.457 | 0.0021 | 0.010 |
| `af.prepare_blizz_cdm_viewer` | 620 | 1.444 | 0.0023 | 0.064 |
| `af.clear_custom_aura_scan_cache` | 993 | 1.284 | 0.0013 | 0.016 |
| `af.get_custom_aura_filter` | 82 | 0.577 | 0.0070 | 0.012 |
| `af.update_blizz_cdm_visibility` | 28 | 0.342 | 0.0122 | 0.023 |
| `af.set_height_for_growth` | 6 | 0.308 | 0.0513 | 0.092 |
| `af.get_custom_modifier_def` | 82 | 0.180 | 0.0022 | 0.005 |

Conclusion: Provisional only. Ticker frequency reduction appeared to work:
compared with the prior runtime color-cache run, `tick_visible_icons` dropped
from about 9.36 calls/sec to 6.29 calls/sec, and ticker CPU dropped from about
2.59ms/sec to 1.72ms/sec. Because this run lacked combat timing and did not
capture the exact slider value, replace it with a clean `0.15` combat-timed run
before comparing `0.15` against `0.20`.


### 2026-06-24, Aura Frames Only, Visible Icon Tick 0.10s Combat Baseline
<!-- cpu-profile-run: elapsed=75.5 combat=72.2 timer_tick=0.10 -->

Context: 75.5s run with only `PROFILE_TARGETS.aura_frames = true`, `Timer Tick
Sec` set to `0.10`, and combat timing enabled. Combat was active for 72.2s
(95.7% of elapsed time), one segment, and the report was captured after combat
ended. Earlier partial/aborted runs in the same pasted block were ignored.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1384 | 520.805 | 0.3763 | 4.146 |
| `af.render_aura_map` | 1384 | 236.809 | 0.1711 | 1.396 |
| `af.tick_visible_icons` | 691 | 215.380 | 0.3117 | 0.789 |
| `af.unified_scan` | 140 | 82.442 | 0.5889 | 2.904 |
| `af.set_timer_text` | 15809 | 64.863 | 0.0041 | 0.210 |
| `af.add_cooldown_viewer_category_entries` | 744 | 62.111 | 0.0835 | 0.428 |
| `af.scan_custom_aura_map` | 128 | 60.112 | 0.4696 | 3.030 |
| `af.get_frame_activity_state` | 6079 | 43.141 | 0.0071 | 0.092 |
| `af.refresh_frame_ooc_fade` | 1384 | 22.359 | 0.0162 | 0.173 |
| `af.is_runtime_enabled` | 2078 | 12.816 | 0.0062 | 0.030 |
| `af.mark_aura_scan_dirty` | 1650 | 10.640 | 0.0064 | 0.133 |
| `af.get_setting` | 5152 | 10.128 | 0.0020 | 0.072 |
| `af.get_frame_config_db` | 6079 | 10.064 | 0.0017 | 0.025 |
| `af.merge_aura_info` | 1629 | 8.963 | 0.0055 | 0.048 |
| `af.get_timer_behavior` | 1512 | 8.710 | 0.0058 | 0.031 |
| `af.normalize_timer_category` | 1512 | 4.147 | 0.0027 | 0.023 |
| `af.clear_sorted_aura_ids_cache` | 1790 | 2.696 | 0.0015 | 0.126 |
| `af.clear_custom_aura_scan_cache` | 1650 | 2.254 | 0.0014 | 0.015 |
| `af.refresh_visible_icon_ticker` | 1384 | 2.020 | 0.0015 | 0.015 |
| `af.get_cdm_viewer_frame` | 792 | 2.006 | 0.0025 | 0.019 |
| `af.prepare_blizz_cdm_viewer` | 744 | 1.527 | 0.0021 | 0.040 |
| `af.get_custom_aura_filter` | 128 | 0.888 | 0.0069 | 0.026 |
| `af.update_blizz_cdm_visibility` | 24 | 0.367 | 0.0153 | 0.044 |
| `af.cdm_category_needs_viewer` | 12 | 0.266 | 0.0222 | 0.040 |
| `af.set_height_for_growth` | 5 | 0.265 | 0.0531 | 0.062 |

Conclusion: This is the clean combat-timed baseline for ticker interval
comparison. `tick_visible_icons` ran about 9.15 calls/sec elapsed, or 9.57
calls/sec combat-normalized. Ticker CPU was about 2.85ms/sec elapsed, or
2.98ms/sec combat-normalized.


### 2026-06-23, Aura Frames Only, Runtime Color Cache
<!-- cpu-profile-run: elapsed=107.1 timer_tick=0.10 -->

Context: 107.1s run with only `PROFILE_TARGETS.aura_frames = true`, after extending
the frame-local runtime config cache to store copied scalar color components for
bar color, bar background color, bar text color, and frame background color.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1467 | 573.636 | 0.3910 | 2.016 |
| `af.tick_visible_icons` | 1002 | 277.317 | 0.2768 | 0.742 |
| `af.render_aura_map` | 1467 | 263.963 | 0.1799 | 1.045 |
| `af.unified_scan` | 141 | 88.470 | 0.6274 | 1.368 |
| `af.add_cooldown_viewer_category_entries` | 837 | 74.005 | 0.0884 | 0.530 |
| `af.set_timer_text` | 15780 | 70.652 | 0.0045 | 0.188 |
| `af.scan_custom_aura_map` | 126 | 60.534 | 0.4804 | 1.187 |
| `af.get_frame_activity_state` | 6263 | 47.792 | 0.0076 | 0.113 |
| `af.refresh_frame_ooc_fade` | 1467 | 24.867 | 0.0170 | 0.216 |
| `af.is_runtime_enabled` | 2473 | 16.988 | 0.0069 | 0.186 |
| `af.mark_aura_scan_dirty` | 1686 | 11.996 | 0.0071 | 0.208 |
| `af.get_frame_config_db` | 6263 | 11.341 | 0.0018 | 0.107 |
| `af.get_setting` | 5490 | 11.132 | 0.0020 | 0.032 |
| `af.get_timer_behavior` | 1592 | 9.359 | 0.0059 | 0.128 |
| `af.merge_aura_info` | 1665 | 9.258 | 0.0056 | 0.033 |
| `af.normalize_timer_category` | 1592 | 4.355 | 0.0027 | 0.025 |
| `af.clear_sorted_aura_ids_cache` | 1827 | 2.849 | 0.0016 | 0.081 |
| `af.clear_custom_aura_scan_cache` | 1686 | 2.469 | 0.0015 | 0.025 |
| `af.refresh_visible_icon_ticker` | 1467 | 2.195 | 0.0015 | 0.021 |
| `af.get_cdm_viewer_frame` | 916 | 2.138 | 0.0023 | 0.049 |
| `af.prepare_blizz_cdm_viewer` | 837 | 1.949 | 0.0023 | 0.150 |
| `af.get_custom_aura_filter` | 126 | 0.869 | 0.0069 | 0.016 |
| `af.update_blizz_cdm_visibility` | 37 | 0.508 | 0.0137 | 0.131 |
| `af.get_custom_modifier_def` | 126 | 0.275 | 0.0022 | 0.010 |
| `af.cdm_category_needs_viewer` | 13 | 0.265 | 0.0204 | 0.037 |

Conclusion: Color scalar caching is a measured win. Compared with the prior
runtime-config cache run, `get_setting` dropped from about 90.7 calls/sec to
51.3 calls/sec, and `get_bar_bg_color` no longer appeared in the report.
`update_auras` averaged 0.3910ms versus 0.4533ms in the prior run. Keep this
candidate if a manual settings check confirms visible colors update immediately
after picker changes.


### 2026-06-23, Aura Frames Only, Runtime Config Cache
<!-- cpu-profile-run: elapsed=133.4 timer_tick=0.10 -->

Context: 133.4s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
a frame-local runtime config cache for scalar/layout values and sharing it with
`setup_layout()`. User exercised normal Aura Frames activity rather than idling.
Colors remained uncached.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1562 | 708.094 | 0.4533 | 5.125 |
| `af.tick_visible_icons` | 1249 | 341.296 | 0.2733 | 0.959 |
| `af.render_aura_map` | 1562 | 313.348 | 0.2006 | 5.000 |
| `af.unified_scan` | 146 | 95.705 | 0.6555 | 1.292 |
| `af.add_cooldown_viewer_category_entries` | 882 | 82.724 | 0.0938 | 0.450 |
| `af.set_timer_text` | 16817 | 82.238 | 0.0049 | 0.207 |
| `af.scan_custom_aura_map` | 136 | 76.766 | 0.5645 | 2.511 |
| `af.get_frame_activity_state` | 6318 | 52.561 | 0.0083 | 0.291 |
| `af.refresh_frame_ooc_fade` | 1565 | 28.890 | 0.0185 | 0.107 |
| `af.get_setting` | 12100 | 26.087 | 0.0022 | 0.150 |
| `af.is_runtime_enabled` | 2816 | 21.999 | 0.0078 | 0.183 |
| `af.mark_aura_scan_dirty` | 1587 | 11.821 | 0.0074 | 0.215 |
| `af.get_frame_config_db` | 6324 | 11.596 | 0.0018 | 0.036 |
| `af.get_timer_behavior` | 1697 | 10.995 | 0.0065 | 0.103 |
| `af.get_bar_bg_color` | 1562 | 10.622 | 0.0068 | 0.120 |
| `af.merge_aura_info` | 1566 | 9.303 | 0.0059 | 0.041 |
| `af.normalize_timer_category` | 1697 | 5.357 | 0.0032 | 0.100 |
| `af.prepare_blizz_cdm_viewer` | 882 | 3.698 | 0.0042 | 0.069 |
| `af.clear_sorted_aura_ids_cache` | 1733 | 2.789 | 0.0016 | 0.034 |
| `af.get_cdm_viewer_frame` | 1100 | 2.564 | 0.0023 | 0.026 |
| `af.refresh_visible_icon_ticker` | 1562 | 2.333 | 0.0015 | 0.017 |
| `af.clear_custom_aura_scan_cache` | 1587 | 2.297 | 0.0014 | 0.010 |
| `af.update_blizz_cdm_visibility` | 86 | 1.166 | 0.0136 | 0.035 |
| `af.get_custom_aura_filter` | 136 | 1.042 | 0.0077 | 0.015 |
| `af.set_height_for_growth` | 9 | 0.580 | 0.0644 | 0.078 |

Conclusion: The runtime config cache is a measured win for config-resolution
overhead. Compared with the prior visible-ticker run, `get_setting` dropped from
about 142.8 calls/sec to 90.7 calls/sec, and `is_timer_text_enabled` plus
`uses_cooldown_icon_overlay` no longer appeared in the report. `update_auras`
averaged 0.4533ms, lower than the prior 0.4968ms run and close to the earlier
clean comparison point. Keep the cache, with colors still deferred to the
separate color-cache review.


### 2026-06-23, Aura Frames Only, Visible Ticker Return State
<!-- cpu-profile-run: elapsed=60.3 timer_tick=0.10 -->

Context: 60.3s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
`tick_visible_icons()` to return whether any visible icon still needs ticking so
the ticker callback can avoid a second full `any_frame_needs_visible_icon_tick()`
scan after each tick.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 927 | 460.546 | 0.4968 | 2.913 |
| `af.render_aura_map` | 927 | 185.192 | 0.1998 | 1.213 |
| `af.tick_visible_icons` | 549 | 184.989 | 0.3370 | 0.858 |
| `af.add_cooldown_viewer_category_entries` | 552 | 58.672 | 0.1063 | 0.505 |
| `af.unified_scan` | 82 | 57.880 | 0.7059 | 1.880 |
| `af.set_timer_text` | 10192 | 51.626 | 0.0051 | 0.196 |
| `af.scan_custom_aura_map` | 75 | 44.583 | 0.5944 | 1.878 |
| `af.get_frame_activity_state` | 3736 | 33.486 | 0.0090 | 0.292 |
| `af.get_setting` | 8609 | 20.423 | 0.0024 | 0.706 |
| `af.refresh_frame_ooc_fade` | 928 | 18.188 | 0.0196 | 0.278 |
| `af.is_timer_text_enabled` | 927 | 12.426 | 0.0134 | 0.044 |
| `af.is_runtime_enabled` | 1479 | 12.360 | 0.0084 | 0.108 |
| `af.get_timer_behavior` | 1929 | 11.411 | 0.0059 | 0.046 |
| `af.get_frame_config_db` | 3738 | 7.674 | 0.0021 | 0.032 |
| `af.normalize_timer_category` | 2856 | 7.183 | 0.0025 | 0.038 |
| `af.mark_aura_scan_dirty` | 894 | 7.026 | 0.0079 | 0.082 |
| `af.get_bar_bg_color` | 927 | 6.672 | 0.0072 | 0.036 |
| `af.merge_aura_info` | 882 | 5.430 | 0.0062 | 0.039 |
| `af.uses_cooldown_icon_overlay` | 927 | 2.160 | 0.0023 | 0.104 |
| `af.clear_sorted_aura_ids_cache` | 976 | 1.705 | 0.0017 | 0.031 |
| `af.get_cdm_viewer_frame` | 564 | 1.627 | 0.0029 | 0.035 |
| `af.refresh_visible_icon_ticker` | 927 | 1.516 | 0.0016 | 0.015 |
| `af.clear_custom_aura_scan_cache` | 894 | 1.358 | 0.0015 | 0.014 |
| `af.prepare_blizz_cdm_viewer` | 552 | 1.092 | 0.0020 | 0.022 |
| `af.get_custom_aura_filter` | 75 | 0.596 | 0.0080 | 0.022 |

Conclusion: The intended redundant eligibility scan was removed from the profile:
`any_frame_needs_visible_icon_tick` no longer appears in the report, while
`refresh_visible_icon_ticker` is only 1.516ms over 60.3s. The ticker's own per-call
cost stayed in the same range, as expected, because the live timer/bar update work
is unchanged.


### 2026-06-23, Aura Frames Only, Category-Scoped CDM Hook Refresh
<!-- cpu-profile-run: elapsed=61.1 timer_tick=0.10 -->

Context: 61.1s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
hook-driven CDM refreshes to carry the child viewer category and refresh only that
category when known. Startup, settings, and combat-entry refreshes still use the
broad pass.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 998 | 495.116 | 0.4961 | 4.651 |
| `af.render_aura_map` | 998 | 198.474 | 0.1989 | 1.674 |
| `af.tick_visible_icons` | 555 | 182.413 | 0.3287 | 1.733 |
| `af.unified_scan` | 92 | 65.234 | 0.7091 | 1.226 |
| `af.add_cooldown_viewer_category_entries` | 593 | 59.733 | 0.1007 | 0.474 |
| `af.set_timer_text` | 10226 | 52.584 | 0.0051 | 0.226 |
| `af.scan_custom_aura_map` | 81 | 45.905 | 0.5667 | 1.169 |
| `af.get_frame_activity_state` | 3969 | 35.259 | 0.0089 | 0.210 |
| `af.get_setting` | 9265 | 20.872 | 0.0023 | 0.057 |
| `af.refresh_frame_ooc_fade` | 998 | 19.611 | 0.0196 | 0.201 |
| `af.is_timer_text_enabled` | 998 | 15.944 | 0.0160 | 2.626 |
| `af.is_runtime_enabled` | 1557 | 13.577 | 0.0087 | 1.392 |
| `af.any_frame_needs_visible_icon_tick` | 555 | 13.042 | 0.0235 | 0.211 |
| `af.get_timer_behavior` | 2077 | 12.182 | 0.0059 | 0.104 |
| `af.normalize_timer_category` | 3075 | 10.075 | 0.0033 | 2.593 |
| `af.frame_needs_visible_icon_tick` | 1110 | 9.396 | 0.0085 | 0.188 |
| `af.get_frame_config_db` | 3969 | 8.047 | 0.0020 | 0.100 |
| `af.get_bar_bg_color` | 998 | 7.961 | 0.0080 | 0.281 |
| `af.mark_aura_scan_dirty` | 993 | 7.914 | 0.0080 | 0.306 |
| `af.merge_aura_info` | 972 | 6.287 | 0.0065 | 0.231 |
| `af.prepare_blizz_cdm_viewer` | 593 | 2.521 | 0.0043 | 0.204 |
| `af.uses_cooldown_icon_overlay` | 998 | 2.230 | 0.0022 | 0.020 |
| `af.clear_sorted_aura_ids_cache` | 1085 | 1.817 | 0.0017 | 0.016 |
| `af.get_cdm_viewer_frame` | 744 | 1.767 | 0.0024 | 0.026 |
| `af.clear_custom_aura_scan_cache` | 993 | 1.580 | 0.0016 | 0.012 |

Conclusion: Category-scoped hook refresh is a low-risk routing cleanup with a
small measured support-cost win. Compared with the clean comparison run,
`prepare_blizz_cdm_viewer` dropped from 14.877ms over 88.1s to 2.521ms over
61.1s, and `get_cdm_viewer_frame` dropped from 4.575ms to 1.767ms. The core CDM
map walk did not improve per call: `add_cooldown_viewer_category_entries`
averaged 0.1007ms versus 0.0932ms in the clean comparison. The Aura performance
review owns the CDM map-walk target; the target would need to reduce map-walk
work itself or reduce how often visible CDM frames need a full rebuild.


### 2026-06-23, Aura Frames Only, Clean Comparison
<!-- cpu-profile-run: elapsed=88.1 timer_tick=0.10 -->

Context: 88.1s run with only `PROFILE_TARGETS.aura_frames = true`, after removing
the external addon condition that caused the NumyAddonProfiler `scriptProfile`
warning. No temporary scan/map sub-step labels were active in this run.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1250 | 566.765 | 0.4534 | 2.912 |
| `af.tick_visible_icons` | 821 | 224.691 | 0.2737 | 1.329 |
| `af.render_aura_map` | 1250 | 221.207 | 0.1770 | 1.407 |
| `af.add_cooldown_viewer_category_entries` | 840 | 78.268 | 0.0932 | 0.675 |
| `af.unified_scan` | 104 | 65.535 | 0.6301 | 1.768 |
| `af.set_timer_text` | 9882 | 63.937 | 0.0065 | 1.133 |
| `af.scan_custom_aura_map` | 82 | 35.919 | 0.4380 | 1.103 |
| `af.get_frame_activity_state` | 4169 | 33.741 | 0.0081 | 0.162 |
| `af.refresh_frame_ooc_fade` | 1250 | 26.945 | 0.0216 | 0.238 |
| `af.get_setting` | 11716 | 25.863 | 0.0022 | 0.459 |
| `af.any_frame_needs_visible_icon_tick` | 821 | 19.501 | 0.0238 | 0.284 |
| `af.is_runtime_enabled` | 2129 | 16.836 | 0.0079 | 0.216 |
| `af.is_timer_text_enabled` | 1250 | 16.506 | 0.0132 | 0.692 |
| `af.get_timer_behavior` | 2576 | 14.914 | 0.0058 | 0.679 |
| `af.prepare_blizz_cdm_viewer` | 840 | 14.877 | 0.0177 | 2.187 |
| `af.frame_needs_visible_icon_tick` | 1938 | 13.456 | 0.0069 | 0.148 |
| `af.update_blizz_cdm_visibility` | 608 | 9.887 | 0.0163 | 2.152 |
| `af.normalize_timer_category` | 3826 | 8.948 | 0.0023 | 0.080 |
| `af.get_bar_bg_color` | 1250 | 8.928 | 0.0071 | 0.466 |
| `af.get_frame_config_db` | 4169 | 7.722 | 0.0019 | 0.156 |
| `af.mark_aura_scan_dirty` | 978 | 7.137 | 0.0073 | 0.107 |
| `af.merge_aura_info` | 873 | 5.044 | 0.0058 | 0.024 |
| `af.get_cdm_viewer_frame` | 2200 | 4.575 | 0.0021 | 0.160 |
| `af.cdm_category_needs_viewer` | 232 | 4.373 | 0.0188 | 0.044 |
| `af.update_all_blizz_cdm_visibility` | 58 | 3.784 | 0.0652 | 0.116 |

Conclusion: This is the cleaner post-item-7 comparison point. `render_aura_map`
averaged 0.1770ms, lower than the prior render-cache and display-signature runs,
while `update_auras` averaged 0.4534ms. The direct preset-bucket change still
does not show as an isolated CPU win. CDM/custom scan-map work and
trigger-specific refresh routing are recorded as Aura performance targets in
`internal_dev/working_docs/proj_mem/modules/aura_frames.md`.


### 2026-06-23, Aura Frames Only, Scan/Map Sub-Steps
<!-- cpu-profile-run: elapsed=64.9 timer_tick=0.10 -->

Context: 64.9s run with only `PROFILE_TARGETS.aura_frames = true`, plus temporary
sub-step labels around Aura Frames scan/map fill branches. No test auras were
enabled. NumyAddonProfiler again reported `scriptProfile` enabled.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1117 | 512.267 | 0.4586 | 6.247 |
| `af.render_aura_map` | 1117 | 208.738 | 0.1869 | 1.098 |
| `af.tick_visible_icons` | 607 | 189.438 | 0.3121 | 0.810 |
| `af.update_auras.scan_shared` | 106 | 66.846 | 0.6306 | 5.180 |
| `af.unified_scan` | 106 | 66.280 | 0.6253 | 5.169 |
| `af.update_auras.map_cdm` | 632 | 61.866 | 0.0979 | 0.615 |
| `af.add_cooldown_viewer_category_entries` | 632 | 59.387 | 0.0940 | 0.606 |
| `af.set_timer_text` | 11599 | 55.397 | 0.0048 | 0.198 |
| `af.update_auras.map_custom` | 97 | 49.982 | 0.5153 | 1.366 |
| `af.scan_custom_aura_map` | 97 | 49.357 | 0.5088 | 1.354 |
| `af.get_frame_activity_state` | 4648 | 39.909 | 0.0086 | 1.231 |
| `af.get_setting` | 10333 | 21.758 | 0.0021 | 0.082 |
| `af.refresh_frame_ooc_fade` | 1117 | 19.512 | 0.0175 | 0.206 |
| `af.any_frame_needs_visible_icon_tick` | 607 | 14.530 | 0.0239 | 0.107 |
| `af.is_timer_text_enabled` | 1117 | 13.790 | 0.0123 | 0.067 |
| `af.is_runtime_enabled` | 1727 | 13.302 | 0.0077 | 0.104 |
| `af.get_timer_behavior` | 2331 | 12.801 | 0.0055 | 0.062 |
| `af.frame_needs_visible_icon_tick` | 1296 | 10.430 | 0.0080 | 0.076 |
| `af.get_frame_config_db` | 4648 | 8.721 | 0.0019 | 0.034 |
| `af.mark_aura_scan_dirty` | 1146 | 8.156 | 0.0071 | 0.106 |
| `af.normalize_timer_category` | 3448 | 7.894 | 0.0023 | 0.035 |
| `af.get_bar_bg_color` | 1117 | 7.525 | 0.0067 | 0.076 |
| `af.merge_aura_info` | 1134 | 7.201 | 0.0064 | 0.442 |

Conclusion: The direct preset-bucket path is not the meaningful scan/map cost:
`map_preset_bucket`, `map_preset_copy`, `preview_copy`, and `preview_append` were
below the report cutoff. Scan/map cost is dominated by `unified_scan`,
`add_cooldown_viewer_category_entries`, and `scan_custom_aura_map`. Keep the
direct-bucket cleanup because it is safe and removes avoidable work. Durable Aura
performance conclusions live in `internal_dev/working_docs/proj_mem/modules/aura_frames.md`.


### 2026-06-23, Aura Frames Only, Preset Bucket Direct Render
<!-- cpu-profile-run: elapsed=84.7 timer_tick=0.10 -->

Context: 84.7s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
preset static/short/long/debuff frames to render directly from scan-built category
buckets when no test-preview mutation is needed. NumyAddonProfiler again reported
`scriptProfile` enabled.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1523 | 728.070 | 0.4781 | 3.433 |
| `af.render_aura_map` | 1523 | 310.403 | 0.2038 | 1.765 |
| `af.tick_visible_icons` | 787 | 280.501 | 0.3564 | 0.985 |
| `af.unified_scan` | 155 | 98.559 | 0.6359 | 1.730 |
| `af.set_timer_text` | 18443 | 87.511 | 0.0047 | 0.494 |
| `af.add_cooldown_viewer_category_entries` | 828 | 74.643 | 0.0901 | 0.752 |
| `af.scan_custom_aura_map` | 139 | 74.114 | 0.5332 | 2.634 |
| `af.get_frame_activity_state` | 6427 | 52.192 | 0.0081 | 0.444 |
| `af.get_setting` | 14050 | 29.516 | 0.0021 | 0.084 |
| `af.refresh_frame_ooc_fade` | 1523 | 26.176 | 0.0172 | 0.113 |
| `af.is_timer_text_enabled` | 1523 | 19.549 | 0.0128 | 0.406 |
| `af.any_frame_needs_visible_icon_tick` | 787 | 18.241 | 0.0232 | 0.246 |
| `af.get_timer_behavior` | 3185 | 17.882 | 0.0056 | 0.187 |
| `af.is_runtime_enabled` | 2313 | 17.208 | 0.0074 | 0.101 |
| `af.frame_needs_visible_icon_tick` | 1638 | 12.737 | 0.0078 | 0.226 |
| `af.get_frame_config_db` | 6427 | 11.632 | 0.0018 | 0.046 |
| `af.normalize_timer_category` | 4708 | 11.434 | 0.0024 | 0.391 |
| `af.mark_aura_scan_dirty` | 1659 | 11.392 | 0.0069 | 0.062 |
| `af.get_bar_bg_color` | 1523 | 10.284 | 0.0068 | 0.049 |
| `af.merge_aura_info` | 1647 | 9.799 | 0.0059 | 0.292 |
| `af.uses_cooldown_icon_overlay` | 1523 | 3.083 | 0.0020 | 0.035 |
| `af.refresh_visible_icon_ticker` | 1523 | 2.712 | 0.0018 | 0.202 |
| `af.clear_sorted_aura_ids_cache` | 1814 | 2.690 | 0.0015 | 0.014 |
| `af.clear_custom_aura_scan_cache` | 1659 | 2.320 | 0.0014 | 0.011 |
| `af.get_cdm_viewer_frame` | 864 | 2.154 | 0.0025 | 0.031 |

Conclusion: This broad Aura-only profile did not show a clear improvement from
direct bucket rendering. `update_auras` and `render_aura_map` averages were higher
than the previous display-signature run, but activity pressure and `scriptProfile`
make the comparison noisy. The likely issue is that this profile does not isolate
the scan/map-fill sub-step, and preset test-preview paths may prevent the direct
bucket fast path for frames with previews enabled. Revisit item 7 with targeted
sub-step labels or a narrower profile before marking it complete.


### 2026-06-23, Aura Frames Only, Render Display Signature
<!-- cpu-profile-run: elapsed=117.3 timer_tick=0.10 -->

Context: 117.3s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
a conservative display-signature skip to `render_aura_map()`. NumyAddonProfiler
reported `scriptProfile` enabled, so use this run for relative shape more than
absolute timing.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 2215 | 1011.583 | 0.4567 | 3.454 |
| `af.render_aura_map` | 2215 | 419.992 | 0.1896 | 2.023 |
| `af.tick_visible_icons` | 1095 | 372.792 | 0.3404 | 1.253 |
| `af.unified_scan` | 214 | 135.244 | 0.6320 | 1.606 |
| `af.set_timer_text` | 24921 | 116.204 | 0.0047 | 0.267 |
| `af.add_cooldown_viewer_category_entries` | 1240 | 111.338 | 0.0898 | 0.610 |
| `af.scan_custom_aura_map` | 195 | 103.253 | 0.5295 | 2.809 |
| `af.get_frame_activity_state` | 9134 | 73.025 | 0.0080 | 0.229 |
| `af.get_setting` | 20475 | 42.821 | 0.0021 | 0.217 |
| `af.refresh_frame_ooc_fade` | 2215 | 37.564 | 0.0170 | 0.242 |
| `af.is_timer_text_enabled` | 2215 | 26.305 | 0.0119 | 0.156 |
| `af.any_frame_needs_visible_icon_tick` | 1095 | 24.128 | 0.0220 | 0.253 |
| `af.get_timer_behavior` | 4625 | 23.978 | 0.0052 | 0.149 |
| `af.is_runtime_enabled` | 3313 | 23.746 | 0.0072 | 0.443 |
| `af.frame_needs_visible_icon_tick` | 2226 | 17.034 | 0.0077 | 0.233 |
| `af.get_frame_config_db` | 9134 | 16.631 | 0.0018 | 0.074 |
| `af.mark_aura_scan_dirty` | 2334 | 16.514 | 0.0071 | 0.173 |
| `af.normalize_timer_category` | 6840 | 15.096 | 0.0022 | 0.068 |
| `af.get_bar_bg_color` | 2215 | 14.977 | 0.0068 | 0.057 |
| `af.merge_aura_info` | 2322 | 14.254 | 0.0061 | 0.185 |
| `af.uses_cooldown_icon_overlay` | 2215 | 4.695 | 0.0021 | 0.118 |
| `af.clear_sorted_aura_ids_cache` | 2548 | 4.104 | 0.0016 | 0.080 |
| `af.clear_custom_aura_scan_cache` | 2334 | 3.396 | 0.0015 | 0.030 |
| `af.refresh_visible_icon_ticker` | 2215 | 3.277 | 0.0015 | 0.074 |
| `af.get_cdm_viewer_frame` | 1252 | 2.935 | 0.0023 | 0.029 |

Conclusion: The conservative display-signature skip did not produce a large
step change. `render_aura_map` average improved modestly versus the previous
render-cache run, from 0.1952ms to 0.1896ms, but the run also had external
script profiling enabled and different activity pressure. Treat item 6 as a
small measured win unless later in-game behavior shows stale icon visuals. The
next higher-value target remains scan/map fill.


### 2026-06-22, Aura Frames Only, Render Timer Behavior Cache
<!-- cpu-profile-run: elapsed=78.7 timer_tick=0.10 -->

Context: 78.7s run with only `PROFILE_TARGETS.aura_frames = true`, after changing
`render_aura_map()` to reuse one timer behavior for preset frames and cache timer
behaviors by category for custom frames during each render pass.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1457 | 712.382 | 0.4889 | 2.505 |
| `af.render_aura_map` | 1457 | 284.441 | 0.1952 | 1.125 |
| `af.tick_visible_icons` | 728 | 252.601 | 0.3470 | 0.920 |
| `af.unified_scan` | 141 | 102.302 | 0.7255 | 1.641 |
| `af.set_timer_text` | 15294 | 78.261 | 0.0051 | 0.180 |
| `af.add_cooldown_viewer_category_entries` | 812 | 77.623 | 0.0956 | 0.516 |
| `af.scan_custom_aura_map` | 129 | 74.680 | 0.5789 | 1.438 |
| `af.get_frame_activity_state` | 5865 | 51.673 | 0.0088 | 0.180 |
| `af.get_setting` | 13464 | 30.194 | 0.0022 | 0.084 |
| `af.refresh_frame_ooc_fade` | 1457 | 26.691 | 0.0183 | 0.151 |
| `af.is_timer_text_enabled` | 1457 | 19.566 | 0.0134 | 0.687 |
| `af.any_frame_needs_visible_icon_tick` | 728 | 17.470 | 0.0240 | 0.095 |
| `af.is_runtime_enabled` | 2190 | 17.144 | 0.0078 | 0.052 |
| `af.get_timer_behavior` | 3042 | 16.480 | 0.0054 | 0.069 |
| `af.mark_aura_scan_dirty` | 1551 | 12.537 | 0.0081 | 0.221 |
| `af.frame_needs_visible_icon_tick` | 1502 | 12.475 | 0.0083 | 0.052 |
| `af.get_frame_config_db` | 5865 | 12.020 | 0.0020 | 0.168 |
| `af.normalize_timer_category` | 4499 | 11.610 | 0.0026 | 0.606 |
| `af.get_bar_bg_color` | 1457 | 10.810 | 0.0074 | 0.053 |
| `af.merge_aura_info` | 1530 | 10.182 | 0.0067 | 0.141 |
| `af.uses_cooldown_icon_overlay` | 1457 | 3.083 | 0.0021 | 0.024 |
| `af.clear_sorted_aura_ids_cache` | 1692 | 3.012 | 0.0018 | 0.120 |
| `af.prepare_blizz_cdm_viewer` | 812 | 2.958 | 0.0036 | 0.222 |
| `af.clear_custom_aura_scan_cache` | 1551 | 2.448 | 0.0016 | 0.085 |
| `af.get_cdm_viewer_frame` | 928 | 2.413 | 0.0026 | 0.091 |

Conclusion: The targeted helper change worked: compared with the update sub-step
run, `get_timer_behavior` fell from 6014 calls / 30.396ms to 3042 calls /
16.480ms despite similar render/update volume. `render_aura_map` average also
fell from 0.2049ms to 0.1952ms in this run. The main render path remains a large
cost. The broader render-signature and redundant-work review is tracked through
`internal_dev/working_docs/proj_mem/modules/aura_frames.md` if
Aura performance work resumes.


### 2026-06-22, Aura Frames Only, Update Sub-Steps
<!-- cpu-profile-run: elapsed=77.2 timer_tick=0.10 -->

Context: 77.2s run with only `PROFILE_TARGETS.aura_frames = true`, plus temporary
sub-step labels inside `M.update_auras()` to split inclusive update cost. Profiler
wrapped Aura Frames addon-owned functions only. Sub-step labels were removed after
the run.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1498 | 748.218 | 0.4995 | 3.484 |
| `af.update_auras.render` | 1498 | 311.485 | 0.2079 | 1.355 |
| `af.render_aura_map` | 1498 | 306.921 | 0.2049 | 1.350 |
| `af.update_auras.scan_map` | 1498 | 259.106 | 0.1730 | 2.844 |
| `af.tick_visible_icons` | 709 | 254.530 | 0.3590 | 1.710 |
| `af.unified_scan` | 149 | 101.481 | 0.6811 | 1.948 |
| `af.set_timer_text` | 17000 | 81.092 | 0.0048 | 1.251 |
| `af.add_cooldown_viewer_category_entries` | 828 | 76.121 | 0.0919 | 0.481 |
| `af.scan_custom_aura_map` | 134 | 74.637 | 0.5570 | 2.834 |
| `af.update_auras.config` | 1498 | 72.361 | 0.0483 | 0.184 |
| `af.get_frame_activity_state` | 6229 | 49.904 | 0.0080 | 0.068 |
| `af.get_timer_behavior` | 6014 | 30.396 | 0.0051 | 0.216 |
| `af.get_setting` | 13835 | 29.154 | 0.0021 | 0.338 |
| `af.update_auras.ooc_fade` | 1498 | 28.310 | 0.0189 | 0.354 |
| `af.refresh_frame_ooc_fade` | 1498 | 25.031 | 0.0167 | 0.353 |
| `af.is_timer_text_enabled` | 1498 | 17.772 | 0.0119 | 0.071 |
| `af.update_auras.activity` | 1498 | 16.649 | 0.0111 | 0.069 |
| `af.any_frame_needs_visible_icon_tick` | 709 | 16.427 | 0.0232 | 0.278 |
| `af.is_runtime_enabled` | 2210 | 16.284 | 0.0074 | 0.036 |
| `af.normalize_timer_category` | 7512 | 16.178 | 0.0022 | 0.056 |
| `af.update_auras.layout_shell` | 1498 | 12.198 | 0.0081 | 0.149 |
| `af.get_frame_config_db` | 6229 | 11.829 | 0.0019 | 0.055 |
| `af.frame_needs_visible_icon_tick` | 1464 | 11.642 | 0.0080 | 0.120 |
| `af.mark_aura_scan_dirty` | 1614 | 11.610 | 0.0072 | 0.260 |
| `af.get_bar_bg_color` | 1498 | 10.129 | 0.0068 | 0.041 |

Conclusion: The split shows the next best Aura Frames CPU target is not generic
settings resolution. Render dominates the inclusive update path, followed by
scan/map fill. `update_auras.config` is visible but much smaller, about 0.94ms/s
versus about 4.03ms/s for render and 3.36ms/s for scan/map fill in this run.
Next implementation pass should focus on render skipping/redundant render work
and scan-map narrowing before adding a broader runtime config cache.


### 2026-06-22, Aura Frames Only, Post-OOC Fast Path
<!-- cpu-profile-run: elapsed=90.1 timer_tick=0.10 -->

Context: 90.1s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
the low-risk OOC fade early return for disabled/no-active-fade frames. Profiler
wrapped Aura Frames addon-owned functions only.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1309 | 590.951 | 0.4515 | 2.645 |
| `af.render_aura_map` | 1309 | 231.311 | 0.1767 | 1.463 |
| `af.tick_visible_icons` | 833 | 216.191 | 0.2595 | 1.181 |
| `af.add_cooldown_viewer_category_entries` | 824 | 79.223 | 0.0961 | 0.528 |
| `af.unified_scan` | 111 | 66.405 | 0.5982 | 1.508 |
| `af.set_timer_text` | 10583 | 62.127 | 0.0059 | 0.939 |
| `af.scan_custom_aura_map` | 97 | 48.777 | 0.5029 | 1.460 |
| `af.get_frame_activity_state` | 4858 | 38.211 | 0.0079 | 0.077 |
| `af.get_setting` | 12218 | 27.166 | 0.0022 | 0.237 |
| `af.refresh_frame_ooc_fade` | 1311 | 26.106 | 0.0199 | 0.090 |
| `af.get_timer_behavior` | 4414 | 22.734 | 0.0052 | 0.229 |
| `af.any_frame_needs_visible_icon_tick` | 833 | 17.850 | 0.0214 | 0.141 |
| `af.is_runtime_enabled` | 2170 | 16.669 | 0.0077 | 0.193 |
| `af.is_timer_text_enabled` | 1309 | 16.506 | 0.0126 | 0.105 |
| `af.normalize_timer_category` | 5723 | 12.734 | 0.0022 | 0.055 |
| `af.frame_needs_visible_icon_tick` | 1784 | 12.164 | 0.0068 | 0.042 |
| `af.prepare_blizz_cdm_viewer` | 824 | 10.595 | 0.0129 | 0.201 |
| `af.get_bar_bg_color` | 1309 | 9.005 | 0.0069 | 0.033 |
| `af.get_frame_config_db` | 4865 | 8.770 | 0.0018 | 0.071 |
| `af.mark_aura_scan_dirty` | 1146 | 7.854 | 0.0069 | 0.274 |
| `af.merge_aura_info` | 1062 | 6.217 | 0.0059 | 0.113 |
| `af.update_blizz_cdm_visibility` | 396 | 5.050 | 0.0128 | 0.048 |
| `af.get_cdm_viewer_frame` | 1788 | 3.809 | 0.0021 | 0.037 |
| `af.uses_cooldown_icon_overlay` | 1309 | 2.626 | 0.0020 | 0.028 |
| `af.cdm_category_needs_viewer` | 112 | 2.271 | 0.0203 | 0.056 |

Conclusion: Compared with the prior 90.6s Aura-only baseline, total ms/sec fell
mostly because `update_auras` and render calls/sec were lower in this run
(`update_auras` about 7.45ms/s -> 6.56ms/s). Per-call costs stayed broadly
stable: `update_auras` 0.4471ms -> 0.4515ms and `render_aura_map` 0.1778ms ->
0.1767ms. `tick_visible_icons` improved on both total rate and average cost
(`0.2961ms` -> `0.2595ms`), but workload differences still make attribution
uncertain. Use this as the current comparison baseline before adding temporary
`update_auras` sub-step profiler labels.


### 2026-06-22, Aura Frames Only
<!-- cpu-profile-run: elapsed=90.6 timer_tick=0.10 -->

Context: 90.6s run with only `PROFILE_TARGETS.aura_frames = true`.
Profiler wrapped Aura Frames addon-owned functions only.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `af.update_auras` | 1509 | 674.741 | 0.4471 | 3.580 |
| `af.render_aura_map` | 1509 | 268.251 | 0.1778 | 1.287 |
| `af.tick_visible_icons` | 836 | 247.537 | 0.2961 | 1.273 |
| `af.unified_scan` | 138 | 85.381 | 0.6187 | 2.910 |
| `af.add_cooldown_viewer_category_entries` | 944 | 85.081 | 0.0901 | 0.517 |
| `af.set_timer_text` | 13780 | 80.167 | 0.0058 | 0.616 |
| `af.scan_custom_aura_map` | 113 | 56.953 | 0.5040 | 1.256 |
| `af.get_frame_activity_state` | 5422 | 43.579 | 0.0080 | 0.129 |
| `af.refresh_frame_ooc_fade` | 1509 | 30.160 | 0.0200 | 0.256 |
| `af.get_setting` | 14402 | 29.670 | 0.0021 | 0.210 |
| `af.get_timer_behavior` | 5328 | 26.794 | 0.0050 | 0.066 |
| `af.any_frame_needs_visible_icon_tick` | 836 | 17.870 | 0.0214 | 0.274 |
| `af.is_timer_text_enabled` | 1509 | 17.843 | 0.0118 | 0.072 |
| `af.is_runtime_enabled` | 2389 | 17.245 | 0.0072 | 0.109 |
| `af.normalize_timer_category` | 6837 | 14.939 | 0.0022 | 0.063 |
| `af.frame_needs_visible_icon_tick` | 1697 | 12.824 | 0.0076 | 0.262 |
| `af.get_bar_bg_color` | 1509 | 9.990 | 0.0066 | 0.071 |
| `af.get_frame_config_db` | 5422 | 9.966 | 0.0018 | 0.124 |
| `af.prepare_blizz_cdm_viewer` | 944 | 9.851 | 0.0104 | 0.339 |
| `af.mark_aura_scan_dirty` | 1323 | 9.554 | 0.0072 | 0.126 |
| `af.merge_aura_info` | 1197 | 6.928 | 0.0058 | 0.041 |
| `af.update_blizz_cdm_visibility` | 456 | 5.516 | 0.0121 | 0.039 |
| `af.get_cdm_viewer_frame` | 1960 | 4.383 | 0.0022 | 0.313 |
| `af.cdm_category_needs_viewer` | 176 | 3.310 | 0.0188 | 0.060 |
| `af.uses_cooldown_icon_overlay` | 1509 | 2.903 | 0.0019 | 0.028 |

Conclusion: Aura-only profiling confirms the broad-run hot path. `update_auras`
is still the main inclusive path, followed by rendering and visible-icon ticking.
`unified_scan`, CDM entry reads, timer text, and custom aura scans are secondary
contributors. Per-call costs are stable versus the broad run. Durable Aura
performance conclusions live in `internal_dev/working_docs/proj_mem/modules/aura_frames.md`.


## Aura Frames Duration Probe
Long-term capture for Aura Frames in-game profiling runs. Use
`../aura_frames_duration_profile.lua` when collecting comparable
data.


## Current Decision
`C_UnitAuras.GetAuraDuration` is not a meaningful hotspot based on the collected
2026-06-06 data. Keep the defensive `GetAuraDuration` guards in
`af_logic_ticker.lua`, `af_render.lua`, and `af_scan.lua`; restructure duration
handling for CPU reasons only if future profiling shows a material regression.

The safe ticker improvement remains: visible-icon updates reuse live
DurationObjects resolved during render before falling back to another
`GetAuraDuration` lookup.


## How To Collect
1. Temporarily load `internal_dev/tests_tools/aura_frames_duration_profile.lua` after
   `modules/aura_frames/af_main.lua` in `LsTweeks.toc`.
2. `/reload`.
3. Run `/lstafprofile start`.
4. Exercise normal aura/CDM gameplay for 1-3 minutes.
5. Run `/lstafprofile report`, copy the output here, then run `/lstafprofile stop`.
6. Remove the temporary TOC line and `/reload`.


## Runs
### 2026-06-06
Context: 77.6s normal Aura Frames and CDM use.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `C_UnitAuras.GetAuraDuration` | 2673 | 10.330 | 0.0039 | 0.142 |
| `C_UnitAuras.GetUnitAuraInstanceIDs` | 311 | 6.750 | 0.0217 | 0.145 |
| `tick_visible_icons` | 722 | 116.671 | 0.1616 | 0.519 |
| `render_aura_map` | 1325 | 167.696 | 0.1266 | 0.768 |
| `unified_scan` | 109 | 72.540 | 0.6655 | 1.857 |
| `scan_custom_aura_map` | 101 | 6.667 | 0.0660 | 0.215 |
| `add_cooldown_viewer_category_entries` | 820 | 50.482 | 0.0616 | 0.387 |

Conclusion: `C_UnitAuras.GetAuraDuration` was not a meaningful hotspot in this
run. Keep the defensive guards and do not restructure duration handling for CPU
reasons based on this data.
