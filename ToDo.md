## Let's Do It !



### 1. aura_frames Performance Cleanup

- [x] a) Tick only displayed aura icons.
  - Store `frame._display_count` from `render_aura_map()` and have `tick_visible_icons()` loop only `1..frame._display_count`.
  - Expected shape: `O(total pooled icons)` -> `O(displayed icons)` on the tenth-second ticker.

- [ ] b) Build category buckets during unified scan.
  - Populate category-specific maps/lists while scanning instead of making each preset frame filter the full shared `M._aura_map`.
  - Expected shape: `O(enabled frames * total auras)` -> closer to `O(total auras + displayed category entries)`.

- [ ] c) Centralize sorted aura ID caches per update batch.
  - Cache `C_UnitAuras.GetUnitAuraInstanceIDs()` results by `HELPFUL/HARMFUL + sort_rule + sort_dir` for the current update batch instead of per frame.
  - Expected shape: `O(frames * sorted aura id fetch)` -> `O(unique sort requests)`.

- [ ] d) Avoid reapplying unchanged visual state during render.
  - Cache per-slot identity/style keys so stable icons skip redundant texture, color, text, cooldown, and visibility setters.
  - Mostly a constant-factor win, but relevant because WoW UI setters are not free.

- [ ] e) Separate aura-data dirty work from settings/style dirty work.
  - Extend existing layout caching with explicit dirty flags for style/config changes so aura events do not redo work that only changes from settings actions.
  - Expected win is fewer unnecessary setter/layout paths during normal aura churn.



### Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
- [ ] c) Dungeon ready sound levels.
