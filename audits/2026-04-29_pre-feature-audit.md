# LsTweeks Pre-Feature Audit Report
*2026-04-29*

---

## 1. Structure & Architecture — PASS

All 26 files have the 2-sentence header comment and `local addon_name, addon = ...`. Module pattern is consistent. No internal-reaching detected. `af_defaults.lua` is the single source of truth for aura frame defaults.

---

## 2. Compute Efficiency — MIXED (several issues)

### Caching & Hoisting — FAIL (minor)
- `modules/aura_frames/af_core.lua` ~line 58 — `C_UnitAuras.GetAuraDuration()` called inside the icon tick loop. Must stay live (bars freeze without it per CLAUDE.md), but the global itself should be a cached local: `local GetAuraDuration = C_UnitAuras.GetAuraDuration`
- `modules/aura_frames/af_render.lua` ~line 249 — same pattern

### Loop Complexity — FAIL (one real concern)
- `modules/aura_frames/af_render.lua:183–199` — **O(n×m)** nested loop: outer iterates `sorted_ids`, inner iterates `aura_map` by key to find matches. A pre-keyed lookup table on `aura_map` would reduce to O(n).
- All other loops are O(n) or one-time UI build loops — not concerns.

### Table construction in loops — FAIL
- `modules/aura_frames/af_render.lua:180` — `local list = {}` created inside `render_aura_map()` which runs per update. Should be a module-level scratch table cleared with `wipe()`.
- `modules/aura_frames/af_scan.lua:93` — `local by_key = {}` inside `build_added_by_key()` helper, called per scan. Same fix applies.

### String concatenation in loops — FAIL
- `modules/aura_frames/af_scan.lua:85` — `make_order_key()` builds a string with `..` on every call, called inside scan loops (~line 289, 400). Keys rebuilt from scratch each scan — could be cached by instance ID.
- `modules/aura_frames/af_render.lua:211` — `"iid:" .. tostring(entry.instance_id)` inside short-frame ordering loop. Pre-build these keys when the entry is created.
- `modules/aura_frames/af_gui.lua:257` — `id .. "_custom"` in tree rebuild loop. Minor; runs only on UI interaction, not a tick.

### CreateFrame in non-init loops — FAIL (context-dependent)
- `modules/aura_frames/af_gui.lua:265–356` — `rebuild_tree()` calls `CreateFrame` ~5 times per custom frame entry on every expand/collapse. Should pool or lazily build+hide nodes instead.
- `modules/aura_frames/af_gui_custom.lua:490` — whitelist rebuild loop calls `CreateFrame` per spell entry. Low frequency (only on whitelist change), but could accumulate frames over time without cleanup verification.

### Redundant passes — FAIL (minor)
- `modules/aura_frames/af_render.lua:208 + 224` — two passes over related data per render: one to populate `_short_order_map`, one to clean stale keys. Could be merged into one pass.
- `modules/aura_frames/af_scan.lua:173` — `old_map` iterated to build `old_cat_by_spell` on every scan. Could be maintained incrementally rather than rebuilt from scratch.

---

## 3. Code Cleanliness — PASS

All `print()` calls are user-facing (warnings, confirmations, errors) — acceptable. No dead code blocks. No debug-only output left in silent paths.

---

## 4. Pre-Feature Scope — N/A
*(Applies when scoping a new feature, not during a general audit.)*

---

## Priority Work List

| # | Priority | Status | Issue | Location |
|---|---|---|---|---|
| 1 | ~~High~~ | FALSE POSITIVE | ~~O(n×m) nested loop~~ — lines 183–194 are two sequential O(n) loops with O(1) hash lookup; already correct | `af_render.lua:183` |
| 2 | **High** | [x] DONE | `list/seen/seen_keys = {}` allocated per render call — replaced with module-level scratch tables + wipe() | `af_render.lua:180,182,207` |
| 3 | ~~Medium~~ | FALSE POSITIVE | ~~`C_UnitAuras` not cached~~ — already a file-top local at line 13; af_core.lua line 58 is also fine | `af_render.lua:13` |
| 4 | **Medium** | [ ] | `make_order_key()` string concat rebuilt every scan loop — cache by instance ID | `af_scan.lua:85` |
| 5 | **Medium** | [ ] | `"iid:" ..` string concat in render loop — pre-build keys on entry creation | `af_render.lua:211` |
| 6 | **Medium** | [ ] | `build_added_by_key` allocates `{}` per scan — module-level scratch + wipe() | `af_scan.lua:93` |
| 7 | **Low** | [ ] | `rebuild_tree()` calls CreateFrame on every expand — pool or lazy-build nodes | `af_gui.lua:265` |
| 8 | **Low** | [ ] | Two passes over short-order data per render — merge into one pass | `af_render.lua:208` |
