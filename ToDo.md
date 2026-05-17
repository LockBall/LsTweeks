## Let's Do It !

### 1. Ketho / LuaLS Manual Review

- [ ] a) Review `modules/aura_frames/af_gui_frame_builders.lua:647`: `enable_cb` is referenced inside the callback passed to `bound_cb()` in the same local declaration statement. Confirm whether Lua scoping makes this resolve as a global and whether behavior is affected.

- [ ] b) Review `modules/aura_frames/af_scan.lua:82`: `DurationObject:GetExpirationTime()` is not present in Ketho's DurationObject annotations. Compare against available methods such as `GetEndTime()`, `GetRemainingDuration()`, and `GetTotalDuration()`.

- [ ] c) Review `modules/aura_frames/af_scan.lua:446`: `CooldownViewerItemDataMixin.SetCooldownInfo` is not present in Ketho FrameXML annotations. Confirm whether this hook is obsolete, version-specific, or intentionally guarded fallback code.

- [ ] d) Review `modules/aura_frames/af_main.lua:315` and `modules/aura_frames/af_main.lua:325`: `CreateFontString()` is called with five arguments; Ketho annotations expect a maximum of four.

- [ ] e) Review `modules/aura_frames/af_core.lua:226`: legacy global `LoadAddOn` fallback is not recognized by Ketho; confirm whether keeping only `C_AddOns.LoadAddOn` is appropriate for the supported client.

### Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
