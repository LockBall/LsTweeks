# Disabled Aura Frames Settings Error

Active assessment of the 2026-08-14 error saved in `new_issue.txt`.


## Reproduction
- Disable **Buffs & Debuffs** in the Settings module-enabler tab.
- Click the disabled **Buffs & Debuffs** sidebar button.
- The settings category begins building before its lock overlay is applied.
- `af_gui_frame_builders.lua:523` reads `M.db.enable_blizz_buffs` while `M.db` is `nil`.


## Condensed Error
- One unique message, one stack variant, three reported occurrences.
- Failure: `af_gui_frame_builders.lua:523: attempt to index field 'db' (a nil value)`.
- Stack: `build_general_tab` -> `BuildSettings` -> Aura Frames category builder -> `core/main_frame.lua` tab selection.


## Root Cause
- Aura Frames always registers its settings category during `ADDON_LOADED`.
- The shared settings window intentionally permits disabled category selection, builds the category, and then applies a mouse-blocking lock overlay.
- Aura Frames assigns `M.db`, applies defaults, and creates runtime frames only inside `ensure_module_started()`.
- Startup calls `ensure_module_started()` only when the module is enabled. A module disabled before reload therefore has a registered settings builder but no attached `M.db`.
- This is a module lifecycle boundary error, not a tooltip error. Other inspected module settings builders obtain or initialize their data independently of runtime enablement; Aura Frames is the identified exception.


## Proposed Fix
- Separate data preparation from runtime/frame startup.
- During Aura Frames `ADDON_LOADED`, always attach `M.db` to `Ls_Tweeks_DB.aura_frames`, apply defaults, and normalize saved data before registering or building settings.
- Continue creating Aura frames and starting events, timers, scans, Blizzard-frame handling, and other runtime services only when the module is enabled.
- Keep `ensure_module_started()` idempotent so enabling later creates the runtime frames exactly once from the already-prepared DB.


## Implementation Status
- Implemented in `af_main.lua`: disabled startup now prepares `M.db` before category registration; `ensure_module_started()` reuses prepared data and remains the frame-creation boundary.
- Implemented shared sidebar locked-state styling in `core/main_frame.lua`: disabled modules retain dark-grey text while the standard button highlight marks a selected locked page; they remain clickable.
- Added `test_af_disabled_settings.lua` covering disabled boot, settings construction, locked selected styling, zero runtime/frame startup, later enablement, DB identity, and duplicate-enable protection.
- Headless and static validation passed; awaiting in-game confirmation before archiving this note and `new_issue.txt`.


## Regression Coverage
- Boot the full addon with `modules.aura_frames = false`.
- Select/build the **Buffs & Debuffs** category and assert no error.
- Assert `M.db` exists and defaults are available.
- Assert the module remains runtime-disabled with no Aura runtime frames, events, ticker, scan work, or Blizzard visibility suppression started merely by opening settings.
- Enable the module afterward and assert frames/runtime start once and use the same saved DB table.
