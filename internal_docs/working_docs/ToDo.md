## Let's Do It !

### Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually initiate.

### 1. skyriding_vigor

- [x] a) Add initial restored Vigor display module from scratch using Blizzard atlas assets.
- [ ] b) In-game verify charge spell fallback order on a Skyriding mount.
- [ ] c) In-game verify fade behavior when grounded with full vigor.

### 2. module disabled-state review

- [ ] a) Apply the disabled-options principle across non-Aura Frames modules: disabled features should unregister events/tickers, skip frame creation and refresh work, and do little to no runtime work until enabled.

### 3. aura_frames render-path cleanup

- [ ] a) Cache or pass timer behavior/category data so `set_timer_text()` does less repeated category normalization/lookup work.
- [ ] b) Add a cooldown overlay signature guard to reduce repeated `Show()` / `SetCooldown*` work.
- [ ] c) Guard bar `SetMinMaxValues()` writes while preserving live `SetValue()` progress updates.
- [ ] d) Cache count-text anchor signatures so bar-mode stack text does not repeatedly call `SetPoint()`.
- [ ] e) Reprofile with `/lstprofile report 40` and compare `render_aura_map`, `set_timer_text`, `get_timer_behavior`, and `normalize_timer_category`.
