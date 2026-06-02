# Scratchpad

## Current Refocus: Fishing Focus

Actionable focus: validate and polish the Sound Levels **Fishing Focus** implementation.

Read first:
- `README.md`
- `internal_docs/working_docs/proj_mem.md`
- `modules/sound_levels/sl_defaults.lua`
- `modules/sound_levels/sl_functions.lua`
- `modules/sound_levels/sl_core.lua`
- `modules/sound_levels/sl_fishing.lua`
- `modules/sound_levels/sl_gui.lua`
- `modules/sound_levels/sl_main.lua`
- `LsTweeks.toc`

Current implementation summary:
- Exact Fishing Bobber bite replacement is blocked; the bite moment was not exposed through tested Lua hooks/APIs.
- Fishing Focus is the chosen user-facing solution: a temporary second sound-channel profile while the player channels Fishing.
- Fishing Focus lives in `modules/sound_levels/sl_fishing.lua`.
- The UI lives in the Sound Levels `Fishing` tab.
- Fishing profile values initialize from the user's current normal channel CVars, then preserve user edits.
- Runtime applies the Fishing profile on Fishing channel spell `131476` start and restores cached normal CVars on channel stop/reset/logout.
- Angleur is credited for the temporary audio-profile inspiration; Resonance should not be credited for the mute/replacement design.

Next useful checks:
- Review `sl_fishing.lua`, `sl_gui.lua`, and TOC integration for correctness.
- Test in-game UI layout: five channel sliders should appear as separate columns.
- Test runtime: enable Fishing Focus, set obvious channel values, cast Fishing, confirm CVars change during channel and restore afterward.
- Decide whether to remove the temporary `internal_docs/tests/fishing_sound_probe.lua` TOC entry before release.
