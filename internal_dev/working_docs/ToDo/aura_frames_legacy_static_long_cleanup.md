# Aura Frames Legacy Static/Long Cleanup
Preparation inventory for removing the legacy `static` and `long` preset frames after the managed `static_long` frame is committed and accepted in game. No saved-data migration is required; use an Aura Frames reset after the cleanup.


## Remove With The Legacy Presets
- `af_defaults.lua`: `static`/`long` `FRAME_DEFS`, their explicit preset defaults, and saved positions. Keep the managed `static_long` definition and learned cache.
- `af_test_aura.lua`: Static preset preview, shared Long preview phases, Long-to-Short preview transfer, and their preset-only clock helpers. Preserve generic/custom and CDM preview support.
- `af_logic_main.lua`: shared Long preview branches and preset category-bucket rendering. Re-evaluate the shared-scan branch only after CDM is decoupled from it.
- `af_functions.lua`: real/preset Long-to-Short reclassification and preset Static/Long cancellation eligibility. Preserve custom-frame cancellation and timer-category behavior.
- GUI/profile/default references generated from `FRAME_DEFS` disappear automatically when the two definitions are removed; delete remaining explicit Static/Long wording and settings.
- Tests whose sole subject is a removed preset should be deleted or rewritten around the surviving custom/managed owner: legacy Long preview transfer, legacy Static test preview, and assertions that Long owns a legacy pool/event route.


## Keep As Shared Custom-Frame Behavior
- `af_scan.lua` custom Aura classification still needs the per-entry strings `static`, `short`, `long`, and `debuff`; these are timer/render classifications, not preset identities.
- `af_functions.lua` must retain Static timer suppression through `TIMER_BEHAVIOR.static` because custom frames may contain permanent Auras.
- `af_render.lua` and `af_logic_ticker.lua` must retain `entry.category == "static"` / `aura_is_static` handling for mixed custom frames. Remove only preset-frame shortcuts such as `frame.category == "static"` after the preset is gone.
- `scan_custom_aura_map()`, custom scan caches, guarded tooltip prewarming, custom cancellation, generic legacy icon pools, layout, timer formatting, and rendering remain owned by custom frames.
- CDM entry builders and legacy icon rendering remain required by Essential, Utility, Tracked Buffs, and Tracked Bars.


## Shared Scan And CDM Cross-Check
- `get_frame_activity_state()` currently marks every enabled non-custom legacy backend as `needs_shared_scan`, including CDM frames. Managed presets return before this branch, but enabled CDM frames can still run `unified_scan()` before their viewer walk.
- `add_cooldown_viewer_category_entries()` can build a missing active Aura entry from the Blizzard child Aura instance ID, so CDM should be given an explicit no-shared-scan path and regression-tested before deleting `unified_scan()` or its preset buckets.
- After Static/Long removal, audit whether any remaining caller truly needs `_aura_maps_by_category`. Delete the unified helpful/debuff preset scan only when CDM, custom frames, tooltips, and tests pass without it.


## Regression Boundary Before Deletion
- Managed Static / Long tests assert the explicit `static_long` metadata/backend/profile keys and absence of a `combined` alias.
- Learned-buff tests cover OOC persistence, secret/malformed rejection, reclassification, combat blocking, and clearing.
- Custom scan tests assert that one helpful custom frame retains static, short, and long per-entry timer classes.
- Before deleting cancellation branches, add a focused custom-frame cancellation regression so preset removal cannot silently remove the supported custom path.
- Rewrite generic layout tests that construct `show_long` to use a custom frame or neutral test shell before deleting Long defaults.
- Add a CDM regression proving its viewer scan does not require `unified_scan()` before removing shared preset scanning.


## Cleanup Acceptance
- No `show_static`, `show_long`, `move_static`, `move_long`, or preset position/profile keys remain.
- Frames tree exposes Short Buffs, Static / Long Buffs, Timed Buffs, Debuffs, CDM presets, and custom frames only.
- `static` and `long` remain only where they describe custom Aura entry timer behavior or historical documentation.
- Impact-selected tests, smoke load, LuaLS/Ketho, and the in-game managed combat/reload matrix pass after an Aura Frames reset.
