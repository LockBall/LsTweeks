## Let's Do It !



### 1. aura_frames Performance Cleanup

- [x] a) Guard stable frame-shell setters in `update_auras()`.
  - Keep `update_auras()` as the single conductor; do not split aura-data and style/config pipelines yet.
  - Cache applied frame shell state so aura refreshes do not reapply unchanged scale, alpha, backdrop colors, title/resizer visibility, and frame size/position inputs.
  - Preserve combat and user-positioning guards. Geometry setters must still be skipped while in combat or while the user is dragging/resizing.
  - Expected win is fewer redundant WoW frame setters during normal aura churn, not a Big-O improvement.



### Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
- [ ] c) Dungeon ready sound levels.
