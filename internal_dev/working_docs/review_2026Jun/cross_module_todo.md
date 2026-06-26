# Cross-Module TODO

## Settings Builder Rule
1. [x] Carry the addon-wide settings-builder rule from `project.md` through other settings modules when they are next touched. Review `modules/sound_levels/sl_gui.lua` and `modules/aura_frames/af_gui.lua` for long `BuildSettings()` functions that would benefit from local section-builder functions plus a small local `context` table, without expanding each module's public `M` surface.

    2026-06-25 status: Sound Levels already uses local tab builders. Aura Frames `BuildSettings()` now uses local helpers plus a small `context` table.

2. [x] Revisit `modules/aura_frames/af_gui.lua` exported GUI builders such as `M.build_profiles_tab`, `M.build_general_tab`, and `M.build_frames_tab`. Keep exported builders only where another file genuinely needs them; otherwise prefer local builders so Aura Frames aligns with the cleaner `sound_levels/sl_gui.lua` pattern and avoids unnecessary public `M` surface area.

    2026-06-25 status: `build_profiles_tab` is local to `af_gui.lua`. `M.build_general_tab` and `M.build_frames_tab` still cross file boundaries under the current Aura Frames GUI split.


## Skyriding Vigor GUI Modularization
1. [ ] Revisit `modules/skyriding_vigor/sv_gui.lua` split boundaries after the completed settings-grid consolidation. Prefer boundaries that keep layout constants/private builders local and avoid exposing GUI implementation details through `M` just to bridge files.
