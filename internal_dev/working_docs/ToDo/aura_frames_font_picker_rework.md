# Aura Frames Text Options Acceptance

Implementation is complete for the Aura Frames Text Options popup rework. Durable contracts live in `proj_mem/functions/controls.md` and `proj_mem/modules/aura_frames.md`; this note retains only the remaining in-game acceptance work and deferred reuse decision.


## Table of Contents
- [Implemented](#implemented)
- [Remaining In-Game Acceptance](#remaining-in-game-acceptance)
- [Deferred Reuse Decision](#deferred-reuse-decision)


## Implemented
- [x] One addon-wide `CreateFontPicker()` path owns compact Bar, Timer, and Stack launchers plus a singleton transactional popup.
- [x] Every local and shared popup contains Text Color, Font, Font Size, Bold, and Outline; Save retains live edits, Cancel or dismissal restores the opening snapshot, and Reset previews caller-owned defaults.
- [x] Shared Bar and Timer styles include color, family, size, bold, and outline, with immediate participating-frame preview and profile/reset coverage.
- [x] Font catalog, runtime application, launcher preview, and popup-dropdown preview share role-aware Game Default resolution. Private preview FontObjects prevent Blizzard's native font colors from overriding the selected text color.
- [x] The Shared Options rename, compact grid layout, popup background factory, color-picker Save/Cancel/Reset footer, tests, public README, and durable project memory are updated.
- [x] Full automated validation passes all 28 headless suites plus syntax, region, memory-size, whitespace, and line-ending checks.


## Remaining In-Game Acceptance
- [ ] Verify Bar, Timer, and Stack launcher and popup-dropdown faces/colors against their selected values, including role-aware Game Default.
- [ ] Verify local and shared Color, Font, Size, Bold, and Outline preview on test and regular Auras, including enabling/disabling Shared Options participation.
- [ ] Verify Save, Cancel, Reset, launcher toggle/replacement, popup clamping, profile/reset while open, and disabled Bold behavior.
- [ ] Verify compact alignment and spacing in Shared Options, General, and every built-in/custom frame-panel variant.
- [ ] Remove this acceptance note after the remaining checks pass.


## Deferred Reuse Decision
- Keep `CreateFontPicker()` font-specific until a second dense settings group proves which popup/session seams are genuinely reusable.
- If that consumer appears, extract only shared launcher state, popup chrome/placement, exclusive session lifecycle, snapshot/restore, and terminal-button behavior. Keep field layout, bindings, eligibility, validation, and preview policy domain-owned.
