# Aura Frames Font Picker Rework
Active handoff for replacing the addon font-control pattern with one shared picker factory before further Shared BG Colors layout work.


## Table of Contents
- [1. Outcome And Boundaries](#1-outcome-and-boundaries)
- [2. Confirmed Current State](#2-confirmed-current-state)
- [3. Shared Factory Contract](#3-shared-factory-contract)
- [4. Consolidation And Optimization](#4-consolidation-and-optimization)
- [5. Aura Frames Migration Map](#5-aura-frames-migration-map)
- [6. Implementation Order](#6-implementation-order)
- [7. Verification And Documentation](#7-verification-and-documentation)


## 1. Outcome And Boundaries
- [ ] **a** Create one addon-wide `CreateFontPicker()` launcher/popup factory; do not add an Aura-only popup or leave two competing user-facing font systems.
- [ ] **b** Migrate every current Aura Frames font-family control in the same work batch: Shared Bar/Timer, per-frame Timer, and per-frame Stack.
- [ ] **c** Expose the existing per-frame Bar Font value through the compact picker. The DB/profile field already exists but currently has no local frame-panel control.
- [ ] **d** Preserve all existing SavedVariables and profile keys. This is a UI/control-ownership rework, not a data migration or runtime typography redesign.
- [ ] **e** Keep text colors in `CreateColorPicker()` and keep font application role-aware through the shared font catalog.
- [ ] **f** Do not generalize ColorPickerFrame and the addon-owned font popup into a generic popup framework during this work; their ownership and lifecycle constraints differ.


## 2. Confirmed Current State
- [ ] **a** `functions/font_catalog.lua` owns font definitions, semantic `body`/`timer`/`stack` Game Defaults, bold-face availability, dropdown preview options, and `ApplySelectedFont()`.
- [ ] **b** The catalog currently offers Source Code Pro and role-aware Game Default. Runtime font application preserves fractional sizes and composes Outline independently.
- [ ] **c** `CreateFontDropdown()` is the current user-facing family selector. Repository search found its module consumers only in Aura Frames plus shared-factory tests.
- [ ] **d** Per-frame Timer UI separately creates family, size, Bold, and Outline controls. Per-frame Stack UI independently duplicates the same pattern.
- [ ] **e** Bar text uses `bar_text_font` with the `body` role and a fixed runtime size of 10. Built-in and custom defaults/profile schemas already retain the field, but frame panels expose only Bar Text Color.
- [ ] **f** Shared BG Colors exposes Bar Font and Timer Font dropdowns with detached `Apply All` buttons. Each action copies only that selected family to built-in and custom local frame values without enabling live sharing.
- [ ] **g** `af_gui.lua` manually synchronizes Timer/Stack dropdowns, size sliders, checkboxes, and Stack bold-availability callbacks after reset/profile changes.
- [ ] **h** Local font callbacks currently call broad `M.apply_number_font_to_all()` and then update the current frame. The rework must avoid retaining unnecessary all-frame work for a local edit.


## 3. Shared Factory Contract
- [ ] **a** Keep catalog/style resolution in `font_catalog.lua`; put launcher, popup, binding, and session ownership in a focused shared helper such as `functions/font_picker.lua`, loaded after dropdown and font catalog support.
- [ ] **b** Create one addon-owned popup lazily and rebind it for each launcher. Never allocate a complete popup control set per frame or attach font-picker state to Blizzard frames.
- [ ] **c** The compact launcher shows its label, the selected font name, and a font-styled preview. It exposes container-level `GetValue()`, `SetValue()` or `Refresh()`, and `SetEnabled()` behavior consistent with other shared controls.
- [ ] **d** Accept role plus dynamic get/set/default bindings. Optional Size, Bold, Outline, and contextual-action bindings determine which popup rows appear; callers must not implement popup internals.
- [ ] **e** Snapshot every enabled binding on open. Font edits preview live; Cancel and replacement by another launcher restore the snapshot, while Save commits and closes.
- [ ] **f** Reset uses caller-provided defaults for every enabled field. Do not hard-code Game Default because current Aura defaults are independently owned and may be Source Code Pro.
- [ ] **g** When the selected definition has no registered bold face, disable and grey Bold without discarding the saved preference. Switching back to a capable family restores eligibility and the preserved value.
- [ ] **h** A contextual action such as `Apply to All Frames` commits the active selection, invokes the caller action exactly once, and closes. It must not later be undone by a stale Cancel path.
- [ ] **i** Closing, hiding, disabling, or rebinding an active launcher clears callbacks and bindings so later popup input cannot write the previous consumer. Profile/reset DB replacement must close or safely refresh an active session first.
- [ ] **j** Coalesce live preview callbacks at the shared tenth-second interval unless a caller proves its update is cheap enough for the established immediate-preview contract.


## 4. Consolidation And Optimization
- [ ] **a** Replace UI-specific `GetFontDropdownOptions()` ownership with generic font options plus one style resolver used by runtime application, dropdown rows, launcher text, and popup preview. Unknown-key fallback and role-aware Game Default must resolve identically everywhere.
- [ ] **b** Retain `CreateFontDropdown()` only as a low-level selector used inside the popup if useful; no module should directly compose its own user-facing font cluster after migration.
- [ ] **c** Replace duplicated Timer/Stack family-size-bold-outline construction with one binding-driven Aura helper. Timer Text enablement and Timer/Stack colors remain separate feature controls.
- [ ] **d** Replace individual dropdown/slider/checkbox synchronization loops and `*_bold_refresh_*` control keys with the picker container's single refresh contract or a small font-picker registry.
- [ ] **e** Remove detached Shared `Apply All` controls and their control keys after the contextual popup action has equivalent regression coverage.
- [ ] **f** Scope runtime work by intent: local picker changes refresh only that frame/category; shared live selection refreshes participating frames; one-shot Apply to All performs one complete refresh after copying values.
- [ ] **g** Reusing one popup should remove most per-category font sliders, Bold/Outline widgets, dropdown popups, and callback closures. Keep only compact launchers plus the singleton popup controls.
- [ ] **h** Preserve the existing renderer functions and DB resolution unless the shared style resolver can replace demonstrably duplicated resolution without changing output.


## 5. Aura Frames Migration Map
- [ ] **a** Shared Bar Font: family only, role `body`, plus contextual `Apply to All Frames`; no shared size/Bold/Outline semantics are added.
- [ ] **b** Shared Timer Font: family only, role `timer`, plus contextual `Apply to All Frames`; participation remains paired with Bar Font under the existing Text Font matrix checkbox.
- [ ] **c** Local Bar Font: family only, role `body`, existing fixed size 10; place the compact launcher with the Bar Text presentation controls without expanding the frame grid solely for this setting.
- [ ] **d** Local Timer Font: family, size, Bold, and Outline, role `timer`; preserve current ranges, half-step sizes, defaults, test-aura preview, and managed/addon-rendered output.
- [ ] **e** Local Stack Font: family, size, Bold, and Outline, role `stack`; preserve current ranges, defaults, and native/addon-rendered stack output.
- [ ] **f** Built-in and custom frames use the same picker-building path and their existing dynamic DB/default bindings. Do not capture a DB table that profile/reset can replace.


## 6. Implementation Order
- [ ] **a** Add failing shared-factory tests for singleton rebinding, transactional Cancel/Save, defaults, optional controls, bold eligibility, stale-callback cleanup, and contextual action commit semantics.
- [ ] **b** Consolidate catalog option/style resolution and implement the shared picker factory with the smallest stub additions needed by those tests.
- [ ] **c** Migrate Shared BG Colors first and retain focused tests for independent Bar/Timer Apply to All behavior and unchanged sharing participation.
- [ ] **d** Migrate the common per-frame Timer and Stack controls, add Local Bar Font, then remove the superseded builders, control keys, and reset/profile synchronization branches.
- [ ] **e** Audit every `CreateFontDropdown`, font control key, `IsFontBoldAvailable`, `apply_number_font_to_all`, and profile/reset caller before declaring the old path unused.
- [ ] **f** Run impact-selected validation once after the final behavior edit; use targeted red-to-green suites during implementation and avoid repeating the same suite in closeout.


## 7. Verification And Documentation
- [ ] **a** Extend `test_control_factories.lua` for the shared picker API and popup lifecycle.
- [ ] **b** Update Aura coverage in `test_af_color_sync.lua`; retain shared selection, participation, Apply to All isolation, profile restore, and custom-frame assertions through the new launcher API.
- [ ] **c** Retain runtime typography coverage in `test_af_managed_styling_growth.lua` and profile field coverage in `test_profiles.lua`; add a local Bar Font UI assertion.
- [ ] **d** Run changed-file LuaLS/Ketho and fast non-duplicate validation. No patch-sensitive WoW API work is expected; refresh the live source only if implementation evidence crosses that boundary.
- [ ] **e** In game, verify compact alignment in Shared BG Colors and every frame-panel type; popup clamping; role-correct previews; live Test Aura updates; Save, Cancel, Reset, and Apply to All; profile/reset while open; Bold eligibility; and no stale launcher writes.
- [ ] **f** After acceptance, update `proj_mem/functions/controls.md`, Aura Frames `## GUI`, applicable test documentation, source responsibility headers/regions, and public Aura Frames documentation if the visible settings workflow warrants it.
- [ ] **g** Remove this handoff after every active item is complete and the durable factory/module contracts have been promoted to their owning memory files.
