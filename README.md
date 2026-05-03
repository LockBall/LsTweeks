## L's Tweeks
A modular World of Warcraft UI addon for small interface adjustments and configurable aura frames.

## Features
- Buffs & Debuffs module with configurable aura frames.
- Preset frames for static buffs, short buffs, long buffs, debuffs, and WoW Cooldown Manager groups.
- Custom filtered aura frames using modern `C_UnitAuras` AuraFilters such as `HELPFUL|IMPORTANT`.
- Icon or bar presentation modes, growth direction, spacing, width, colors, timers, and test-aura previews.
- Optional tooltip spell ID display.
- Optional hiding of Blizzard buff/debuff frames.
- Optional minimap button, open-on-reload setting, and main panel transparency.
- Toggle for portrait combat text.

## Installation
1. Download or clone the repository.
2. Place the addon folder into:
   `World of Warcraft/_retail_/Interface/AddOns/`
3. Launch the game and enable **L's Tweeks** in the AddOns menu.

## Use Notes
- Slash command: `/lst`
- Open the **Buffs & Debuffs** panel for aura frame settings.
- Open the **Settings** panel for minimap, open-on-reload, and interface transparency settings.

## Aura Frames Reference
Aura frames replace and extend the default buff/debuff display. The module includes preset player-aura frames, WoW Cooldown Manager-backed frames, and up to four custom filtered frames.

### Preset Frames
- `Static`: permanent player buffs.
- `Short`: timed player buffs at or below the short-buff threshold.
- `Long`: timed player buffs above the short-buff threshold.
- `Debuffs`: harmful player auras.

### WoW Cooldown Manager Frames
CDM-backed frames read live Blizzard Cooldown Manager viewer state:

- `Essential`
- `Utility`
- `Tracked Buffs`
- `Tracked Bars`

WoW Cooldown Manager must stay enabled for these frames to populate. CDM-backed Blizzard viewer frames are hidden with alpha/mouse settings, not `Hide()`, because hidden viewers stop providing useful child state. Use **Sync to CDM** after manually reordering icons inside the same CDM group if the addon frame has not refreshed yet.

Cooldown Viewer categories come from `Enum.CooldownViewerCategory`.
Source: https://warcraft.wiki.gg/wiki/Enum.CooldownViewerCategory

### Custom Filtered Frames
Custom frames scan player auras directly with `C_UnitAuras.GetAuraDataByIndex()` and a selected AuraFilters string.

Example custom frame filter:

```lua
C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|IMPORTANT")
```

Source: https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex

`IMPORTANT` and several other AuraFilters values were added in 12.0.1. `IMPORTANT` is described as spells that pass `C_Spell.IsSpellImportant()`.

### Behavior Notes
- Aura scans are deferred and batched at 0.1s to avoid reading protected/secret aura fields inside event dispatch.
- Frame geometry updates are skipped during combat; timers and bars continue updating, and layout catches up after combat.
- Changing an aura frame pool size requires `/reload` because icon pools are created at load time.
- CDM cooldown icon grey state is based on real spell cooldown data and intentionally ignores the global cooldown.

## Embedded Libraries
All embedded libraries are stored in `libs/` and documented in `libs/sources.md`.
Libraries are unmodified.
- CallbackHandler
- LibDBIcon
- LibDataBroker
- LibStub

## License
This project is released under the MIT License.
Embedded libraries retain their original licenses as documented in `libs/sources.md`.
See the `LICENSE` file for full details.
Copyright (c) 2026 **LockBall**

## Credits
- LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0
  by their respective authors on WowAce / CurseForge.
- I appreciate the inspiration of the WoW addon community, including but not limited to: Elkano's BuffBars, BetterCooldownManager, and ArcUI.
- Addon design and implementation by **LockBall**.
- Portions of this addon were developed with assistance by generative tools.
