## Remaining Work

# Aura Frames Module — Scan Report
*Generated: 2026-05-07 | Files: 13 | Total lines: ~5,850*
*Updated: 2026-05-08 | Completed dead-code cleanup and removed obsolete aura-learning remnants*

---

## 4. Structural / Maintainability Issues

### 4e. `af_render.lua` — `render_aura_map` is ~240 lines with deeply nested timer/bar logic
The non-static timer block (lines 449–536) contains 4–5 nested `if`/`elseif` branches where bar-mode and show-timer-text cross-cut. The block has grown organically and is difficult to follow. Splitting out a `set_obj_timer_and_bar(obj, entry, remaining, live_remaining, live_duration, cooldown_duration, ...)` helper would make the main loop readable.

---

## 5. Summary Table

| # | File | Type | Severity |
|---|------|------|----------|
| 4e | `af_render.lua` | Structural — 240-line render function, deep nesting | Medium |

**Medium-priority items (worth fixing soon):** 4e  
**Low-priority items (clean-up pass):** everything else  
No correctness bugs were found; all issues are quality/maintainability.


### Nice To Have

- [ ] Brief guided tour.
- [ ] Portrait dim out of combat.
- [ ] Dungeon ready sound levels.
- [ ] Saves.
