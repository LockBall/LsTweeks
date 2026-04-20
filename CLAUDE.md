# LsTweeks — Claude Code Context

## What This Is
**L's Tweeks** — a modular WoW UI addon (patch 12.0 / Interface 120000) by LockBall.  
Slash command: `/lt`. SavedVariables: `Ls_Tweeks_DB`. Note the intentional "Tweeks" spelling throughout.

## File Map
```
core/
  init.lua          — addon entry, theme constants (addon.UI_THEME), DB init, slash cmd
  main_frame.lua    — sidebar + tabbed settings window; addon.register_category()
  minimap_button.lua — LibDataBroker minimap button
functions/
  checkbox.lua        — addon.CreateCheckbox()
  color_picker.lua    — addon.CreateColorPicker()
  dropdown.lua        — addon.CreateDropdown() — custom popup, NOT UIDropDownMenu
  module_reset.lua    — addon.CreateGlobalReset() — ARM-code safety reset
  panel_riveted.lua   — addon.CreateRivetedPanel() / ApplyRivetedPanelStyle() / AddRivetCorners()
  slider_with_box.lua — addon.CreateSliderWithBox()
  step_button_group.lua — addon.CreateStepButtonGroup()
modules/
  about.lua        — intro/version page
  settings.lua     — minimap toggle
  combat_text.lua  — hide portrait combat text
  aura_frames/
    af_defaults.lua  — all default config values, single source of truth
    af_logic.lua     — core engine: aura scanning, icon pool, layout, timer ticker (1453 lines)
    af_gui.lua       — settings tab builder
    af_main.lua      — init, events, drag mode, test aura wiring
    af_test_aura.lua — fake aura preview system
libs/            — LibStub, LibDataBroker-1.1, LibDBIcon-1.0, CallbackHandler-1.0
media/fonts/     — monospace TTFs: SourceCodePro, Inconsolata, JetBrainsMono, RobotoMono, 0xProto
```

## Architecture Rules
- **Module pattern:** `local addon_name, addon = ...` at top of every file; modules share the `addon` namespace table.
- **Self-registration:** modules call `addon.register_category(name, builder_fn)` to appear in the settings sidebar.
- **DB access:** `Ls_Tweeks_DB.module_key = Ls_Tweeks_DB.module_key or {}` — always guard with `or {}`.
- **Init pattern:** every module creates a loader frame, registers ADDON_LOADED, and unregisters after first fire.
- **Hot paths:** cache WoW globals at file top — `local floor = math.floor`, `local GetTime = GetTime`, etc.
- **Theme constants:** spacing, fonts, widths live in `addon.UI_THEME` (set in `core/init.lua`) — don't hardcode.
- **Pixel snapping:** use the pixel_snap helper in af_logic for any sub-pixel positioning.
- **Deferred batching:** UNIT_AURA events are bucketed at 0.05s; timer ticker runs at 0.1s.
- **InCombatLockdown:** defer layout changes; never call protected WoW API during combat.

## Aura Frame Categories
Four categories: `static`, `short`, `long`, `debuff`.  
DB keys follow the pattern `aura_frames.<setting>_<category>` (e.g. `show_static`, `color_debuff`).  
Positions are stored under `aura_frames.positions.<category>`.

## UI Shared Controls — Quick Reference
| Function | Key args |
|---|---|
| `CreateCheckbox(parent, label, checked, cb)` | returns container, checkbox, label |
| `CreateSliderWithBox(name, parent, label, min, max, step, db, key, defaults, cb)` | slider + input + reset |
| `CreateDropdown(name, parent, label, options, cfg)` | cfg: width, row_height, get_value, on_select |
| `CreateColorPicker(parent, db, key, has_alpha, label, defaults, cb)` | integrated reset button |
| `CreateRivetedPanel(parent, w, h, anchorTo, point, x, y, levelOffset)` | returns panel, fontstring |
| `CreateGlobalReset(parent, db, defaults)` | ARM-code safety reset control |

## Riveted Panel Style
Marble background, ornate dialog-frame borders, 4 corner rivet textures. Apply via `addon.ApplyRivetedPanelStyle(frame, opts)` or `addon.AddRivetCorners(frame, inset, offX, offY)`.

## Key WoW API Used
- `C_UnitAuras.GetBuffDataByIndex / GetDebuffDataByIndex` — aura scanning
- `C_UnitAuras.GetAuraDuration` — fallback for secret durations
- `AuraUtil.ForEachAura` — iteration helper
- `ColorPickerFrame` — system color picker
- `InCombatLockdown()` — combat guard
- `LibDataBroker`, `LibDBIcon` — minimap button
