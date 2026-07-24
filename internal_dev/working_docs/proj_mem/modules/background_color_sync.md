# Background Colors Module Memory
Durable ownership and runtime contracts for `modules/background_color_sync/`.


## Table of Contents
- [Settings And Defaults](#settings-and-defaults)
- [Resolution And Consumers](#resolution-and-consumers)
- [Presets And Controls](#presets-and-controls)
- [Profiles Reset And Lifecycle](#profiles-reset-and-lifecycle)


## Settings And Defaults
- Module key: `background_color_sync`; visible category: **Background Colors**.
- `bcs_defaults.lua` owns global policy defaults, registry state, and the ordered global preset palette.
- Persisted consumer state is limited to `background_color_sync.consumers.<module_key>.global_enabled`; consumer modules own shared/local colors and target selections.
- Normalize only the global RGBA table here. `ensure_consumer_db()` deletes obsolete consumer `color` and `targets` fields.


## Resolution And Consumers
- `bcs_logic.lua` owns `M.resolve_color(module_key, target_key, local_color)` with precedence `global -> caller-owned input`. Consumer modules resolve any module-shared color before calling it.
- Resolution returns the caller's original input table when no global override applies and never copies global color into consumer settings.
- Global color replaces RGBA and makes visibility-capable backgrounds visible for checked modules. `Enable All Backgrounds` operates independently and makes every registered visibility-capable background visible even without global color. Neither path rewrites consumer DB; consumer-owned borders, opacity, combat rules, and rendering remain unchanged.
- Consumers register through `M.register_consumer(module_key, opts)` and `M.register_target(module_key, target_key, opts)`. Keys are stable resolver identity; labels, order, and capabilities are runtime metadata.
- Non-global-only targets expose consumer-owned participation through `get_enabled`; Background Colors does not persist or edit that state.
- Fade-capable consumers register with `supports_ooc_fade = true` and resolve their saved local fade flag through `M.resolve_ooc_fade(module_key, local_enabled)`. `M.get_disable_ooc_fade()`, `M.set_disable_ooc_fade()`, and `M.is_ooc_fade_disabled()` provide the single policy API used by Background Colors and linked consumer UI. Global `Disable OOC Fade` is independent, does not depend on `Enable All Backgrounds`, and never rewrites consumer settings.
- Consumers registered with `global_toggle = true` expose a module participation checkbox as an indented child of `Enable Global Color`. `global_order` controls those checkbox positions; Objectives precedes Buffs & Debuffs.
- Consumers registered with `global_only = true` bypass target participation for global color. Objectives uses this mode and owns local customization.
- Buffs & Debuffs registers as fade-capable, so the global policy suppresses OOC fading across its built-in and custom frames.
- Registration is independent from local visibility. Built-in targets register at module load; dynamic targets register when created/loaded and unregister when deleted.
- Aura target keys are `frame:<category-or-custom-id>` and `bar:<category-or-custom-id>`; Aura Frames owns their selections and controls. Objectives registers `custom_background`.
- `M.refresh_consumers()` calls registered refresh closures. Background Colors owns no consumer frames, events, timers, or queued runtime work.


## Presets And Controls
- Preset order: Red, Orange, Yellow, Green, Blue, Indigo, Violet, Black, White, Grey.
- Presets replace RGB and preserve current alpha. Picker RGB values outside the preset tolerance display as **Custom**.
- The preset selector uses shared `CreateCyclingDropdown()`: Spellbook previous-page button, standard clickable dropdown with hover arrow, and Spellbook next-page button. Cycling wraps; right/left from **Custom** enters Red/Grey.
- The module has only General and Profiles tabs. General places the Global visibility/fade/color policy group and Module Reset in two rows of a section-level `CreateSettingsGrid()`; there is no redundant module heading below the tabs. The Global row height includes its dynamic module participation count and the reset row follows it without chained anchors. There is no separate Colors tab. The Global group derives sizing from `addon.main_frame:GetContentAreaSize()` and its internal controls use a second `CreateSettingsGrid()` with 20px margins.
- Global color enablement gates the global picker/preset and whole-module participation controls.


## Profiles Reset And Lifecycle
- Profiles snapshot global policy plus each registered module's `global_enabled` flag; consumer colors and targets are excluded.
- General reset preserves profiles by default and restores only global policy/color and module participation defaults.
- Soft module disable makes resolution return caller-owned colors and refreshes consumers immediately; re-enable normalizes DB and reapplies global policy.
