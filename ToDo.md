## Let's Do It !

Use one extraction at a time, with reload / in-game testing after each meaningful step.

### 1. `af_main.lua` — modularize frame construction and lifecycle first

Recommended sub-step order:

- [x] a) Extract or regroup tooltip helpers if needed; this is already mostly isolated and low risk.
- [x] b) Extract icon pool creation from `M.create_aura_frame()`.
- [x] c) Extract title bar creation and resizer setup from `M.create_aura_frame()`.
- [x] d) Extract event registration and event-handler binding from `M.create_aura_frame()`.
- [x] e) Extract startup bootstrap chunks from the `ADDON_LOADED` handler.
- [x] f) Extract reset recovery chunks from `M.on_reset_complete()`.

Goal: make `M.create_aura_frame()`, startup, and reset read as orchestrators that call focused helpers.

### 2. `af_gui_frame_builders.lua` — clarify settings-panel builder flow

- [x] a) Review `build_frame_settings_panel()` for helper boundaries and source-specific hooks.
- [ ] b) Keep preset/custom presentation controls shared through normalized frame configs.
- [ ] c) Preserve the current visible GUI unless a specific cleanup requires a tested layout change.

### 3. `af_scan.lua` — defer until safer orchestration files are clean

- [ ] a) Review only after `af_main.lua` and `af_gui_frame_builders.lua`.
- [ ] b) Be conservative: scan logic handles combat-safe aura reads, secret values, CDM hooks, cache behavior, and classification.
- [ ] c) Prefer small isolated extractions with direct in-game validation.


### Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
- [ ] c) Dungeon ready sound levels.
- [ ] d) frame layout Saves.
 
