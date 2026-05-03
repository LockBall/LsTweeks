# Temporary TODO

- Guard aura-frame anchor, size, and height writes during combat. `setup_layout()` is guarded, but `update_auras()` still reanchors/resizes frames and calls `set_height_for_growth()` from deferred event updates. Defer geometry changes until `PLAYER_REGEN_ENABLED`.
- Replace the time-based shared aura scan cache with an event-batch or dirty/version flag. The current `M._last_unified_scan_time` reuse can skip a fresh pending aura event if it lands inside the 0.1s window.
- Reduce repeated CDM viewer child table allocations in `af_scan.lua`. The `ipairs({viewer:GetChildren()})` loops are functional but allocate on refresh paths; use a reusable scratch table or equivalent helper if CDM churn becomes noticeable.
