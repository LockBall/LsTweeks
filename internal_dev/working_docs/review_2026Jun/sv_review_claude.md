# Skyriding Vigor Module Review — 2026-06-26

## Issues Found

## Summary

No bugs found. sv_gui.lua length is not a problem — its concerns are cohesive and already well-decomposed internally.

Actionable items:
1. **Duplicated `clamp_number`** (#1) — consolidate into shared utility
2. **`_suppress_callback` may be dead code** (#2) — verify against shared slider factory
3. **Asymmetric sync guards** (#3) — standardize once #2 is resolved
4. **Double-local in `create_slot`** (#4) — minor cleanup
5. **`get_bar_style()` call frequency** (optimization #1-2) — cache per refresh cycle if profiling warrants

### 1. Duplicated `clamp_number` helper
- **sv_main.lua:66-72** and **sv_styles.lua:230-236** define identical `clamp_number` functions.
- Not a bug (both are local), but a maintenance risk — if clamping logic changes, both must be updated.
- **Recommendation:** Move to a shared utility (e.g. `functions/table_utils.lua`) or have one file export it via `M`.

### 2. `sync_slider_controls` uses `_suppress_callback` alongside `_syncing_slider_controls`
- **sv_gui.lua:306-327** — Sets `M._syncing_slider_controls = true` as a re-entrancy guard, but *also* sets `control._suppress_callback = true` per-control (lines 320-322).
- `set_setting_from_slider` (line 132-137) only checks `M._syncing_slider_controls`, so `_suppress_callback` is unused by the module's own callbacks.
- **Question:** Is `_suppress_callback` consumed by the shared `CreateSliderWithBox` implementation? If not, it's dead code.
- **Recommendation:** Verify whether the shared slider factory reads `_suppress_callback`. If not, remove it from all sync functions (also in `sync_decor_position_controls` lines 337-349).

### 3. `sync_decor_position_controls` and `sync_position_controls` — asymmetric guard patterns
- `sync_position_controls` (line 283) uses `M._syncing_position_controls` as its re-entrancy guard.
- `sync_decor_position_controls` (line 329) uses `_suppress_callback` per-control instead.
- These should use the same pattern for consistency. Tied to issue #2 — resolving `_suppress_callback` will clarify the right pattern.

### 4. sv_bar.lua double-locals `_, style` in `create_slot`
- **sv_bar.lua:503 and 532** — `local _, style = M.get_bar_style(get_db())` is called twice in the same function scope. The second declaration shadows the first.
- **Recommendation:** Remove the second `local` or hoist the call.

---

## Optimization Opportunities

### Runtime Performance (sv_bar.lua / sv_main.lua)

1. **`get_bar_style()` is called very frequently** — every `set_slot_state`, `update_slot_spark`, `set_slot_progress`, `apply_slot_static_atlases`, `set_bar_atlas`, `set_spark_atlas`, `set_slot_spark_clip_bounds`, and inside `apply_layout`. Each call does a table lookup + validation. Consider caching the result per-refresh cycle (set at top of `M.refresh()`, cleared at end or on invalidation).

2. **`get_fill_size()`, `get_node_size()`, `get_frame_size()`, `get_background_size()`** are called repeatedly during slot iteration. They internally call `get_bar_style()` again. These are pure functions of the current style — caching per layout pass would reduce redundant work.
