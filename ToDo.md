## Let's Do It !

### 1. Ketho / LuaLS Follow-up Review

- [x] a) Resolved `modules/aura_frames/af_core.lua:162`: restructured `C_UnitAuras.GetAuraDuration()` `pcall` handling so failed calls do not assign `nil` into a variable LuaLS inferred as `DurationObject`. Timer fallback behavior is unchanged.
Commit: `Clean up aura duration pcall handling`.

- [x] b) Resolved `modules/aura_frames/af_functions.lua:47`: expanded guarded `GetCenter()` call so multi-return assignment is explicit and no longer depends on `and` short-circuit behavior.
Commit: `Clarify guarded GetCenter assignment`.

- [x] c) Resolved `modules/aura_frames/af_gui_tree.lua:250`, `359`, and `549`: moved tree group metadata from injected `FontString._group_key` fields into a local side table keyed by FontString.
Commit: `Store tree group metadata outside FontStrings`.

- [ ] d) Review `modules/aura_frames/af_gui_tree.lua:179` and `548`: `SetFont(row.cat_fs:GetFont(), ...)` may pass a nil font path according to LuaLS. Add a fallback font path if appropriate.

- [ ] e) Review `modules/aura_frames/af_main.lua:207`: Ketho/LuaLS does not expose `GameTooltip.SetUnitAuraByAuraInstanceID` on the tooltip type, though Blizzard FrameXML uses it. Confirm whether this is an annotation gap or a client-version concern.

- [ ] f) Review `modules/combat_text.lua:56`: `PlayerFrame.HitIndicator` is not present in Ketho's `PlayerFrame` type. Confirm whether this should stay as a guarded FrameXML field lookup or use a different access path.

- [ ] g) Review `modules/sound_levels/sl_gui.lua:131` and `165`: LuaLS cannot infer `MinimalSliderWithSteppersTemplate` mixin methods on the created slider. Determine whether this is an annotation limitation, a template/type mismatch, or needs a safer runtime guard.

## Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
