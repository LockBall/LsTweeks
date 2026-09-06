# Aura Frames Font Picker Rework
Active handoff for replacing the addon font-control pattern with the first compact progressive-disclosure picker before further Shared BG Colors layout work. Fonts are the proving case for a reusable launcher/popup pattern that can later hide other dense groups of related settings until the user chooses to edit them.


## Table of Contents
- [1. Outcome And Boundaries](#1-outcome-and-boundaries)
- [2. Confirmed Current State](#2-confirmed-current-state)
- [3. Shared Factory Contract](#3-shared-factory-contract)
- [4. Progressive Disclosure Reuse Seam](#4-progressive-disclosure-reuse-seam)
- [5. Consolidation And Optimization](#5-consolidation-and-optimization)
- [6. Aura Frames Migration Map](#6-aura-frames-migration-map)
- [7. Concrete Change Map](#7-concrete-change-map)
- [8. Implementation Order](#8-implementation-order)
- [9. Verification And Documentation](#9-verification-and-documentation)


## 1. Outcome And Boundaries
- [ ] **a** Create one addon-wide `CreateFontPicker()` launcher/popup factory as the first progressive-disclosure control; do not add an Aura-only popup or leave two competing user-facing font systems.
- [ ] **b** Migrate every current Aura Frames font-family control in the same work batch: Shared Bar/Timer, per-frame Timer, and per-frame Stack.
- [ ] **c** Expose the existing per-frame Bar Font value through the compact picker. The DB/profile field already exists but currently has no local frame-panel control.
- [ ] **d** Preserve all existing SavedVariables and profile keys. This is a UI/control-ownership rework, not a data migration or runtime typography redesign.
- [ ] **e** Keep text colors in `CreateColorPicker()` and keep font application role-aware through the shared font catalog.
- [ ] **f** Reduce at-rest settings density: frame panels show one compact, state-readable launcher per font role; Size, Bold, Outline, Reset, and contextual actions appear only while that launcher is open.
- [ ] **g** Make launcher presentation, popup/session lifecycle, and font-specific content separate responsibilities so later dense setting groups can reuse the proven interaction without copying font logic.
- [ ] **h** Do not generalize Blizzard `ColorPickerFrame` and addon-owned progressive-disclosure popups into one framework; native and addon popup ownership/lifecycle constraints differ.
- [ ] **i** Implement and validate fonts before exporting a generic multi-option popup factory. A second real consumer defines the variation points and triggers extraction; the font pass must leave a clean internal seam rather than speculate about an arbitrary settings schema.


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
- [ ] **a** Keep catalog/style resolution in `font_catalog.lua`; put font launcher, popup, binding, and session ownership in a focused shared helper such as `functions/font_picker.lua`, loaded after dropdown and font catalog support. Within that helper, keep generic shell/session code independent from font row construction even if both remain file-local initially.
- [ ] **b** Create one addon-owned popup lazily and rebind it for each launcher. Never allocate a complete popup control set per frame or attach font-picker state to Blizzard frames.
- [ ] **c** The compact launcher shows its label, the selected font name, and a font-styled preview. It exposes container-level `GetValue()`, `SetValue()` or `Refresh()`, and `SetEnabled()` behavior consistent with other shared controls.
- [ ] **d** Accept role plus dynamic bindings for required Font and optional Size, Bold, and Outline values. Each binding supplies current-value read, write, and default-value read behavior; a contextual action supplies label plus callback. Presence of a binding, not its current UI eligibility, determines whether it participates in snapshot/reset/restore.
- [ ] **e** Keep persistence and preview separate: the factory writes through the active binding, then requests one coalesced caller preview. Multi-field Reset/Cancel restore all values first and request only one preview so Aura callers do not rebuild once per field.
- [ ] **f** Snapshot every present binding on open. Font edits preview live; Cancel, Escape/outside dismissal, parent hide, disable, and replacement by another launcher restore the snapshot, while Save commits the already-written values and closes.
- [ ] **g** Reset uses caller-provided defaults for every present field, remains part of the open transaction, and can still be undone by Cancel. Do not hard-code Game Default because current Aura defaults are independently owned and may be Source Code Pro.
- [ ] **h** Opening the already-active launcher refreshes from its live bindings without replacing its original snapshot. Opening a different launcher first rolls back and fully detaches the old session, then snapshots and binds the new consumer.
- [ ] **i** When the selected definition has no registered bold face, disable and grey Bold without discarding, resetting, or omitting the saved preference. Switching back to a capable family restores eligibility and the preserved value.
- [ ] **j** A contextual action such as `Apply to All Frames` commits the active selection, invokes the caller action exactly once, and closes. It must clear the transaction before invoking module code so a callback-triggered hide or refresh cannot roll the committed values back.
- [ ] **k** Every terminal path cancels pending preview work and clears callbacks/bindings. Profile/reset code closes the active session before replacing or repopulating DB tables, then refreshes launchers against the new state; no old snapshot may be written into the replacement DB.
- [ ] **l** `SetEnabled(false)` closes an active session before disabling the launcher. Hiding an inactive launcher has no effect on whichever other launcher owns the popup.
- [ ] **m** Coalesce live preview callbacks at the shared tenth-second interval unless a caller proves its update is cheap enough for the established immediate-preview contract. Save flushes the latest pending preview before close; rollback paths cancel pending work and issue one restored-state preview.


## 4. Progressive Disclosure Reuse Seam
- [ ] **a** The reusable interaction is **summary launcher -> focused popup -> explicit Save/Cancel**. A closed launcher must communicate the current state well enough that users do not need to open it merely to identify what is configured.
- [ ] **b** Treat launcher state/display, owned-popup framing and placement, exclusive session lifecycle, transaction cleanup, and terminal close semantics as domain-neutral responsibilities. They must not inspect font keys, roles, bold eligibility, or Aura DB tables.
- [ ] **c** Treat popup rows, field bindings/defaults, eligibility rules, preview rendering, summary text, contextual actions, and runtime refresh policy as domain-owned responsibilities. Font behavior must enter the shell through these seams rather than through font conditionals embedded in lifecycle code.
- [ ] **d** Keep Save, Cancel, replacement, dismissal, and stale-callback behavior consistent across future progressive-disclosure controls. Allow each domain to vary launcher summary, popup dimensions, row composition, control types, validation/eligibility, preview cadence, and contextual actions.
- [ ] **e** Build popup content once per picker type and rebind it between launchers. Do not require every future launcher instance to allocate its hidden sub-controls, and do not require unrelated picker types to share one physical popup when their content/lifecycle differs.
- [ ] **f** Keep the first public surface font-specific. Organize the implementation around small internal operations such as shell creation, session bind/unbind, transaction finish, content refresh, and font-row construction so the second consumer can extract only proven common behavior.
- [ ] **g** When a second dense setting group is selected, compare its real needs against the font picker before extraction. Promote only shared lifecycle/presentation behavior into a generic factory; leave domain layout, bindings, validation, and previews in adapters/builders owned by each setting group.
- [ ] **h** Do not build a universal form-description language, recursively generated settings UI, or generic DB writer as part of the font work. Those abstractions would hide module ownership and make specialized behavior harder to reason about.
- [ ] **i** Future candidate selection is separate follow-up work. Prefer a visibly dense cluster with multiple related controls, a concise closed-state summary, and a clear transactional edit boundary; do not migrate isolated controls merely for consistency.


## 5. Consolidation And Optimization
- [ ] **a** Replace UI-specific `GetFontDropdownOptions()` ownership with generic font options plus one style resolver used by runtime application, dropdown rows, launcher text, and popup preview. Unknown-key fallback and role-aware Game Default must resolve identically everywhere.
- [ ] **b** Retain `CreateFontDropdown()` only as a low-level selector used inside the popup if useful; no module should directly compose its own user-facing font cluster after migration.
- [ ] **c** Replace duplicated Timer/Stack family-size-bold-outline construction with one binding-driven Aura helper. Timer Text enablement and Timer/Stack colors remain separate feature controls.
- [ ] **d** Replace individual dropdown/slider/checkbox synchronization loops and `*_bold_refresh_*` control keys with the picker container's single refresh contract or a small font-picker registry.
- [ ] **e** Remove detached Shared `Apply All` controls and their control keys after the contextual popup action has equivalent regression coverage.
- [ ] **f** Scope runtime work by intent: local picker changes refresh only that frame/category; shared live selection refreshes participating frames; one-shot Apply to All performs one complete refresh after copying values.
- [ ] **g** Reusing one popup should remove most per-category font sliders, Bold/Outline widgets, dropdown popups, and callback closures. Keep only compact launchers plus the singleton popup controls.
- [ ] **h** Preserve the existing renderer functions and DB resolution unless the shared style resolver can replace demonstrably duplicated resolution without changing output.


## 6. Aura Frames Migration Map
- [ ] **a** Shared Bar Font: family only, role `body`, plus contextual `Apply to All Frames`; no shared size/Bold/Outline semantics are added.
- [ ] **b** Shared Timer Font: family only, role `timer`, plus contextual `Apply to All Frames`; participation remains paired with Bar Font under the existing Text Font matrix checkbox.
- [ ] **c** Local Bar Font: family only, role `body`, existing fixed size 10; place the compact launcher with the Bar Text presentation controls without expanding the frame grid solely for this setting.
- [ ] **d** Local Timer Font: family, size, Bold, and Outline, role `timer`; preserve current ranges, half-step sizes, defaults, test-aura preview, and managed/addon-rendered output.
- [ ] **e** Local Stack Font: family, size, Bold, and Outline, role `stack`; preserve current ranges, defaults, and native/addon-rendered stack output.
- [ ] **f** Built-in and custom frames use the same picker-building path and their existing dynamic DB/default bindings. Do not capture a DB table that profile/reset can replace.


## 7. Concrete Change Map
- [ ] **a** `functions/font_catalog.lua`: expose one role-aware option/style resolution path for runtime application, dropdown rows, launcher text, and popup preview. Keep font definitions and unknown-key fallback here.
- [ ] **b** `functions/font_picker.lua` plus `LsTweeks.toc`: add the font singleton popup/session factory and load it immediately after `font_catalog.lua`, when button, checkbox, slider, dropdown, and catalog support already exist. Keep shell/session helpers and font-content construction visibly separated by functions/regions so later extraction does not require untangling them.
- [ ] **c** `af_defaults.lua`: keep saved/default font fields and sharing participation unchanged; remove detached Apply All control-key metadata only after contextual actions own that behavior.
- [ ] **d** `af_gui_shared_bg_colors.lua`: replace the two shared dropdown/button pairs with family-only launchers whose contextual callbacks route once through `M.apply_shared_font_to_all()`.
- [ ] **e** `af_gui_frame_builders.lua`: add one Aura binding adapter used by Local Bar, Timer, and Stack launchers. Stack Local Bar below Bar Text Color in the existing presentation cell unless in-game layout proves that placement unreadable; do not add a grid column or row solely for it.
- [ ] **f** `af_gui.lua`: close the active picker before profile/reset state replacement and replace per-widget font synchronization with launcher refresh. Preserve non-font checkbox, color-picker, and layout synchronization.
- [ ] **g** `af_logic_main.lua` and `af_main.lua`: keep sharing resolution and renderers stable. Add or narrow a refresh entry point only if the existing panel `update()` callbacks cannot refresh the selected built-in/custom frame without `M.apply_number_font_to_all()`.
- [ ] **h** `test_control_factories.lua`: load the new helper explicitly and own transaction/session tests. Extend the WoW stub only for UI methods actually exercised by the singleton popup.
- [ ] **i** `test_af_color_sync.lua`: migrate assertions from dropdown internals and detached Apply All buttons to the launcher API and contextual action. Keep existing shared-selection, participation, custom-frame, and profile-restore coverage.
- [ ] **j** `test_af_managed_styling_growth.lua` and `test_profiles.lua`: retain renderer/schema assertions; add Local Bar launcher coverage without coupling runtime tests to popup internals.


## 8. Implementation Order
- [ ] **a** Add failing shared-factory tests for singleton rebinding, transactional Cancel/Save, defaults, optional controls, bold eligibility, stale-callback cleanup, and contextual action commit semantics.
- [ ] **b** Include explicit lifecycle cases for same-launcher reopen, different-launcher replacement, external hide/disable, pending-preview Save/Cancel, profile/reset close-before-replace, and a contextual callback that hides or refreshes its caller.
- [ ] **c** Consolidate catalog option/style resolution and implement the shared picker factory with the smallest stub additions needed by those tests.
- [ ] **d** Migrate Shared BG Colors first and retain focused tests for independent Bar/Timer Apply to All behavior and unchanged sharing participation.
- [ ] **e** Migrate the common per-frame Timer and Stack controls, add Local Bar Font, then remove the superseded builders, control keys, and reset/profile synchronization branches.
- [ ] **f** Audit every `CreateFontDropdown`, font control key, `IsFontBoldAvailable`, `apply_number_font_to_all`, and profile/reset caller before declaring the old path unused.
- [ ] **g** Run impact-selected validation once after the final behavior edit; use targeted red-to-green suites during implementation and avoid repeating the same suite in closeout.
- [ ] **h** After font acceptance, record which shell seams were actually exercised and leave selection of the second progressive-disclosure consumer as a new focused review; do not expand this implementation batch into another settings migration.


## 9. Verification And Documentation
- [ ] **a** Extend `test_control_factories.lua` for the shared picker API and popup lifecycle.
- [ ] **b** Update Aura coverage in `test_af_color_sync.lua`; retain shared selection, participation, Apply to All isolation, profile restore, and custom-frame assertions through the new launcher API.
- [ ] **c** Retain runtime typography coverage in `test_af_managed_styling_growth.lua` and profile field coverage in `test_profiles.lua`; add a local Bar Font UI assertion.
- [ ] **d** Run changed-file LuaLS/Ketho and fast non-duplicate validation. No patch-sensitive WoW API work is expected; refresh the live source only if implementation evidence crosses that boundary.
- [ ] **e** In game, verify compact alignment in Shared BG Colors and every frame-panel type; popup clamping and strata; role-correct launcher/popup previews; live Test Aura updates; Save, Cancel, Escape/outside dismissal, Reset, launcher replacement, and Apply to All; profile/reset while open; Bold eligibility; and no stale launcher writes.
- [ ] **f** After acceptance, update `proj_mem/functions/controls.md` with both the font contract and the proven progressive-disclosure seam, Aura Frames `## GUI`, applicable test documentation, source responsibility headers/regions, and public Aura Frames documentation if the visible settings workflow warrants it.
- [ ] **g** Remove this handoff after every active item is complete and the durable factory/module contracts have been promoted to their owning memory files.
