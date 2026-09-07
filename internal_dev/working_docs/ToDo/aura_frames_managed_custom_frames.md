# Aura Frames Managed Custom Frames
Implementation plan for moving Custom Filtered Frames from addon Aura scans to Blizzard-managed AuraContainers.


## Table of Contents
- [Goal And Current State](#goal-and-current-state)
- [Confirmed Constraints](#confirmed-constraints)
- [Implementation Plan](#implementation-plan)
- [Completion Gate](#completion-gate)


## Goal And Current State
- [ ] Preserve the existing Custom Filtered Frame experience while replacing addon-owned Aura membership scanning with managed AuraContainer groups.
- Custom frames currently expose only a base plus one predefined modifier, so arbitrary Lua predicates are already outside the UI contract.
- Aura membership still comes from `C_UnitAuras.GetAuraDataByIndex`; custom frames do not use the managed backend used by preset frames.
- The migration is valuable because Blizzard can select and update protected/secret Auras without the addon reading their identity or timing, especially in combat.


## Confirmed Constraints
- Current live-source baseline: WoW `12.1.0.69587`, Interface `120100`, source commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34` dated 2026-09-01. Refresh the live source before implementation if this baseline is stale.
- Managed groups accept validated `AuraUtil.AuraFilters` strings and narrowly defined `candidateFilters` for spell IDs, dispel types, maximum duration, processed Aura type, and documented boolean fields.
- The filter catalog uses current `!CANCELABLE`; the deprecated `NOT_CANCELABLE` spelling and old saved-field aliases are intentionally unsupported.
- Candidate filters are not required by the current base/modifier UI. Do not translate its choices into addon predicates or add candidate-filter machinery without an explicit supported rule.
- Managed preset durations have used Blizzard's default native formatter successfully through sustained use and live acceptance. Managed Custom Frames should use that same binding rather than recreate the legacy addon decimal/compact formatter.
- The project has one developer/user. Do not add versioned saved-data migration machinery; invalid saved selections may normalize to the default and be reselected.


## Implementation Plan
- [ ] **a — Freeze the behavior contract.** Add failing tests requiring a managed backend for custom frames and proving Aura membership no longer calls `C_UnitAuras.GetAuraDataByIndex`. Record current Bar/Icon layout, styling, Shared Options, Test Aura, profile/reset, and lifecycle behavior.
- [ ] **b — Centralize supported filters.** Make one canonical schema own base/modifier values, labels, allowed or forced bases, and managed mappings. Keep an independent required-filter test list and validate saved selections through the schema.
- [ ] **c — Validate semantics against live WoW.** Check every retained token with `AuraUtil.IsValidFilterString` and test meaningful base/modifier combinations rather than syntax alone. Decide whether obsolete or questionable choices such as `MAW` remain useful; add `DISPELLABLE` only if it fills a real need.
- [ ] **d — Preserve native timer behavior.** Use the same Blizzard-default `SetDurationText()` binding as managed preset frames. Verify readable short/long durations, hidden permanent-Aura timers, and secret-duration behavior without introducing an addon numeric formatter.
- [ ] **e — Generalize managed presentation creation.** Refactor the managed preset builder into a managed Aura-frame builder accepting a unique backend key, built-in/custom identity, flat or prefixed settings, filter string, candidate filters, and presentation metadata. Preserve immutable Bar and Icon groups and one shared presentation path.
- [ ] **f — Attach managed custom backends.** Create managed Bar and Icon groups for every custom frame using its validated filter string. Keep the addon shell responsible for position, movement, resizing, background, fade, Shared Options, and Test Aura placement.
- [ ] **g — Make filter changes lifecycle-safe.** Update both managed groups when Base or Modifier changes. Apply supported mutations outside combat and queue a last-value-wins update when blocked. Cancel pending work during deletion, profile/reset replacement, module disablement, and backend release; profile loading must recreate missing backends without stale registrations.
- [ ] **h — Verify presentation parity.** Test Bar/Icon switching, growth, width, spacing, fonts, colors, backgrounds, fades, Shared Options, Test Auras, and native managed tooltips. Retain guarded addon tooltip handling only where a native managed tooltip cannot own the interaction.
- [ ] **i — Retire obsolete scan state.** After parity passes, remove `scan_custom_aura_map`, the custom scan cache and invalidation, custom `UNIT_AURA` selection work, and ticker responsibilities replaced by native bindings. Confirm no remaining consumer needs the removed entry metadata. Unused addon sort settings and helpers were already removed; managed Custom Frames should use Blizzard's native default ordering unless a real user-facing requirement appears.
- [ ] **j — Complete validation.** Run focused red-to-green suites while implementing, then all headless suites, LuaLS/Ketho, stale-reference and dead-code scans, documentation checks, and package verification. In game, test every retained filter in and out of combat, filter changes during combat, reloads, creation/deletion, profiles/reset, and both presentation modes.


## Completion Gate
- Custom frames display and update through managed Bar and Icon groups while preserving their existing controls and appearance.
- Filter selection is limited to the canonical validated schema, with meaningful combinations confirmed against current live WoW.
- Blizzard's default native duration formatting remains readable and secret-safe for managed Custom Frames.
- Creation, deletion, filter changes, combat deferral, module lifecycle, profiles, reset, Shared Options, Test Auras, and tooltips pass automated and in-game acceptance.
- No custom-frame Aura membership path calls `C_UnitAuras.GetAuraDataByIndex`, and obsolete scan/cache/ticker state has been removed.
