# Controls Function Memory
Durable contracts for shared buttons, checkboxes, sliders, color pickers, and dropdowns under `functions/`.


## Table of Contents
- [Scope And Ownership](#scope-and-ownership)
- [Container API Contract](#container-api-contract)
- [Callback And Synchronization Contract](#callback-and-synchronization-contract)
- [Control-Specific Rules](#control-specific-rules)
- [Validation](#validation)


## Scope And Ownership
- `buttons.lua`: text measurement/sizing, standard button fonts, text buttons, play/pause controls, and Move Reset buttons.
- `checkbox.lua`: checkbox container, checked/enabled state, silent synchronization, and checked-change hooks.
- `slider_with_box.lua`: DB-bound slider/edit-box/reset composition, callback scheduling, silent synchronization, and value-change hooks.
- `color_picker.lua`: DB-bound swatch/reset control plus the shared Blizzard `ColorPickerFrame` session, alpha input, preview, cancel, and cleanup behavior.
- `dropdown.lua`: styled dropdown button/popup/options, dynamic value access, hover arrow, and container state.
- `group_column.lua`, `module_reset.lua`, and `ui_helpers.lua` remain separately indexed shared composites; this file owns their underlying standard control contracts only when they consume these factories.


## Container API Contract
- Module control tables store the returned container and use its public API for routine state. Reach into inner widgets only for template-specific behavior not exposed by the factory.
- Checkbox containers expose `GetChecked()`, `SetChecked()`, `SetCheckedSilently()`, `SetEnabled()`, `Enable()`, `Disable()`, and `HookCheckedChanged()`.
- Slider containers expose `GetValue()`, `SetValue()`, `SetValueSilently()`, `SetEnabled()`, and `HookValueChanged()`. `container.slider` is an explicit escape hatch for specialized hooks, not the normal state API.
- Color-picker containers expose `GetValue()`, `SetValue()`, and `SetEnabled()`; dropdown containers expose `GetValue()`, `SetValue()`, and `SetEnabled()`.
- Factory internals anchor only inside their returned container. External placement belongs to the caller or `CreateSettingsGrid()`.


## Callback And Synchronization Contract
- Programmatic silent setters suppress callbacks only around the setter call, restore the previous suppression state through protected cleanup, and rethrow setter errors. A failed sync must not mute later user input.
- Hook helpers skip silent updates unless the caller explicitly requests `run_when_silent = true`.
- Slider callbacks debounce at `addon.UPDATE_INTERVALS.tenth_sec` by default. Use `opts.immediate_callback` only for inexpensive direct visual previews; it applies the first value immediately and throttles later drag values to the latest pending value. Do not use immediate mode for scans, reconstruction, or external API work.
- Callback-free sliders write their binding without scheduling empty timers. Hiding a slider container cancels pending debounce/live timers.
- When a module adds its own synchronization guard around shared controls, it must restore that guard on setter errors as well. Module-local guards and factory suppression solve different layers and may both be required.
- Dynamic value/provider closures must resolve mutable DB/runtime state at call time rather than capture a table that can be replaced or switched after UI construction.


## Control-Specific Rules
- Raw `UIPanelButtonTemplate` buttons use `addon.ApplyStandardButtonStyle()`. `CreateTextButton()`, Move Reset, dropdowns, sliders, color-picker reset, and Profiles-tab buttons already route through it.
- `CreatePlayPauseButton()` uses Blizzard play/pause art; `SetPaused()` swaps the offered action, while `show_pause = false` creates a play-only control. Asset details remain in `media_notes.md`.
- `CreateColorPicker()` owns the single live system-picker session. Clear prior swatch/opacity callbacks when a session closes, cancels, or hides so a later picker cannot write the previous control. Reset/cancel callbacks apply immediately; live previews are coalesced.
- Dropdown `cfg.get_value` initializes selection, `cfg.on_select` owns external writes, and `SetEnabled(false)` closes the popup and hover arrow. Hover-arrow art/rotation remains asset-owned in `media_notes.md`.
- A control with both a broad runtime lock and a narrower eligibility rule must reapply the composed gate during local synchronization; do not directly enable the inner widget and bypass another owner.


## Validation
- `test_control_factories.lua` owns silent-setter recovery, play/pause state, slider throttling, and callback-free timer regression coverage. Extend it when changing shared callback/container behavior.
- Color-picker and dropdown changes require targeted module tests where behavior is modelable plus in-game verification of popup lifecycle, cancel/reset, alpha, enabled state, and dynamic DB switching.
- Shared factory changes require an impact audit of every consumer named by changed-file test selection and `rg`; visual layout remains an in-game check.
