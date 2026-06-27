# Skyriding Vigor Module Review


## Open Items

No open Skyriding Vigor review items remain from this pass. Keep the temporary profiler load staged only until final cleanup.


## Profile Result

### 2026-06-26, Fill Test Baseline

Focused Skyriding Vigor run with only `PROFILE_TARGETS.skyriding_vigor = true`. Elapsed time was 129.7s. Combat was 0.0s. `skyriding_active` was 129.7s, 100.0% of elapsed time, one segment, active at report capture.

Top rows:

- `sv.update_filling_slot_progress`: 2316 calls, 363.644ms total, 2.804ms/sec active.

- `sv.refresh`: 298 calls, 333.786ms total, 2.574ms/sec active.

- `sv.get_bar_style`: 6553 calls, 307.898ms total, 2.374ms/sec active, 50.54 calls/sec active.

- `sv.set_slot_state`: 1790 calls, 278.693ms total, 2.149ms/sec active.

- `sv.get_frame_atlas`: 1790 calls, 112.043ms total, 0.864ms/sec active.

- `sv.get_style_layout_table`: 1790 calls, 90.150ms total, 0.695ms/sec active.

- `sv.get_valid_bar_style_key`: 1790 calls, 68.512ms total, 0.528ms/sec active.

Do not sum nested rows as exclusive cost. The shape still supports consolidation because style lookup and validation are both frequent and visibly nested under the active progress/render path.

### 2026-06-26, After Render Context

Focused Skyriding Vigor run after adding pass-local render context. Elapsed time was 140.8s. Combat was 0.0s. `skyriding_active` was 137.6s, 97.7% of elapsed time, one segment, active at report capture.

Top rows:

- `sv.update_filling_slot_progress`: 2394 calls, 593.390ms total, 4.311ms/sec active.

- `sv.get_render_context`: 2533 calls, 562.585ms total, 4.088ms/sec active.

- `sv.get_frame_atlas`: 2533 calls, 241.338ms total, 1.754ms/sec active.

- `sv.get_bar_style`: 2533 calls, 213.768ms total, 1.553ms/sec active, 18.40 calls/sec active.

- `sv.refresh`: 344 calls, 159.001ms total, 1.155ms/sec active.

- `sv.set_slot_state`: 2001 calls, 17.316ms total, 0.126ms/sec active.

Result: `sv.set_slot_state` improved sharply, from 2.149ms/sec active to 0.126ms/sec active, and `sv.refresh` improved from 2.574ms/sec to 1.155ms/sec. `sv.get_bar_style` calls also dropped from 50.54/sec to 18.40/sec. The remaining issue is that `sv.get_render_context` now rebuilds style/atlas context for each active progress tick.

### 2026-06-26, After Progress Context Reuse

Focused Skyriding Vigor run after locking real in-flight settings changes and reusing slot-local render context during active progress ticks. Elapsed time was 122.6s. Combat was 0.0s. `skyriding_active` was 122.6s, 100.0% of elapsed time, one segment, active at report capture.

Top rows:

- `sv.refresh`: 263 calls, 129.174ms total, 1.053ms/sec active.

- `sv.update_filling_slot_progress`: 2131 calls, 90.087ms total, 0.735ms/sec active.

- `sv.get_render_context`: 267 calls, 44.261ms total, 0.361ms/sec active, 2.18 calls/sec active.

- `sv.get_frame_atlas`: 267 calls, 19.816ms total, 0.162ms/sec active.

- `sv.get_bar_style`: 267 calls, 17.833ms total, 0.145ms/sec active, 2.18 calls/sec active.

- `sv.get_style_layout_table`: 267 calls, 15.875ms total, 0.129ms/sec active.

Result: `sv.update_filling_slot_progress` dropped from 4.311ms/sec active to 0.735ms/sec active. `sv.get_render_context` dropped from 18.40 calls/sec active to 2.18 calls/sec active, matching refresh cadence instead of progress tick cadence. Style/atlas helper rows followed the same pattern. No deeper local-helper probe is indicated from this run.


## Consolidation Applied

### 2026-06-26, Pass-Local Render Context

`sv_bar.lua` now builds a pass-local render context through `M.get_render_context(db)`. The context carries the active DB, `style_key`, `style`, `frame_atlas`, and `spark_atlas`.

`sv_main.lua` creates one render context per `M.refresh()` render pass and passes it into each `M.set_slot_state()` call. Slot rendering helpers now accept the already-resolved style/context where practical, so they do not repeatedly call `M.get_bar_style()` from nested size, atlas, spark, and fill paths.

This is intentionally pass-local. It does not add persistent cache invalidation state.

### 2026-06-26, Flight Settings Lock and Progress Context Reuse

Real active flight now rejects settings mutations through `M.is_settings_locked_by_flight()` and the main settings write paths. Fill Test remains editable while it is the active simulated state, but starting real flight stops Fill Test and re-locks settings. This makes in-flight render state stable enough for the progress driver to reuse slot-local render data safely.

`M.set_slot_state()` stamps each slot with the resolved DB, style key, style table, frame atlas, and spark atlas from the full render pass. `M.update_filling_slot_progress()` now reuses those slot-local values and falls back to `M.get_render_context()` only if the slot has not been initialized. The next profile should show whether `sv.get_render_context` and style/atlas helper rows drop out of the per-tick path.


## Profiling Setup Notes

Profiler setup remains staged for a focused Skyriding Vigor before/after run:

1. `internal_dev/tests_tools/addon_cpu_profile.lua` has `PROFILE_TARGETS.skyriding_vigor = true` and other targets disabled.

2. The profiler reports `skyriding_active` duration and appends `sv_msps` / `sv_callsps` to each metric when active time is present. This is the primary normalization for this review; combat time is still printed but is less relevant for Skyriding.

3. `LsTweeks.toc` temporarily loads `internal_dev\tests_tools\addon_cpu_profile.lua` after the normal addon files. Remove this line before release/package cleanup.

Profiler scope note: `addon_cpu_profile.lua` wraps addon-table functions. For this focused run, Skyriding Vigor rows are abbreviated as `sv.*`, such as `sv.get_bar_style`, `sv.refresh`, `sv.set_slot_state`, `sv.update_filling_slot_progress`, and `sv.apply_layout`. Local helpers in `sv_bar.lua`, including `get_fill_size()`, `get_node_size()`, `get_frame_size()`, and `get_background_size()`, must be inferred from parent timings unless a narrower temporary probe is added.
