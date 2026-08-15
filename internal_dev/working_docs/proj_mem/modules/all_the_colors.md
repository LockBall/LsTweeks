# All the Colors Module Memory
Durable ownership and runtime contracts for `modules/all_the_colors/`.


## Table of Contents
- [Settings And Defaults](#settings-and-defaults)
- [Resolution And Consumers](#resolution-and-consumers)
- [Presets And Controls](#presets-and-controls)
- [Profiles Reset And Lifecycle](#profiles-reset-and-lifecycle)


## Settings And Defaults
- Module key: `all_the_colors`; visible category: **All the Colors**.
- `atc_defaults.lua` owns global policy defaults, the `M.AURA_COLOR_DEFS` schema used by Aura style-override defaults/UI/normalization/profiles, registry state, and the ordered global preset palette. Buff/Debuff bar defaults come from `addon.AURA_BAR_COLOR_DEFAULTS`, shared with Aura Frames.
- Persisted consumer state is limited to `all_the_colors.consumers.<module_key>.global_enabled` and optional registered `global_groups`; consumer modules own shared/local colors and target selections. Aura Frames uses `global_groups.buffs` and `global_groups.debuffs`.
- Normalize the global RGBA table and Aura style-override colors here. `ensure_consumer_db()` initializes each registered group from its own declared default; grouped consumers do not inherit the old combined `global_enabled` value.


## Resolution And Consumers
- `atc_logic.lua` owns `M.resolve_color(module_key, target_key, local_color)` with precedence `global -> caller-owned input` and `M.resolve_module_color(module_key, color_key, local_color, group_key)` for registered module-wide style overrides. Aura Frames resolves helpful bars through the Buff group and `aura_buff_bar_color`, and harmful bars through the Debuff group and `aura_debuff_bar_color`.
- Resolution returns the caller's original input table when no global override applies and never copies global color into consumer settings.
- Global color replaces RGBA and makes visibility-capable backgrounds visible for checked modules. `Show Backgrounds` operates independently and makes every registered visibility-capable background visible even without global color. Neither path rewrites consumer DB; consumer-owned borders, opacity, combat rules, and rendering remain unchanged.
- Consumers register through `M.register_consumer(module_key, opts)` and `M.register_target(module_key, target_key, opts)`. A consumer may declare ordered `global_groups`; targets select a group through `global_group` or dynamic `get_global_group`. Keys are stable resolver identity; labels, order, and capabilities are runtime metadata.
- Non-global-only targets expose consumer-owned participation through `get_enabled`; Shared Colors does not persist or edit that state.
- Fade-capable consumers register with `supports_ooc_fade = true` and resolve their saved local fade flag through `M.resolve_ooc_fade(module_key, local_enabled)`. `M.get_disable_ooc_fade()`, `M.set_disable_ooc_fade()`, and `M.is_ooc_fade_disabled()` provide the single policy API used by All the Colors and linked consumer UI. Global `Disable OOC Fade` is independent, does not depend on `Show Backgrounds`, and never rewrites consumer settings. Enabling a consumer-owned local fade clears the global disable policy through `set_disable_ooc_fade(false)`, silently synchronizes every linked control, and refreshes registered consumers.
- `Enable Test Auras` temporarily enables previews on every enabled Aura Frame without changing its individual Test Aura setting. Its adjacent Play/Pause button controls all enabled preview clocks together. It remains available independently of global color enablement.
- Consumers registered with `global_toggle = true` expose participation checkboxes as indented children of `Enable Global Color`: one consumer checkbox when ungrouped, or one checkbox per registered global group. `global_order` controls consumer placement and group order controls its children; Objectives precedes Aura Frames' separate Buffs and Debuffs entries.
- Re-registering a consumer refreshes an open General tab only when its displayed global-toggle membership, label, `global_order`, or group schema changes; repeated unchanged registrations do not rebuild the panel.
- Consumers registered with `global_only = true` bypass target participation for global color. Objectives uses this mode and owns local customization.
- Aura Frames registers as fade-capable, so the global policy suppresses OOC fading across its built-in and custom frames. This fade policy remains consumer-wide and is independent of the Buff/Debuff color participation split.
- Registration is independent from local visibility. Built-in targets register at module load; dynamic targets register when created/loaded and unregister when deleted.
- Aura target keys are `frame:<category-or-custom-id>` and `bar:<category-or-custom-id>`; Aura Frames owns their selections and controls. Objectives registers `custom_background`.
- `M.refresh_consumers()` calls registered refresh closures. Shared Colors owns no consumer frames, events, timers, or queued runtime work.


## Presets And Controls
- Preset order: Red, Orange, Yellow, Green, Blue, Indigo, Violet, Black, White, Grey.
- Presets replace RGB and preserve current alpha. Picker RGB values outside the preset tolerance display as **Custom**.
- The preset selector uses shared `CreateCyclingDropdown()`: Spellbook previous-page button, standard clickable dropdown with hover arrow, and Spellbook next-page button. Cycling wraps; right/left from **Custom** enters Red/Grey.
- The General tab has BG Colors, Bar Colors, and Text Colors columns. BG Colors stacks Frame BG and Bar BG; Frame BG affects Aura frame backgrounds only, while Bar BG independently affects their bar backgrounds. Bar Colors stacks Buff Bar and Debuff Bar; Text Colors stacks Bar Text and Timer Text. The Buff/Debuff fill colors default to the matching Aura Frames Bar Color defaults. Overrides apply only while All the Colors and the target's Buff or Debuff participation are enabled; local Aura colors remain saved underneath.
- The module has only General and Profiles tabs. General places the Global visibility/fade/test-aura/color policy group and Module Reset in two rows of a section-level `CreateSettingsGrid()`; there is no redundant module heading below the tabs. The Global row height includes its dynamic module participation count and the reset row follows it without chained anchors. There is no separate Colors tab. The Global group derives sizing from `addon.main_frame:GetContentAreaSize()` and its internal controls use a second `CreateSettingsGrid()` with 20px margins.
- Global color enablement gates the global picker/preset and consumer participation controls.


## Profiles Reset And Lifecycle
- Profiles snapshot global policy, Aura style overrides, and each registered consumer's ungrouped or grouped participation; consumer-owned colors and targets are excluded.
- General reset preserves profiles by default and restores only global policy/color and module participation defaults.
- Soft module disable makes resolution return caller-owned colors and refreshes consumers immediately; re-enable normalizes DB and reapplies global policy.
