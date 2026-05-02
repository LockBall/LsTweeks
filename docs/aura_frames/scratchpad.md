Important caveat: I did not use a "PROC" aura filter, because current AuraFilters do not list one. Source: 
https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex

Instead, Proc is backed by Cooldown Viewer’s aura-ish categories:

Enum.CooldownViewerCategory.TrackedBuff
Enum.CooldownViewerCategory.TrackedBar
Source: 
https://warcraft.wiki.gg/wiki/Enum.CooldownViewerCategory

What changed:

Added Proc frame/defaults/settings/test aura.
Created the frame on load.
Scanner now asks C_CooldownViewer for TrackedBuff + TrackedBar spell IDs.

i see the 4 categories there, but then where did important come from

Important came from a different API surface.

There are two separate “category/filter” worlds here:

Cooldown Viewer categories
These are from Enum.CooldownViewerCategory:

Essential
Utility
TrackedBuff
TrackedBar
Those belong to C_CooldownViewer.

Aura filters
IMPORTANT is an aura filter used with C_UnitAuras, for example:

C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|IMPORTANT")
Source: 
https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex

That page lists IMPORTANT as an AuraFilters value added in 12.0.1, described as spells that pass:

C_Spell.IsSpellImportant()
So:

Important frame = C_UnitAuras aura filter: "HELPFUL|IMPORTANT"
Proc experiment = C_CooldownViewer categories: TrackedBuff / TrackedBar
They sound related because both are Blizzard “classification” systems, but they’re not the same enum.



error was result of CLEU issue
on reload, a window is immediately displayed with a message and 2 buttons, disable, ignore

LsTweeks has been blocked from an action only available tot he Blizzard UI. You can disable this addon and relaod the UI.

TODO:
- Refactor test aura previews toward "fake data, real rendering" so they follow the same render/ticker/layout rules as real aura and CDM entries. Avoid separate visual behavior in `af_test_aura.lua` except for generating placeholder icon/duration/count data.


