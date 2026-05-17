## Let's Do It !

### 1. Ketho / LuaLS Manual Review

- [x] a) Resolved `modules/aura_frames/af_gui_frame_builders.lua:647`: `enable_cb` was referenced inside the callback passed to `bound_cb()` in the same local declaration statement. Declared `enable_container` and `enable_cb` before assignment so the callback captures the intended local.

- [x] b) Resolved `modules/aura_frames/af_scan.lua:82` and `modules/aura_frames/af_scan.lua:418`: replaced undocumented `DurationObject:GetExpirationTime()` calls with `DurationObject:GetEndTime()`, which is the current public API for absolute duration end time.

- [x] c) Resolved `modules/aura_frames/af_scan.lua:446`: removed dead guarded `CooldownViewerItemDataMixin.SetCooldownInfo` hook. Current FrameXML sets `cooldownInfo` through `SetCooldownID()` / `OnCooldownIDSet()`, and the existing `SetCooldownID` hook covers the refresh path.

- [x] d) Resolved `modules/aura_frames/af_main.lua:315` and `modules/aura_frames/af_main.lua:325`: removed unsupported extra argument from `CreateFontString()` calls. Font sizing remains handled by existing font templates and timer font application code.

- [x] e) Resolved `modules/aura_frames/af_core.lua:226`: removed obsolete global `LoadAddOn` fallback. Supported WoW 12.0.5+ clients use `C_AddOns.LoadAddOn()`.

- [x] f) Resolved unnecessary global namespace pollution from addon-created frame names. Removed global names from dropdown internals, aura frame containers, grid overlay, and Sound Levels slider/tab controls; kept intentional globals for SavedVariables, slash command, libraries, and the main settings frame.

---


## Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
