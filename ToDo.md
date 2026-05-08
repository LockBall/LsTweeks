## Remaining Work

### Aura Frames

- [ ] Verify CDM viewer ownership after enabled-root activity gating.

  Analysis:
  - `show/enabled` is now the root activity gate: disabled frames hide and return before move handles, test aura, scan, render, or CDM prep.
  - `M.get_frame_activity_state()` is the single runtime decision path for preset/custom activity and CDM data need.
  - `queue_wow_cooldown_refresh()` only prepares/clears CDM viewers whose addon frame is enabled.
  - `update_auras()` prepares a CDM viewer when that enabled CDM frame is being processed, so enabling a CDM frame after login can still populate live viewer data.
  - Still verify in game: startup with all CDM addon frames disabled, enabling one CDM frame, disabling it again, Sync to CDM, reset, and combat lockdown behavior.

- [ ] Consolidate remaining Aura Frames duplication.

  1. Preset/custom settings panels still duplicate control binding patterns.
     Checkbox binding and timer-font option building are shared now. Remaining duplication is mostly sliders, pickers, position controls, and panel-specific layout differences; consolidate only where behavior is identical.

### Nice To Have

- [ ] Brief guided tour.
- [ ] Portrait dim out of combat.
- [ ] Dungeon ready sound levels.
- [ ] Saves.
