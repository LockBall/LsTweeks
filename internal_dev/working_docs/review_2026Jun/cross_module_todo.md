# Cross-Module TODO

## Settings Builder Rule
1. [ ] Carry the addon-wide settings-builder rule from `project.md` through other settings modules when they are next touched. Review `modules/sound_levels/sl_gui.lua` and `modules/aura_frames/af_gui.lua` for long `BuildSettings()` functions that would benefit from local section-builder functions plus a small local `context` table, without expanding each module's public `M` surface.

2. [ ] Revisit `modules/aura_frames/af_gui.lua` exported GUI builders such as `M.build_profiles_tab`, `M.build_general_tab`, and `M.build_frames_tab`. Keep exported builders only where another file genuinely needs them; otherwise prefer local builders so Aura Frames aligns with the cleaner `sound_levels/sl_gui.lua` pattern and avoids unnecessary public `M` surface area.


## Settings Grid Consolidation
1. [ ] Review current settings-grid usage across modules and consolidate the remaining common patterns into `functions/layout_grid.lua` or another addon-wide helper where appropriate. Goal: existing and new modules should be able to use a consistent row/column settings layout without duplicating grid setup, placement, centering, dynamic width handling, or divider-row conventions.
