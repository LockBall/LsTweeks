# Aura Frames Managed Custom Frames
Implementation plan for moving Custom Filtered Frames from addon Aura scans to Blizzard-managed AuraContainers.


## Table of Contents
- [Goal And Current State](#goal-and-current-state)
- [Confirmed Constraints](#confirmed-constraints)
- [Implementation Plan](#implementation-plan)
- [Completion Gate](#completion-gate)


## Goal And Current State
- [ ] Preserve compatible Custom Filtered Frame controls, layout, and styling while replacing addon-owned Aura membership scanning with managed AuraContainer groups. Accept native managed ordering, duration formatting, tooltip ownership, and cancellation transport instead of recreating their addon implementations.
- Custom frames currently expose only a base plus one predefined modifier, so arbitrary Lua predicates are already outside the UI contract.
- Aura membership still comes from `C_UnitAuras.GetAuraDataByIndex`; custom frames do not use the managed backend used by preset frames.
- The migration is valuable because Blizzard can select and update protected/secret Auras without the addon reading their identity or timing, especially in combat.


## Confirmed Constraints
- Current live-source baseline, refreshed 2026-09-08: WoW `12.1.0.69587`, Interface `120100`, source commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34` dated 2026-09-01. Refresh the live source before implementation if this baseline is stale.
- Managed groups accept validated `AuraUtil.AuraFilters` strings and narrowly defined `candidateFilters` for spell IDs, dispel types, maximum duration, processed Aura type, and documented boolean fields.
- Current `CustomAuraContainerMixin` updates an existing group through `SetAuraGroupFilterString(groupKey, filterString)`. Tests and fixtures must use that exact API name; `SetAuraGroupFilter` is not the current contract.
- The filter catalog uses current `!CANCELABLE`; the deprecated `NOT_CANCELABLE` spelling and old saved-field aliases are intentionally unsupported.
- Candidate filters are not required by the current base/modifier UI. Do not translate its choices into addon predicates or add candidate-filter machinery without an explicit supported rule.
- Managed preset durations have used Blizzard's default native formatter successfully through sustained use and live acceptance. Managed Custom Frames should use that same binding rather than recreate the legacy addon decimal/compact formatter.
- Managed `AuraButton` supports native right-click cancellation for cancelable helpful Auras. Preserve that user behavior through the native button contract, not the old scanned-entry cancellation helper.
- The project has one developer/user. Do not add versioned saved-data migration machinery; invalid saved selections may normalize to the default and be reselected.


## Implementation Plan
- [ ] **a — Freeze the behavior contract.** Add failing tests requiring a managed backend for custom frames, proving Aura membership no longer calls `C_UnitAuras.GetAuraDataByIndex`, and requiring native right-click cancellation for cancelable helpful Auras. Record current Bar/Icon layout, styling, Shared Options, Test Aura, profile/reset, and lifecycle behavior.
- [ ] **b — Centralize supported filters.** Make one canonical schema own base/modifier values, labels, allowed or forced bases, and managed mappings. Keep an independent required-filter test list and validate saved selections through the schema.
- [ ] **c — Validate semantics against live WoW.** Check every retained token with `AuraUtil.IsValidFilterString` and test meaningful base/modifier combinations rather than syntax alone. Decide whether obsolete or questionable choices such as `MAW` remain useful; add `DISPELLABLE` only if it fills a real need.
- [ ] **d — Preserve native timer behavior.** Use the same Blizzard-default `SetDurationText()` binding as managed preset frames. Verify readable short/long durations, hidden permanent-Aura timers, and secret-duration behavior without introducing an addon numeric formatter.
- [ ] **e — Establish neutral presentation ownership.** Extract shared managed Bar/Icon initialization, layout, chrome, and binding into a neutral `af_managed_presentation.lua` owner. Keep preset filter/backend policy in `af_managed_presets.lua`; do not make presets own the custom feature or introduce a broad compatibility dispatcher. Preserve immutable Bar and Icon groups and one shared presentation path.
- [ ] **f — Attach managed custom backends in construction order.** Add an `af_managed_custom.lua` owner for custom backend creation, filter updates, lifecycle, and release. Create its Bar and Icon groups with the validated filter string before event binding and pool decisions, so custom frames register no `UNIT_AURA` scan path and allocate only the single addon-owned Test Aura preview visual rather than a full Aura pool. Keep the shell responsible for position, movement, resizing, background, fade, Shared Options, and Test Aura placement.
- [ ] **g — Make filter changes and teardown lifecycle-safe.** Update both immutable groups through `SetAuraGroupFilterString` when Base or Modifier changes. Initially treat the mutation as out-of-combat-only and queue one last-value-wins update; do not probe safety with `pcall`. A focused in-game test may later prove a narrower direct-combat contract. Cancel pending work and release the backend before frame destruction during deletion, profile/reset replacement, module disablement, and relinking; profile loading must create or update exactly one backend without stale registrations.
- [ ] **h — Resolve interaction ownership and verify presentation parity.** Test Bar/Icon switching, growth, width, spacing, fonts, colors, backgrounds, fades, Shared Options, Test Auras, native right-click cancellation, and native managed tooltips. Do not retain an addon hover fallback. Before implementation, keep the custom `tooltip` setting only if the initialized managed buttons can honor it through a supported native mouse-motion contract; otherwise remove the setting directly, with no migration or silent compatibility field.
- [ ] **i — Retire obsolete scan and interaction state.** After parity passes, remove `scan_custom_aura_map`, the custom scan cache and invalidation, custom `UNIT_AURA` selection work, ticker responsibilities replaced by native bindings, and the scan-entry cancellation/tooltip paths. Rewrite or remove scan-only assertions in `test_af_scan_config.lua`, and confirm no remaining consumer needs the removed entry metadata. Unused addon sort settings and helpers were already removed; managed Custom Frames should use Blizzard's native default ordering unless a real user-facing requirement appears.
- [ ] **j — Complete validation.** Run focused red-to-green suites while implementing, then all headless suites, LuaLS/Ketho, stale-reference and dead-code scans, documentation checks, and package verification. In game, test every retained filter in and out of combat, filter changes during combat, reloads, creation/deletion, profiles/reset, and both presentation modes.


## Completion Gate
- Custom frames display and update through managed Bar and Icon groups while preserving their existing controls and appearance.
- Filter selection is limited to the canonical validated schema, with meaningful combinations confirmed against current live WoW.
- Blizzard's default native duration formatting remains readable and secret-safe for managed Custom Frames.
- The managed fixture exposes the exact current group APIs, and automated tests prove both immutable groups receive every validated filter update.
- Creation, deletion, filter changes, combat deferral, backend release, module lifecycle, profiles, reset, Shared Options, Test Auras, native cancellation, and the explicit tooltip decision pass automated and in-game acceptance.
- Custom frames register no `UNIT_AURA` scan path, allocate no full addon Aura pool, and make no Aura-membership call to `C_UnitAuras.GetAuraDataByIndex`; obsolete scan/cache/ticker/cancellation state has been removed.
