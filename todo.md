# Temporary TODO

- Guard aura-frame anchor, size, and height writes during combat. `setup_layout()` is guarded, but `update_auras()` still reanchors/resizes frames and calls `set_height_for_growth()` from deferred event updates. Defer geometry changes until `PLAYER_REGEN_ENABLED`.
