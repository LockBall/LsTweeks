## Let's Do It !

### 1. Ketho / LuaLS Manual Review

- [x] a) Resolved `modules/aura_frames/af_gui_frame_builders.lua:647`: `enable_cb` was referenced inside the callback passed to `bound_cb()` in the same local declaration statement. Declared `enable_container` and `enable_cb` before assignment so the callback captures the intended local.

- [x] b) Resolved `modules/aura_frames/af_scan.lua:82` and `modules/aura_frames/af_scan.lua:418`: replaced undocumented `DurationObject:GetExpirationTime()` calls with `DurationObject:GetEndTime()`, which is the current public API for absolute duration end time.

- [x] c) Resolved `modules/aura_frames/af_scan.lua:446`: removed dead guarded `CooldownViewerItemDataMixin.SetCooldownInfo` hook. Current FrameXML sets `cooldownInfo` through `SetCooldownID()` / `OnCooldownIDSet()`, and the existing `SetCooldownID` hook covers the refresh path.

- [ ] d) Review `modules/aura_frames/af_main.lua:315` and `modules/aura_frames/af_main.lua:325`: `CreateFontString()` is called with five arguments; Ketho annotations expect a maximum of four.

- [ ] e) Review `modules/aura_frames/af_core.lua:226`: legacy global `LoadAddOn` fallback is not recognized by Ketho; confirm whether keeping only `C_AddOns.LoadAddOn` is appropriate for the supported client.
---

## Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
