Current cleanup TODO:
1. [done] CDM cleanup pass
   Remove stale experimental CDM code and misleading comments. Keep the hidden-live-CDM approach as the assumed design.
   Result: no stale CDM probe/debug routines found; comments now describe reading live CDM viewer state.

2. [done] CDM UI naming
   Normalize visible labels where useful.
   Result: kept `Cooldown Mode` for consistency with modal toggles such as `Bar Mode`; manual button says `Sync to CDM`.

3. [done] CDM sync cache clearing
   Generalize manual CDM sync/cache clearing across all four CDM-backed frames, not just Essential.
   Result: manual sync clears Essential, Utility, Tracked Buffs, and Tracked Bars child caches before rebuild.

4. [todo] CDM validation checklist
   Validate the current hidden-live-CDM behavior before more behavior changes:
  - Utility: hidden Blizzard viewer, cooldown mode on/off, GCD animation without cross-frame greyout, real cooldown greyout, add/remove/reorder plus Sync CDM.
  - Tracked Buffs: hidden Blizzard viewer, active aura display in and out of combat, add/remove/reorder plus Sync CDM.
  - Tracked Bars: hidden Blizzard viewer, active aura display in and out of combat, add/remove/reorder plus Sync CDM.

5. [done] CDM scan comments
   Fix stale/incorrect `af_scan.lua` cooldown-mode comments.
   Result: comments now describe live Blizzard CDM child aura state, cooldown duration object fallback, and real spell cooldown grey state.

6. [done] Remove unused child-order cache clearing
   Remove unused `_lstweeks_cd_order` cache clearing unless it becomes used again.

7. [done] CDM viewer-frame map consolidation
   Consolidate duplicate CDM viewer-frame maps in `af_scan.lua` and `af_core.lua`.
   Result: `af_defaults.lua` owns shared `M.CDM_CATEGORIES`, `M.WOW_COOLDOWN_CATEGORIES`, and `M.CDM_VIEWER_FRAMES`; scan/core/main read from those shared tables.

8. [done] CDM manual sync label
   Rename `Refresh CDM` to a clearer sync/rebuild label.
   Result: button label is `Sync to CDM`.

9. [todo] CDM auto-sync expectations
   Keep auto-refresh hooks best-effort; do not imply they fully replace manual sync unless testing proves it.
   Current behavior: moving icons between groups updates quickly; changing order within a group still needs `Sync to CDM`.

10. [todo] Test aura rendering refactor
   Refactor test aura previews toward "fake data, real rendering" so they follow the same render/ticker/layout rules as real aura and CDM entries.
   Avoid separate visual behavior in `af_test_aura.lua` except for generating placeholder icon/duration/count data.

----

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


