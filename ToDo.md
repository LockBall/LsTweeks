## Remaining Work

### Aura Frames

- [ ] CDM frames get turned on but not turned off when custom delete; adjust default behavior.

  Analysis:
  - Aura Frames reads live data from Blizzard Cooldown Manager viewer child frames for Essential, Utility, Tracked Buffs, and Tracked Bars.
  - Hidden Blizzard CDM viewers stop producing the child state we scan, so the addon currently keeps them active and uses alpha/mouse changes when the user wants them visually hidden.
  - The likely issue is lifecycle ownership: our code can `Show()` / prepare CDM viewers so addon CDM-backed frames can read them, but there is no clear rule for when to stop forcing that state after related addon frames are disabled/deleted.
  - Do not blindly call `Hide()` while any addon CDM-backed frame still needs live data.
  - Desired rule to define: if any CDM-backed addon frame is enabled, previewed, syncing, or otherwise needs the category, keep that Blizzard viewer active and apply the user hide/alpha setting; if no addon frame needs that category, restore or stop forcing that viewer.
  - First step should be read-only: trace calls to `prepare_blizz_cdm_viewer`, `update_blizz_cdm_visibility`, and `queue_wow_cooldown_refresh`, then decide whether the TODO wording about "custom delete" is still accurate or stale.

- [ ] Consolidate remaining Aura Frames duplication.

  1. [x] Frame/category metadata is still duplicated.
     Built-in category metadata now lives in `M.FRAME_DEFS`; `M.CATEGORIES`, `M.TIMER_CATEGORIES`, `M.CDM_CATEGORIES`, CDM viewer mappings, GUI category data, runtime frame creation, and test-aura labels are derived from it.

  2. [x] Default literals are still repeated.
     Aura Frames behavioral defaults now live in `af_defaults.lua` as named constants: frame width limits, default/max icons, short-threshold fallback, default timer font key, and CDM out-of-combat alpha.

  3. Preset/custom settings panels still duplicate control binding patterns.
     Checkbox binding and timer-font option building are shared now. Remaining duplication is mostly sliders, pickers, position controls, and panel-specific layout differences; consolidate only where behavior is identical.

  4. [x] Aura frame creation still uses raw prefixed keys.
     Built-in preset frame paths now use `M.get_preset_keys(category)` for `show_`, `move_`, `timer_`, `bg_`, `scale_`, and `spacing_` key construction.

  5. [x] Test aura metadata duplicates category knowledge.
     Test preview labels and sort IDs now come from `M.FRAME_DEFS`.

### Nice To Have

- [ ] Brief guided tour.
- [ ] Portrait dim out of combat.
- [ ] Dungeon ready sound levels.
- [ ] Saves.
