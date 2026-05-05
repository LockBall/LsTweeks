## L's Tweeks
A modular World of Warcraft UI addon for interface adjustments and configurable aura frames.

---
&nbsp;

## Features
- Buffs & Debuffs module with configurable aura frames.
- Preset frames for static, short, long and de buffs as well as WoW CoolDown Manager (CDM) groups.
- Custom filtered aura frames using AuraFilters such as `HELPFUL|IMPORTANT`.
- Icon or bar presentation modes, growth direction, spacing, width, colors, timers, and test-aura previews.
- Optional tooltip spell ID display.
- Optional hiding of Blizzard buff/debuff frames.
- Optional minimap button, open-on-reload setting, and main panel transparency.
- Toggle for portrait combat text.

---
&nbsp;

## Manual Installation
### Download 
1. Download the repository as a zip file by clicking the
<button style="
  display: inline-flex;
  align-items: center;
  gap: 0.5em;
  padding: 0.5em 1em;
  background-color: #2ea853;
  color: white;
  border: none;
  border-radius: 0.5em;
  font-size: 1em;
  font-weight: 500;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
">
  <span style="font-size: 1.2em;">&#60;&#62;</span>
  Code
  <span style="font-size: 0.9em;">▼</span>
</button>
button, then clicking
<button style="
  display: inline-flex;
  align-items: center;
  gap: 0.5em;
  padding: 0.5em 1em;
  background-color: #1f1f1f;
  color: white;
  border: none;
  border-radius: 0.5em;
  font-size: 1em;
  font-weight: 500;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
">
  <img src="readme_images/zipper.png" style="height: 2.0em; width: 2.0em;" alt="">
  Download ZIP
</button>

1. Extract the zip file. This should give you a folder.

1. Ensure the addon is in a single folder named `LsTweeks`.
    1. This is necessary as some zip file extractors will rename the folder or add extra folders.

1. Place the addon folder into the WoW AddOn directory:  
   `World of Warcraft/_retail_/Interface/AddOns/`

1. Launch the game and enable **L's Tweeks** in the AddOns menu.

### Clone
1. Clone the repository into the AddOns folder directly or to a location of your choice and copy or move into the WoW AddOn directory:  
   `World of Warcraft/_retail_/Interface/AddOns/`

---
&nbsp;

## Use Notes
- To open the L's Tweeks addon without the minimap button input the Slash Command: `/lst` in the chat wender and press Enter.
- Open the **Buffs & Debuffs** panel for aura frame settings.
- Open the **Settings** panel for minimap, open-on-reload, and interface transparency settings.

---
&nbsp;

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

**NOTE:** WoW Cooldown Manager must stay enabled for these frames to populate. CDM-backed Blizzard viewer frames are hidden with alpha/mouse settings, not `Hide()`, because hidden viewers stop providing useful child state. Use **Sync to CDM** after manually reordering icons inside the same CDM group if the addon frame has not refreshed yet.

Cooldown Viewer categories come from WoW API `Enum.CooldownViewerCategory`.  
Source: https://warcraft.wiki.gg/wiki/Enum.CooldownViewerCategory

### Custom Filtered Frames

---
&nbsp;

## Embedded Libraries
All embedded libraries are stored in `libs/` and documented in `libs/sources.md`.
Libraries are unmodified.
- CallbackHandler
- LibDBIcon
- LibDataBroker
- LibStub

---
&nbsp;

## License
- This project is released under the MIT License.
- Embedded libraries retain their original licenses as documented in `libs/sources.md`.
- See the `LICENSE` file for full details.
- Copyright (c) 2026 **LockBall**

---
&nbsp;

## Credits

- LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0 by their respective authors on WowAce / CurseForge.

- I appreciate the inspiration of the WoW addon community, including but not limited to: Elkano's BuffBars, BetterCooldownManager, and ArcUI.

- Addon design and implementation by **LockBall**.

- Special thanks to **DiscoMouse**+++++ !

- Portions of this addon were developed with assistance by generative tools.

---
&nbsp;

## Nerd Notes

### Behavior Notes
- Aura scans are deferred and batched at 0.1s to avoid reading protected/secret aura fields inside event dispatch.

- Frame geometry updates are skipped during combat; timers and bars continue updating, and layout catches up after combat.

- Changing an aura frame pool size requires `/reload` because icon pools are created at load time.

- CDM cooldown icon grey state is based on real spell cooldown data and intentionally ignores the global cooldown.

### Custom Filtered Frames
- Custom frames scan player auras directly with API call `C_UnitAuras.GetAuraDataByIndex()` and a selected AuraFilters string.

- Example custom frame filter code:  
`C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|IMPORTANT")`

- Source: https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex

- The `IMPORTANT` AuraFilter and several other AuraFilters values were added in 12.0.1. `IMPORTANT` is described as spells that pass `C_Spell.IsSpellImportant()`.