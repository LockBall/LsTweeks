# Sources

Reference sources used for addon behavior, public release preparation, documentation, tools, and embedded third-party libraries.

## CurseForge

- Creating and submitting a project: https://support.curseforge.com/support/solutions/articles/9000197241
- World of Warcraft Multi-TOC guidance: https://support.curseforge.com/support/solutions/articles/9000209856
- Moderation policies: https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies

## Warcraft Wiki

- TOC format: https://warcraft.wiki.gg/wiki/TOC_format
- Current interface/build references: https://warcraft.wiki.gg/wiki/Template:Current_builds
- Getting the current interface number: https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number
- Cooldown Viewer categories: https://warcraft.wiki.gg/wiki/Enum.CooldownViewerCategory
- `C_UnitAuras.GetAuraDataByIndex`: https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex
- `GameTooltip:SetUnitAura`: https://warcraft.wiki.gg/wiki/API_GameTooltip_SetUnitAura
- `PlaySound`: https://warcraft.wiki.gg/wiki/API_PlaySound

## Tools

- CascView download page: https://www.zezula.net/en/casc/main.html
- Ketho WoW API VS Code extension: https://marketplace.visualstudio.com/items?itemName=ketho.wow-api

## Embedded Libraries

### LibStub

- Notes: lightweight versioning helper used by many older WoW libraries. Final, stable release.
- Primary source: https://github.com/lua-wow/LibStub
- Alternate source: https://www.wowace.com/projects/libstub
- Depends on: none
- Required by: CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0

### CallbackHandler-1.0

- Notes: event/callback dispatcher used internally by LibDataBroker and other libraries.
- Primary source: https://www.wowace.com/projects/callbackhandler
- Alternate source: https://www.curseforge.com/wow/addons/callbackhandler
- Depends on: LibStub
- Required by: LibDataBroker-1.1

### LibDataBroker-1.1

- Notes: core LDB library for creating data objects, including the minimap button launcher.
- Primary source: https://www.wowace.com/projects/libdatabroker-1-1
- Alternate source: https://www.curseforge.com/wow/addons/libdatabroker-1-1
- Depends on: CallbackHandler-1.0
- Required by: LibDBIcon-1.0 and LsTweeks

### LibDBIcon-1.0

- Notes: handles minimap button creation, dragging, position saving, and visibility.
- Primary source: https://www.wowace.com/projects/libdbicon-1-0
- Alternate source: https://www.curseforge.com/wow/addons/libdbicon-1-0
- Depends on: LibDataBroker-1.1 and LibStub
- Required by: LsTweeks
