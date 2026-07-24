# Background Colors Module Memory
Durable ownership and runtime contracts for `modules/background_color_sync/`.


## Table of Contents
- [Settings And Defaults](#settings-and-defaults)
- [Resolution And Consumers](#resolution-and-consumers)
- [Presets And Controls](#presets-and-controls)
- [Profiles Reset And Lifecycle](#profiles-reset-and-lifecycle)


## Settings And Defaults
- Module key: `background_color_sync`; visible category: **Background Colors**.
- `bcs_defaults.lua` owns global policy defaults, registry state, and the ordered preset palette. Consumer defaults come from registration metadata.
- Registered consumer state persists under `background_color_sync.consumers.<module_key>` with global `global_enabled`, module `color`, and `targets.<target_key>`.
- Normalize global and registered consumer RGBA tables to 0–1 at startup and profile application.


## Resolution And Consumers
- `bcs_logic.lua` owns `M.resolve_color(module_key, target_key, local_color)` with precedence `global -> module -> local`. Non-global-only consumers implicitly use their module color for selected targets whenever their global color does not apply; there is no separate module-color enable toggle.
- Resolution returns the original local table when no override applies. Never copy an override into participating module settings.
- Color overrides replace RGBA only. Global `Enable All Backgrounds` operates independently from `Enable Global Color` and target color-participation selections; it makes every registered visibility-capable background visible through `M.resolve_visibility()` without rewriting consumer DB. Consumer-owned borders, opacity, combat rules, and rendering remain unchanged.
- Consumers register through `M.register_consumer(module_key, opts)` and `M.register_target(module_key, target_key, opts)`. Keys are stable SavedVariables/resolver identity; labels and row/column metadata are presentation.
- Fade-capable consumers register with `supports_ooc_fade = true` and resolve their saved local fade flag through `M.resolve_ooc_fade(module_key, local_enabled)`. Global `Disable OOC Fade` is effective only while `Enable All Backgrounds` is active and never rewrites consumer settings.
- Consumers registered with `global_toggle = true` expose a module participation checkbox as an indented child of `Enable Global Color`. `global_order` controls those checkbox positions; Objectives precedes Buffs & Debuffs.
- Consumers registered with `global_only = true` omit a separate module group, ignore hidden target-selection state, and bypass saved module-color overrides when global color does not apply. Objectives uses this mode so its own settings page exclusively owns local color customization.
- Buffs & Debuffs registers as fade-capable, so the global policy suppresses OOC fading across its built-in and custom frames.
- Registration is independent from local visibility. Built-in targets register at module load; dynamic targets register when created/loaded and unregister when deleted.
- Aura target keys are `frame:<category-or-custom-id>` and `bar:<category-or-custom-id>`. Each frame occupies one row with separate **Frame BG** and **Bar BG** checkboxes. Objectives registers `custom_background`.
- `M.refresh_consumers()` calls registered refresh closures. Background Colors owns no consumer frames, events, timers, or queued runtime work.


## Presets And Controls
- Preset order: Red, Orange, Yellow, Green, Blue, Indigo, Violet, Black, White, Grey.
- Presets replace RGB and preserve current alpha. Picker RGB values outside the preset tolerance display as **Custom**.
- The preset selector uses shared `CreateCyclingDropdown()`: Spellbook previous-page button, standard clickable dropdown with hover arrow, and Spellbook next-page button. Cycling wraps; right/left from **Custom** enters Red/Grey.
- The Colors tab is registry-driven and scrollable. It derives group sizing from `addon.main_frame:GetContentAreaSize()` and places controls through `CreateSettingsGrid()`; retain 20px left/right margins.
- Global enablement shadows and disables module override toggles/colors; target choices remain editable because they also select global participation.


## Profiles Reset And Lifecycle
- Profiles snapshot global policy plus the dynamic registered-consumer table. Loading uses defensive copies, preserves explicit `false`, normalizes colors, rebuilds dynamic controls, and refreshes consumers.
- General reset preserves profiles by default and restores policy/color defaults without touching any participating module's local colors.
- Soft module disable makes resolution return local colors and refreshes consumers immediately; re-enable normalizes DB and reapplies current policy.
