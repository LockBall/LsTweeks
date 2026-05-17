## Let's Do It !

### 1. Ketho / LuaLS Follow-up Review

- [x] a) Resolved `modules/aura_frames/af_core.lua:162`: restructured `C_UnitAuras.GetAuraDuration()` `pcall` handling so failed calls do not assign `nil` into a variable LuaLS inferred as `DurationObject`. Timer fallback behavior is unchanged.
Commit: `Clean up aura duration pcall handling`.

- [x] b) Resolved `modules/aura_frames/af_functions.lua:47`: expanded guarded `GetCenter()` call so multi-return assignment is explicit and no longer depends on `and` short-circuit behavior.
Commit: `Clarify guarded GetCenter assignment`.

- [x] c) Resolved `modules/aura_frames/af_gui_tree.lua:250`, `359`, and `549`: moved tree group metadata from injected `FontString._group_key` fields into a local side table keyed by FontString.
Commit: `Store tree group metadata outside FontStrings`.

- [x] d) Resolved `modules/aura_frames/af_gui_tree.lua:179` and `548`: added `apply_tree_label_outline()` helper with `STANDARD_TEXT_FONT` fallback and replaced duplicated `SetFont(GetFont())` calls. Commit: `Add safe tree label font fallback`. Test: open `/lst` > Buffs & Debuffs > Frames and confirm tree labels render with outline in Buffs, WoW Cooldown, and Filters.

- [x] f) Resolved `modules/combat_text.lua:56`: removed the obsolete direct `PlayerFrame.HitIndicator` fallback and kept the current Retail `PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator` path confirmed by Ketho FrameXML. Commit: `Remove legacy HitIndicator fallback`. Test: enable "Disable portrait combat text," enter combat with a training dummy, and confirm damage/healing numbers no longer appear over the player portrait; then disable the setting and confirm they return.

- [ ] g) Review `modules/sound_levels/sl_gui.lua:131` and `165`: LuaLS cannot infer `MinimalSliderWithSteppersTemplate` mixin methods on the created slider. Determine whether this is an annotation limitation, a template/type mismatch, or needs a safer runtime guard.

## Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
