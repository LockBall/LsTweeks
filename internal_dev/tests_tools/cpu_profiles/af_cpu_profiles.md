# Aura Frames CPU Profiles

Long-term capture for Aura Frames focused in-game profiling runs.

## Whole-Addon Profiler Runs

Use `internal_dev/tests_tools/addon_cpu_profile.lua` with only `PROFILE_TARGETS.aura_frames = true` for these runs.

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
contributors. Per-call costs are stable versus the broad run. Durable Aura
performance conclusions live in `internal_dev/working_docs/proj_mem/aura_frames.md`;
use `internal_dev/working_docs/review_2026Jun/aura_frames_performance_review.md`
only if Aura performance work is reopened.

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
direct-bucket cleanup because it is safe and removes avoidable work. Durable Aura
performance conclusions live in `internal_dev/working_docs/proj_mem/aura_frames.md`;
use `internal_dev/working_docs/review_2026Jun/aura_frames_performance_review.md`
only if Aura performance work is reopened.

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

### 2026-06-23, Aura Frames Only, Runtime Config Cache

Context: 133.4s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
a frame-local runtime config cache for scalar/layout values and sharing it with
`setup_layout()`. User exercised normal Aura Frames activity rather than idling.
Colors remained uncached.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1562 | 708.094 | 0.4533 | 5.125 |
| `aura_frames.tick_visible_icons` | 1249 | 341.296 | 0.2733 | 0.959 |
| `aura_frames.render_aura_map` | 1562 | 313.348 | 0.2006 | 5.000 |
| `aura_frames.unified_scan` | 146 | 95.705 | 0.6555 | 1.292 |
| `aura_frames.add_cooldown_viewer_category_entries` | 882 | 82.724 | 0.0938 | 0.450 |
| `aura_frames.set_timer_text` | 16817 | 82.238 | 0.0049 | 0.207 |
| `aura_frames.scan_custom_aura_map` | 136 | 76.766 | 0.5645 | 2.511 |
| `aura_frames.get_frame_activity_state` | 6318 | 52.561 | 0.0083 | 0.291 |
| `aura_frames.refresh_frame_ooc_fade` | 1565 | 28.890 | 0.0185 | 0.107 |
| `aura_frames.get_setting` | 12100 | 26.087 | 0.0022 | 0.150 |
| `aura_frames.is_runtime_enabled` | 2816 | 21.999 | 0.0078 | 0.183 |
| `aura_frames.mark_aura_scan_dirty` | 1587 | 11.821 | 0.0074 | 0.215 |
| `aura_frames.get_frame_config_db` | 6324 | 11.596 | 0.0018 | 0.036 |
| `aura_frames.get_timer_behavior` | 1697 | 10.995 | 0.0065 | 0.103 |
| `aura_frames.get_bar_bg_color` | 1562 | 10.622 | 0.0068 | 0.120 |
| `aura_frames.merge_aura_info` | 1566 | 9.303 | 0.0059 | 0.041 |
| `aura_frames.normalize_timer_category` | 1697 | 5.357 | 0.0032 | 0.100 |
| `aura_frames.prepare_blizz_cdm_viewer` | 882 | 3.698 | 0.0042 | 0.069 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1733 | 2.789 | 0.0016 | 0.034 |
| `aura_frames.get_cdm_viewer_frame` | 1100 | 2.564 | 0.0023 | 0.026 |
| `aura_frames.refresh_visible_icon_ticker` | 1562 | 2.333 | 0.0015 | 0.017 |
| `aura_frames.clear_custom_aura_scan_cache` | 1587 | 2.297 | 0.0014 | 0.010 |
| `aura_frames.update_blizz_cdm_visibility` | 86 | 1.166 | 0.0136 | 0.035 |
| `aura_frames.get_custom_aura_filter` | 136 | 1.042 | 0.0077 | 0.015 |
| `aura_frames.set_height_for_growth` | 9 | 0.580 | 0.0644 | 0.078 |

Conclusion: The runtime config cache is a measured win for config-resolution
overhead. Compared with the prior visible-ticker run, `get_setting` dropped from
about 142.8 calls/sec to 90.7 calls/sec, and `is_timer_text_enabled` plus
`uses_cooldown_icon_overlay` no longer appeared in the report. `update_auras`
averaged 0.4533ms, lower than the prior 0.4968ms run and close to the earlier
clean comparison point. Keep the cache, with colors still deferred to the
separate color-cache review.

### 2026-06-23, Aura Frames Only, Runtime Color Cache

Context: 107.1s run with only `PROFILE_TARGETS.aura_frames = true`, after extending
the frame-local runtime config cache to store copied scalar color components for
bar color, bar background color, bar text color, and frame background color.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1467 | 573.636 | 0.3910 | 2.016 |
| `aura_frames.tick_visible_icons` | 1002 | 277.317 | 0.2768 | 0.742 |
| `aura_frames.render_aura_map` | 1467 | 263.963 | 0.1799 | 1.045 |
| `aura_frames.unified_scan` | 141 | 88.470 | 0.6274 | 1.368 |
| `aura_frames.add_cooldown_viewer_category_entries` | 837 | 74.005 | 0.0884 | 0.530 |
| `aura_frames.set_timer_text` | 15780 | 70.652 | 0.0045 | 0.188 |
| `aura_frames.scan_custom_aura_map` | 126 | 60.534 | 0.4804 | 1.187 |
| `aura_frames.get_frame_activity_state` | 6263 | 47.792 | 0.0076 | 0.113 |
| `aura_frames.refresh_frame_ooc_fade` | 1467 | 24.867 | 0.0170 | 0.216 |
| `aura_frames.is_runtime_enabled` | 2473 | 16.988 | 0.0069 | 0.186 |
| `aura_frames.mark_aura_scan_dirty` | 1686 | 11.996 | 0.0071 | 0.208 |
| `aura_frames.get_frame_config_db` | 6263 | 11.341 | 0.0018 | 0.107 |
| `aura_frames.get_setting` | 5490 | 11.132 | 0.0020 | 0.032 |
| `aura_frames.get_timer_behavior` | 1592 | 9.359 | 0.0059 | 0.128 |
| `aura_frames.merge_aura_info` | 1665 | 9.258 | 0.0056 | 0.033 |
| `aura_frames.normalize_timer_category` | 1592 | 4.355 | 0.0027 | 0.025 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1827 | 2.849 | 0.0016 | 0.081 |
| `aura_frames.clear_custom_aura_scan_cache` | 1686 | 2.469 | 0.0015 | 0.025 |
| `aura_frames.refresh_visible_icon_ticker` | 1467 | 2.195 | 0.0015 | 0.021 |
| `aura_frames.get_cdm_viewer_frame` | 916 | 2.138 | 0.0023 | 0.049 |
| `aura_frames.prepare_blizz_cdm_viewer` | 837 | 1.949 | 0.0023 | 0.150 |
| `aura_frames.get_custom_aura_filter` | 126 | 0.869 | 0.0069 | 0.016 |
| `aura_frames.update_blizz_cdm_visibility` | 37 | 0.508 | 0.0137 | 0.131 |
| `aura_frames.get_custom_modifier_def` | 126 | 0.275 | 0.0022 | 0.010 |
| `aura_frames.cdm_category_needs_viewer` | 13 | 0.265 | 0.0204 | 0.037 |

Conclusion: Color scalar caching is a measured win. Compared with the prior
runtime-config cache run, `get_setting` dropped from about 90.7 calls/sec to
51.3 calls/sec, and `get_bar_bg_color` no longer appeared in the report.
`update_auras` averaged 0.3910ms versus 0.4533ms in the prior run. Keep this
candidate if a manual settings check confirms visible colors update immediately
after picker changes.

### 2026-06-24, Aura Frames Only, Visible Icon Tick 0.10s Combat Baseline

Context: 75.5s run with only `PROFILE_TARGETS.aura_frames = true`, `Timer Tick
Sec` set to `0.10`, and combat timing enabled. Combat was active for 72.2s
(95.7% of elapsed time), one segment, and the report was captured after combat
ended. Earlier partial/aborted runs in the same pasted block were ignored.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1384 | 520.805 | 0.3763 | 4.146 |
| `aura_frames.render_aura_map` | 1384 | 236.809 | 0.1711 | 1.396 |
| `aura_frames.tick_visible_icons` | 691 | 215.380 | 0.3117 | 0.789 |
| `aura_frames.unified_scan` | 140 | 82.442 | 0.5889 | 2.904 |
| `aura_frames.set_timer_text` | 15809 | 64.863 | 0.0041 | 0.210 |
| `aura_frames.add_cooldown_viewer_category_entries` | 744 | 62.111 | 0.0835 | 0.428 |
| `aura_frames.scan_custom_aura_map` | 128 | 60.112 | 0.4696 | 3.030 |
| `aura_frames.get_frame_activity_state` | 6079 | 43.141 | 0.0071 | 0.092 |
| `aura_frames.refresh_frame_ooc_fade` | 1384 | 22.359 | 0.0162 | 0.173 |
| `aura_frames.is_runtime_enabled` | 2078 | 12.816 | 0.0062 | 0.030 |
| `aura_frames.mark_aura_scan_dirty` | 1650 | 10.640 | 0.0064 | 0.133 |
| `aura_frames.get_setting` | 5152 | 10.128 | 0.0020 | 0.072 |
| `aura_frames.get_frame_config_db` | 6079 | 10.064 | 0.0017 | 0.025 |
| `aura_frames.merge_aura_info` | 1629 | 8.963 | 0.0055 | 0.048 |
| `aura_frames.get_timer_behavior` | 1512 | 8.710 | 0.0058 | 0.031 |
| `aura_frames.normalize_timer_category` | 1512 | 4.147 | 0.0027 | 0.023 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1790 | 2.696 | 0.0015 | 0.126 |
| `aura_frames.clear_custom_aura_scan_cache` | 1650 | 2.254 | 0.0014 | 0.015 |
| `aura_frames.refresh_visible_icon_ticker` | 1384 | 2.020 | 0.0015 | 0.015 |
| `aura_frames.get_cdm_viewer_frame` | 792 | 2.006 | 0.0025 | 0.019 |
| `aura_frames.prepare_blizz_cdm_viewer` | 744 | 1.527 | 0.0021 | 0.040 |
| `aura_frames.get_custom_aura_filter` | 128 | 0.888 | 0.0069 | 0.026 |
| `aura_frames.update_blizz_cdm_visibility` | 24 | 0.367 | 0.0153 | 0.044 |
| `aura_frames.cdm_category_needs_viewer` | 12 | 0.266 | 0.0222 | 0.040 |
| `aura_frames.set_height_for_growth` | 5 | 0.265 | 0.0531 | 0.062 |

Conclusion: This is the clean combat-timed baseline for ticker interval
comparison. `tick_visible_icons` ran about 9.15 calls/sec elapsed, or 9.57
calls/sec combat-normalized. Ticker CPU was about 2.85ms/sec elapsed, or
2.98ms/sec combat-normalized.

### 2026-06-24, Aura Frames Only, Visible Icon Tick Provisional Slider Test

Context: 67.3s run with only `PROFILE_TARGETS.aura_frames = true`, after adding
the temporary main UI slider for `aura_visible_icon_tick` (`0.10` to `0.20`
seconds, `0.01` increments). The slider value was not captured in the pasted
report; expected test value was `0.15`. Combat timing was not available for this
run, so do not use it as the final `0.15` comparison.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1030 | 377.284 | 0.3663 | 3.774 |
| `aura_frames.render_aura_map` | 1030 | 174.227 | 0.1692 | 1.053 |
| `aura_frames.tick_visible_icons` | 423 | 116.039 | 0.2743 | 0.782 |
| `aura_frames.unified_scan` | 91 | 53.085 | 0.5834 | 1.337 |
| `aura_frames.add_cooldown_viewer_category_entries` | 620 | 49.863 | 0.0804 | 0.712 |
| `aura_frames.scan_custom_aura_map` | 82 | 40.308 | 0.4916 | 3.191 |
| `aura_frames.set_timer_text` | 8704 | 34.213 | 0.0039 | 0.046 |
| `aura_frames.get_frame_activity_state` | 4068 | 28.635 | 0.0070 | 0.085 |
| `aura_frames.refresh_frame_ooc_fade` | 1030 | 16.506 | 0.0160 | 0.214 |
| `aura_frames.is_runtime_enabled` | 1456 | 9.277 | 0.0064 | 0.034 |
| `aura_frames.get_setting` | 3874 | 7.379 | 0.0019 | 0.030 |
| `aura_frames.get_frame_config_db` | 4068 | 6.639 | 0.0016 | 0.048 |
| `aura_frames.mark_aura_scan_dirty` | 993 | 6.181 | 0.0062 | 0.026 |
| `aura_frames.get_timer_behavior` | 1112 | 6.119 | 0.0055 | 0.026 |
| `aura_frames.merge_aura_info` | 972 | 5.238 | 0.0054 | 0.040 |
| `aura_frames.normalize_timer_category` | 1112 | 2.920 | 0.0026 | 0.016 |
| `aura_frames.refresh_visible_icon_ticker` | 1030 | 1.609 | 0.0016 | 0.093 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1084 | 1.539 | 0.0014 | 0.012 |
| `aura_frames.get_cdm_viewer_frame` | 680 | 1.457 | 0.0021 | 0.010 |
| `aura_frames.prepare_blizz_cdm_viewer` | 620 | 1.444 | 0.0023 | 0.064 |
| `aura_frames.clear_custom_aura_scan_cache` | 993 | 1.284 | 0.0013 | 0.016 |
| `aura_frames.get_custom_aura_filter` | 82 | 0.577 | 0.0070 | 0.012 |
| `aura_frames.update_blizz_cdm_visibility` | 28 | 0.342 | 0.0122 | 0.023 |
| `aura_frames.set_height_for_growth` | 6 | 0.308 | 0.0513 | 0.092 |
| `aura_frames.get_custom_modifier_def` | 82 | 0.180 | 0.0022 | 0.005 |

Conclusion: Provisional only. Ticker frequency reduction appeared to work:
compared with the prior runtime color-cache run, `tick_visible_icons` dropped
from about 9.36 calls/sec to 6.29 calls/sec, and ticker CPU dropped from about
2.59ms/sec to 1.72ms/sec. Because this run lacked combat timing and did not
capture the exact slider value, replace it with a clean `0.15` combat-timed run
before comparing `0.15` against `0.20`.

### 2026-06-24, Aura Frames Only, Visible Icon Tick 0.15s Combat Test

Context: 51.0s run with only `PROFILE_TARGETS.aura_frames = true`, `Timer Tick
Sec` set to `0.15`, and combat timing enabled. Combat was active for 49.2s
(96.4% of elapsed time), one segment, and the report was captured after combat
ended.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 894 | 341.620 | 0.3821 | 2.124 |
| `aura_frames.render_aura_map` | 894 | 156.339 | 0.1749 | 0.815 |
| `aura_frames.tick_visible_icons` | 322 | 99.484 | 0.3090 | 0.654 |
| `aura_frames.unified_scan` | 83 | 54.699 | 0.6590 | 1.756 |
| `aura_frames.add_cooldown_viewer_category_entries` | 529 | 43.252 | 0.0818 | 0.351 |
| `aura_frames.scan_custom_aura_map` | 73 | 34.652 | 0.4747 | 1.118 |
| `aura_frames.set_timer_text` | 7695 | 31.616 | 0.0041 | 0.138 |
| `aura_frames.get_frame_activity_state` | 3544 | 25.627 | 0.0072 | 0.188 |
| `aura_frames.refresh_frame_ooc_fade` | 895 | 14.759 | 0.0165 | 0.109 |
| `aura_frames.is_runtime_enabled` | 1220 | 7.770 | 0.0064 | 0.165 |
| `aura_frames.get_setting` | 3366 | 6.616 | 0.0020 | 0.057 |
| `aura_frames.get_frame_config_db` | 3553 | 6.095 | 0.0017 | 0.089 |
| `aura_frames.get_timer_behavior` | 967 | 5.600 | 0.0058 | 0.028 |
| `aura_frames.mark_aura_scan_dirty` | 903 | 5.479 | 0.0061 | 0.046 |
| `aura_frames.merge_aura_info` | 882 | 4.696 | 0.0053 | 0.201 |
| `aura_frames.normalize_timer_category` | 967 | 2.633 | 0.0027 | 0.016 |
| `aura_frames.get_cdm_viewer_frame` | 560 | 1.406 | 0.0025 | 0.026 |
| `aura_frames.refresh_visible_icon_ticker` | 894 | 1.393 | 0.0016 | 0.062 |
| `aura_frames.clear_sorted_aura_ids_cache` | 986 | 1.364 | 0.0014 | 0.025 |
| `aura_frames.clear_custom_aura_scan_cache` | 903 | 1.177 | 0.0013 | 0.026 |
| `aura_frames.prepare_blizz_cdm_viewer` | 529 | 0.897 | 0.0017 | 0.033 |
| `aura_frames.get_custom_aura_filter` | 73 | 0.484 | 0.0066 | 0.013 |
| `aura_frames.update_blizz_cdm_visibility` | 21 | 0.289 | 0.0138 | 0.034 |
| `aura_frames.update_all_blizz_cdm_visibility` | 4 | 0.282 | 0.0704 | 0.092 |
| `aura_frames.cdm_category_needs_viewer` | 13 | 0.244 | 0.0188 | 0.031 |

Conclusion: The clean `0.15` combat-timed run reduced ticker CPU/sec versus
the clean `0.10` combat baseline, but not as much as `0.20`. `tick_visible_icons`
ran about 6.31 calls/sec elapsed, or 6.54 calls/sec combat-normalized. Ticker
CPU was about 1.95ms/sec elapsed, or 2.02ms/sec combat-normalized, about 32%
lower than the clean `0.10` combat baseline. Compared with `0.15`, the `0.20`
run was about 24% lower in ticker calls/sec and about 26% lower in ticker CPU/sec.

### 2026-06-24, Aura Frames Only, Visible Icon Tick 0.20s Combat Test

Context: 62.0s run with only `PROFILE_TARGETS.aura_frames = true`, `Timer Tick
Sec` set to `0.20`, and combat timing enabled. Combat was active for 60.1s
(96.8% of elapsed time), one segment, and the report was captured while still
in combat.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `aura_frames.update_auras` | 1007 | 374.010 | 0.3714 | 1.666 |
| `aura_frames.render_aura_map` | 1007 | 174.627 | 0.1734 | 0.962 |
| `aura_frames.tick_visible_icons` | 299 | 90.119 | 0.3014 | 0.697 |
| `aura_frames.unified_scan` | 96 | 56.815 | 0.5918 | 1.124 |
| `aura_frames.add_cooldown_viewer_category_entries` | 592 | 47.600 | 0.0804 | 0.309 |
| `aura_frames.scan_custom_aura_map` | 83 | 37.675 | 0.4539 | 0.829 |
| `aura_frames.set_timer_text` | 7577 | 30.225 | 0.0040 | 0.138 |
| `aura_frames.get_frame_activity_state` | 4239 | 29.975 | 0.0071 | 0.047 |
| `aura_frames.refresh_frame_ooc_fade` | 1007 | 15.950 | 0.0158 | 0.070 |
| `aura_frames.is_runtime_enabled` | 1309 | 8.105 | 0.0062 | 0.158 |
| `aura_frames.get_setting` | 3779 | 7.244 | 0.0019 | 0.043 |
| `aura_frames.mark_aura_scan_dirty` | 1083 | 6.734 | 0.0062 | 0.039 |
| `aura_frames.get_frame_config_db` | 4239 | 6.589 | 0.0016 | 0.015 |
| `aura_frames.get_timer_behavior` | 1090 | 6.294 | 0.0058 | 0.076 |
| `aura_frames.merge_aura_info` | 1071 | 5.368 | 0.0050 | 0.098 |
| `aura_frames.normalize_timer_category` | 1090 | 2.922 | 0.0027 | 0.027 |
| `aura_frames.clear_sorted_aura_ids_cache` | 1179 | 1.721 | 0.0015 | 0.025 |
| `aura_frames.get_cdm_viewer_frame` | 604 | 1.497 | 0.0025 | 0.014 |
| `aura_frames.refresh_visible_icon_ticker` | 1007 | 1.464 | 0.0015 | 0.016 |
| `aura_frames.clear_custom_aura_scan_cache` | 1083 | 1.307 | 0.0012 | 0.016 |
| `aura_frames.prepare_blizz_cdm_viewer` | 592 | 0.881 | 0.0015 | 0.015 |
| `aura_frames.get_custom_aura_filter` | 83 | 0.589 | 0.0071 | 0.021 |
| `aura_frames.cdm_category_needs_viewer` | 12 | 0.184 | 0.0154 | 0.021 |
| `aura_frames.get_custom_modifier_def` | 83 | 0.171 | 0.0021 | 0.005 |
| `aura_frames.update_all_blizz_cdm_visibility` | 3 | 0.150 | 0.0501 | 0.057 |

Conclusion: The `0.20` setting produced the expected ticker reduction in a
combat-heavy run. `tick_visible_icons` ran about 4.82 calls/sec elapsed, or
4.98 calls/sec combat-normalized, versus about 9.57 calls/sec in the clean
`0.10` combat baseline. Ticker CPU dropped from about 2.98ms/sec at `0.10` to
about 1.45ms/sec elapsed, or 1.50ms/sec combat-normalized, a roughly 50% ticker
CPU/sec reduction. This is a strong candidate if visual smoothness was acceptable.

### Visible Icon Tick Comparison Scratch

Use only combat-timed runs for final interval selection.

| Tick setting | Combat timed? | Calls/sec | CPU ms/sec | Notes |
| --- | --- | ---: | ---: | --- |
| `0.10` | Yes | 9.57 | 2.98 | 72.2s combat out of 75.5s elapsed. |
| `0.15` | Yes | 6.54 | 2.02 | 49.2s combat out of 51.0s elapsed. |
| `0.20` | Yes | 4.98 | 1.50 | 60.1s combat out of 62.0s elapsed. |

## Aura Frames Duration Probe

Long-term capture for Aura Frames in-game profiling runs. Use
`internal_dev/tests_tools/aura_frames_duration_profile.lua` when collecting comparable
data.

## Current Decision

`C_UnitAuras.GetAuraDuration` is not a meaningful hotspot based on the collected
2026-06-06 data. Keep the defensive `GetAuraDuration` guards in `af_core.lua`,
`af_render.lua`, and `af_scan.lua`; do not restructure duration handling for CPU
reasons unless future profiling shows a material regression.

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


