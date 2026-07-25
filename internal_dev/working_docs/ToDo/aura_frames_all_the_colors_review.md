# Aura Frames And All the Colors Review
Active review findings for `modules/aura_frames/` and `modules/all_the_colors/`. Work through each item with a focused regression test where marked, then remove or promote this note when nothing remains.

## Table of Contents
- [1. Documentation Follow-Up](#1-documentation-follow-up)
- [2. Debug Outline Allocation](#2-debug-outline-allocation)
- [3. Registry Update Contract](#3-registry-update-contract)
- [4. Preset Aura Map Fallback](#4-preset-aura-map-fallback)
- [5. Secret Debuffs](#5-secret-debuffs)
- [Review Evidence](#review-evidence)

## 1. Documentation Follow-Up
1. [x] Added a concise public README note for Aura Frames out-of-combat modifier-right-click cancellation. Internal module memory owns the complete safety contract.
- Change risk: low; documentation-only.

## 2. Debug Outline Allocation
2. [x] `af_debug_outlines.lua` now lazily creates four textures per slot only while enabled, then reuses and hides them across toggles.
- Change risk: low; developer-only control. Normal gameplay does not create, scan, update, or display debug outline regions.
- [not headless-testable: the current stub does not model persistent WoW region allocation; add a focused test only if the pool contract becomes nontrivial.]

## 3. Registry Update Contract
3. [ ] `atc_logic.lua` re-registration preserves most omitted consumer/target fields but clears `supports_ooc_fade` (line 113) and `supports_visibility` (line 157) whenever their options are omitted. Decide whether registration calls are replacement or patch semantics; current mixed behavior is surprising.
- Change risk: low. Preserve an existing capability unless the caller supplies that option explicitly.
- [headless-testable: register a fade-capable consumer and visibility-capable target, re-register each with only a label/order change, and assert the capabilities remain true.]

## 4. Preset Aura Map Fallback
4. [ ] `af_logic_main.lua` lines 592–604 wipes `self._aura_map` and then, when no derived category bucket exists, iterates that same wiped table. The intended fallback cannot copy matching entries from the master scan map, so the preset frame becomes empty on that path.
- Change risk: low to medium. Retain the usual scan/bucket fast path.
- [headless-testable: populate the master aura map with a matching preset entry, clear or omit `_aura_maps_by_category`, refresh the preset frame without a test preview, and assert the entry renders.]

## 5. Secret Debuffs
5. [ ] `af_scan.lua` can discard a newly observed debuff when its remaining time and `DoesAuraHaveExpirationTime()` result are unreadable and `unified_scan()` has no `UNIT_AURA` payload. Lines 1018–1025 set `belongs` false unless the entry was previously cached or appears in `added_lookup`; the stated rule is that debuffs always belong to the debuff frame.
- Change risk: medium. The implementation change is small but it affects a combat/secret-value fallback and needs targeted in-game confirmation.
- [headless-testable: start from an empty `M._aura_map`, provide one debuff with no timing fields, make `DoesAuraHaveExpirationTime()` return nil, call `unified_scan(nil, ...)`, and assert the entry is categorized `debuff`.]
- The current `test_af_ranges.lua` test uses the same aura ID for false, true, then nil results, so the nil iteration inherits the prior cached entry and does not exercise the failing fresh state.

## Review Evidence
- Targeted headless suites passed on 2026-07-25: `af_ranges` (37), `af_color_sync` (7), `af_native_visibility` (3), `atc` (8), `profiles` (7), and `smoke_load_all` (6).
- `check_fast.ps1 -Changed -SkipTests` passed syntax, regions, memory-section size, whitespace, and LF checks.
- No orphaned Aura Frames or All the Colors module files or TOC omissions were found. Aura Frames has legitimate complexity concentrations in `af_main.lua`, `af_scan.lua`, and `af_render.lua`; future splitting should follow subsystem boundaries rather than a mechanical line-count target.
