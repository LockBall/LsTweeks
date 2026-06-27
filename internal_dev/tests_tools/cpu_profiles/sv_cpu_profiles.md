# Skyriding Vigor CPU Profiles

Long-term capture for Skyriding Vigor focused in-game profiling runs.


## Table of Contents
- [How To Collect](#how-to-collect)
- [Runs](#runs)


## How To Collect

1. Use `internal_dev/tests_tools/addon_cpu_profile.lua` with only `PROFILE_TARGETS.skyriding_vigor = true`.

2. Keep `LsTweeks.toc` temporarily loading `internal_dev\tests_tools\addon_cpu_profile.lua` after normal addon files.

3. `/reload`, then run `/lstprofile reset` and `/lstprofile start`.

4. Exercise Fill Test or real Skyriding for a comparable duration.

5. Run `/lstprofile report 40`, copy the output here, then run `/lstprofile stop`.

6. Compare focused runs with `skyriding_active`, `sv_msps`, and `sv_callsps`.

## Runs

### 2026-06-26, Skyriding Vigor Only, Fill Test Baseline

Context: 129.7s focused Skyriding Vigor run with only
`PROFILE_TARGETS.skyriding_vigor = true`. Combat was 0.0s. `skyriding_active`
was 129.7s, 100.0% of elapsed time, one segment, active at report capture. Run
used Fill Test to keep progress/spark updates active.

| Metric | Calls | Total ms | Avg ms | Max ms | SV ms/sec | SV calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `sv.update_filling_slot_progress` | 2316 | 363.644 | 0.1570 | 1.782 | 2.804 | 17.86 |
| `sv.refresh` | 298 | 333.786 | 1.1201 | 3.702 | 2.574 | 2.30 |
| `sv.get_bar_style` | 6553 | 307.898 | 0.0470 | 1.255 | 2.374 | 50.54 |
| `sv.set_slot_state` | 1790 | 278.693 | 0.1557 | 1.703 | 2.149 | 13.80 |
| `sv.get_frame_atlas` | 1790 | 112.043 | 0.0626 | 1.627 | 0.864 | 13.80 |
| `sv.get_style_layout_table` | 1790 | 90.150 | 0.0504 | 1.615 | 0.695 | 13.80 |
| `sv.get_valid_bar_style_key` | 1790 | 68.512 | 0.0383 | 1.598 | 0.528 | 13.80 |
| `sv.get_spark_atlas` | 5709 | 60.328 | 0.0106 | 1.194 | 0.465 | 44.03 |
| `sv.get_db` | 10484 | 36.472 | 0.0035 | 0.070 | 0.281 | 80.85 |
| `sv.get_spark_color` | 2417 | 8.095 | 0.0033 | 1.414 | 0.062 | 18.64 |
| `sv.get_charge_info` | 298 | 8.084 | 0.0271 | 0.066 | 0.062 | 2.30 |
| `sv.get_gliding_state` | 1004 | 4.466 | 0.0044 | 0.016 | 0.034 | 7.74 |
| `sv.set_slot_visible` | 1788 | 4.028 | 0.0023 | 0.027 | 0.031 | 13.79 |
| `sv.is_mounted_in_advanced_flyable_area` | 53 | 3.688 | 0.0696 | 0.175 | 0.028 | 0.41 |
| `sv.apply_full_charge_fade` | 298 | 3.114 | 0.0104 | 0.041 | 0.024 | 2.30 |
| `sv.is_runtime_enabled` | 298 | 2.320 | 0.0078 | 0.018 | 0.018 | 2.30 |
| `sv.restore_frame_alpha` | 295 | 2.157 | 0.0073 | 0.015 | 0.017 | 2.27 |
| `sv.set_move_mode` | 298 | 1.271 | 0.0043 | 0.058 | 0.010 | 2.30 |
| `sv.ensure_frame` | 596 | 0.949 | 0.0016 | 0.014 | 0.007 | 4.60 |
| `sv.is_player_ridealong_passenger` | 298 | 0.847 | 0.0028 | 0.014 | 0.007 | 2.30 |
| `sv.apply_layout` | 298 | 0.763 | 0.0026 | 0.084 | 0.006 | 2.30 |
| `sv.cancel_frame_fade` | 298 | 0.471 | 0.0016 | 0.003 | 0.004 | 2.30 |
| `sv.set_frame_alpha` | 295 | 0.439 | 0.0015 | 0.009 | 0.003 | 2.27 |
| `sv.is_player_flying` | 66 | 0.155 | 0.0024 | 0.007 | 0.001 | 0.51 |
| `sv.fade_frame_alpha` | 3 | 0.038 | 0.0126 | 0.016 | 0.000 | 0.02 |
| `sv.get_spark_size` | 6 | 0.033 | 0.0054 | 0.009 | 0.000 | 0.05 |

Conclusion: Do not sum nested rows as exclusive cost. The baseline still shows a
clear repeated-style-lookup shape: `sv.get_bar_style` ran about 50.54 calls/sec
and 2.374ms/sec during active Fill Test. `sv.get_frame_atlas`,
`sv.get_style_layout_table`, and `sv.get_valid_bar_style_key` also appear as
nested style-resolution work. This supports a consolidation pass that resolves
style/style-derived values once per refresh/progress update path where practical,
without broad persistent cache state.

### 2026-06-26, Skyriding Vigor Only, After Render Context

Context: 140.8s focused Skyriding Vigor run after adding pass-local render
context. Combat was 0.0s. `skyriding_active` was 137.6s, 97.7% of elapsed time,
one segment, active at report capture. Run used Fill Test to keep progress/spark
updates active.

| Metric | Calls | Total ms | Avg ms | Max ms | SV ms/sec | SV calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `sv.update_filling_slot_progress` | 2394 | 593.390 | 0.2479 | 2.881 | 4.311 | 17.39 |
| `sv.get_render_context` | 2533 | 562.585 | 0.2221 | 2.831 | 4.088 | 18.40 |
| `sv.get_frame_atlas` | 2533 | 241.338 | 0.0953 | 2.597 | 1.754 | 18.40 |
| `sv.get_bar_style` | 2533 | 213.768 | 0.0844 | 1.990 | 1.553 | 18.40 |
| `sv.get_style_layout_table` | 2533 | 196.899 | 0.0777 | 2.512 | 1.431 | 18.40 |
| `sv.refresh` | 344 | 159.001 | 0.4622 | 0.926 | 1.155 | 2.50 |
| `sv.get_valid_bar_style_key` | 2533 | 143.393 | 0.0566 | 2.414 | 1.042 | 18.40 |
| `sv.get_spark_atlas` | 2533 | 38.819 | 0.0153 | 0.186 | 0.282 | 18.40 |
| `sv.get_db` | 2200 | 19.302 | 0.0088 | 0.048 | 0.140 | 15.98 |
| `sv.set_slot_state` | 2001 | 17.316 | 0.0087 | 0.185 | 0.126 | 14.54 |
| `sv.get_charge_info` | 344 | 12.899 | 0.0375 | 0.233 | 0.094 | 2.50 |
| `sv.get_spark_color` | 2515 | 6.963 | 0.0028 | 0.025 | 0.051 | 18.27 |
| `sv.get_gliding_state` | 1096 | 6.475 | 0.0059 | 0.111 | 0.047 | 7.96 |
| `sv.set_slot_visible` | 1998 | 5.199 | 0.0026 | 0.070 | 0.038 | 14.52 |
| `sv.is_mounted_in_advanced_flyable_area` | 55 | 5.025 | 0.0914 | 0.261 | 0.037 | 0.40 |
| `sv.apply_full_charge_fade` | 333 | 4.830 | 0.0145 | 0.039 | 0.035 | 2.42 |
| `sv.is_runtime_enabled` | 344 | 3.629 | 0.0105 | 0.031 | 0.026 | 2.50 |
| `sv.restore_frame_alpha` | 340 | 3.530 | 0.0104 | 0.036 | 0.026 | 2.47 |
| `sv.set_move_mode` | 344 | 1.801 | 0.0052 | 0.032 | 0.013 | 2.50 |
| `sv.ensure_frame` | 688 | 1.590 | 0.0023 | 0.027 | 0.012 | 5.00 |
| `sv.is_player_ridealong_passenger` | 344 | 1.451 | 0.0042 | 0.157 | 0.011 | 2.50 |
| `sv.apply_layout` | 344 | 0.993 | 0.0029 | 0.033 | 0.007 | 2.50 |
| `sv.set_frame_alpha` | 340 | 0.679 | 0.0020 | 0.021 | 0.005 | 2.47 |
| `sv.cancel_frame_fade` | 341 | 0.641 | 0.0019 | 0.013 | 0.005 | 2.48 |
| `sv.is_player_flying` | 73 | 0.214 | 0.0029 | 0.006 | 0.002 | 0.53 |
| `sv.fade_frame_alpha` | 4 | 0.053 | 0.0133 | 0.017 | 0.000 | 0.03 |
| `sv.get_spark_size` | 6 | 0.050 | 0.0083 | 0.015 | 0.000 | 0.04 |

Comparison: `sv.set_slot_state` improved sharply, from 2.149ms/sec active to
0.126ms/sec active. `sv.refresh` improved from 2.574ms/sec to 1.155ms/sec.
`sv.get_bar_style` calls dropped from 50.54/sec to 18.40/sec and CPU dropped from
2.374ms/sec to 1.553ms/sec. However, `sv.get_render_context` is now the dominant
inclusive row because it resolves style, frame atlas, and spark atlas on every
active progress update. This identified the issue later resolved by slot-local
render context reuse in the following recorded run.

### 2026-06-26, Skyriding Vigor Only, After Progress Context Reuse

Context: 122.6s focused Skyriding Vigor run after locking real in-flight settings
changes and reusing slot-local render context during active progress ticks. Combat
was 0.0s. `skyriding_active` was 122.6s, 100.0% of elapsed time, one segment,
active at report capture.

| Metric | Calls | Total ms | Avg ms | Max ms | SV ms/sec | SV calls/sec |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `sv.refresh` | 263 | 129.174 | 0.4912 | 2.401 | 1.053 | 2.14 |
| `sv.update_filling_slot_progress` | 2131 | 90.087 | 0.0423 | 0.392 | 0.735 | 17.37 |
| `sv.get_render_context` | 267 | 44.261 | 0.1658 | 0.580 | 0.361 | 2.18 |
| `sv.get_frame_atlas` | 267 | 19.816 | 0.0742 | 0.212 | 0.162 | 2.18 |
| `sv.get_bar_style` | 267 | 17.833 | 0.0668 | 0.478 | 0.145 | 2.18 |
| `sv.get_style_layout_table` | 267 | 15.875 | 0.0595 | 0.173 | 0.129 | 2.18 |
| `sv.set_slot_state` | 1582 | 14.131 | 0.0089 | 0.387 | 0.115 | 12.90 |
| `sv.get_spark_color` | 2237 | 14.016 | 0.0063 | 0.111 | 0.114 | 18.24 |
| `sv.get_valid_bar_style_key` | 267 | 11.389 | 0.0427 | 0.133 | 0.093 | 2.18 |
| `sv.get_charge_info` | 263 | 9.561 | 0.0364 | 0.144 | 0.078 | 2.14 |
| `sv.sync_settings_controls_enabled` | 263 | 6.724 | 0.0256 | 0.130 | 0.055 | 2.14 |
| `sv.get_gliding_state` | 1414 | 6.416 | 0.0045 | 0.168 | 0.052 | 11.53 |
| `sv.set_slot_visible` | 1578 | 5.825 | 0.0037 | 2.041 | 0.047 | 12.87 |
| `sv.is_mounted_in_advanced_flyable_area` | 53 | 4.893 | 0.0923 | 0.159 | 0.040 | 0.43 |
| `sv.apply_full_charge_fade` | 263 | 3.704 | 0.0141 | 0.048 | 0.030 | 2.14 |
| `sv.get_spark_atlas` | 267 | 3.473 | 0.0130 | 0.102 | 0.028 | 2.18 |
| `sv.is_settings_locked_by_flight` | 526 | 3.067 | 0.0058 | 0.031 | 0.025 | 4.29 |
| `sv.is_runtime_enabled` | 263 | 2.744 | 0.0104 | 0.032 | 0.022 | 2.14 |
| `sv.restore_frame_alpha` | 260 | 2.604 | 0.0100 | 0.032 | 0.021 | 2.12 |
| `sv.sync_fade_controls_enabled` | 263 | 2.501 | 0.0095 | 0.048 | 0.020 | 2.14 |
| `sv.set_move_mode` | 263 | 1.325 | 0.0050 | 0.014 | 0.011 | 2.14 |
| `sv.ensure_frame` | 526 | 1.185 | 0.0023 | 0.020 | 0.010 | 4.29 |
| `sv.is_player_ridealong_passenger` | 263 | 0.865 | 0.0033 | 0.014 | 0.007 | 2.14 |
| `sv.apply_layout` | 263 | 0.733 | 0.0028 | 0.014 | 0.006 | 2.14 |

Comparison: Slot-local render context reuse fixed the prior regression.
`sv.update_filling_slot_progress` dropped from 4.311ms/sec active to
0.735ms/sec active. `sv.get_render_context` dropped from 18.40 calls/sec active
to 2.18 calls/sec active, matching the refresh cadence rather than the progress
tick cadence. Style/atlas helpers followed the same pattern: `sv.get_bar_style`
dropped from 1.553ms/sec to 0.145ms/sec active and `sv.get_frame_atlas` dropped
from 1.754ms/sec to 0.162ms/sec active. No deeper local-helper probe is indicated
from this run.
