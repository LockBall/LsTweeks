# Sources And Credits
Public credits, attribution, and embedded third-party library sources for L's Tweeks.


## Table of Contents
- [Addon References](#addon-references)
- [Embedded Libraries](#embedded-libraries)
- [Tools And Community References](#tools-and-community-references)


## Addon References
- Elkano's BuffBars: https://www.curseforge.com/wow/addons/elkbuffbars
  - Referenced for Aura Frames inspiration, especially buff/debuff bar presentation, grouping/bucketing, and configurable aura display behavior.
- Angleur: https://www.curseforge.com/wow/addons/angleur
  - Referenced for Fishing Focus-style temporary audio profile behavior during fishing.


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


## Tools And Community References
- CurseForge: https://www.curseforge.com/
- Warcraft Wiki: https://warcraft.wiki.gg/
- WoW UI source mirror: https://github.com/Gethe/wow-ui-source
