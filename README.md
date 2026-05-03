## L’s Tweeks
A World of Warcraft addon that provides various customizations.

## Features
• toggle portrait combat text (damage, heals)

## Installation
1. Download or clone the repository.
2. Place the addon folder into:  
   `World of Warcraft/_retail_/Interface/AddOns/`
3. Launch the game and enable **L’s Tweeks** in the AddOns menu.


## Use Notes
WoW CoolDown Manager (CDM) must stay enabled for those frames to work.
Sync to CDM may be needed after same-group reorder.

## Bheavior Notes
No icon greyout in combat is a known limitation.

## Embedded Libraries
All embedded libraries are stored in `Libs/` and documented in `Libs/SOURCES.md`.  
libs are unmodified
- CallbackHandler
- LibDBIcon
- LibDataBroker
- LibStub

## License
This project is released under the MIT License.  
Embedded libraries retain their original licenses as documented in `Libs/SOURCES.md`.  
See the `LICENSE` file for full details.  
Copyright © 2026 **LockBall**  

## Credits
- LibStub, CallbackHandler‑1.0, LibDataBroker‑1.1, and LibDBIcon‑1.0  
  by their respective authors on WowAce / CurseForge.

- I appreciate the inspiration of the WoW addon community, including but not limited to: Elkano's BuffBars,  BetterCooldownManager and ArcUI.

- Addon design and implementation by **LockBall**.

- Portions of this addon were developed with assistance by generative tools.

## Code Notes

There are two separate “category/filter” worlds. They sound related because both are Blizzard “classification” systems, but they’re not the same enum.

1) Cooldown Viewer has aura-ish categories from `Enum.CooldownViewerCategory.<>`

  Essential  
  Utility  
  TrackedBuff  
  TrackedBar  

Source: 
https://warcraft.wiki.gg/wiki/Enum.CooldownViewerCategory


2) AuraFilters come from a different API surface.

Aura filters
`IMPORTANT` is an aura filter used with `C_UnitAuras`, for example:
`Custom frame = C_UnitAuras aura : "HELPFUL|IMPORTANT"`

C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|IMPORTANT")  

Source: 
https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex

That page lists IMPORTANT, and several others, as an AuraFilters value added in 12.0.1, described as spells that pass: `C_Spell.IsSpellImportant()`

CDM frames are hidden with alpha, not Hide(), because Hide() breaks the data availability.
