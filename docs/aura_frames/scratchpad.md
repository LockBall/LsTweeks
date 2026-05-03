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

4. [done] Utility CDM validation
   Validate Utility with hidden Blizzard viewer, cooldown mode on/off, GCD animation without cross-frame greyout, real cooldown greyout, add/remove/reorder plus Sync to CDM.
   Result: functional behavior passes. Known limitation: icon greyout only updates out of combat. Do not chase combat grey for now; cooldown overlay is the reliable in-combat unavailable signal.

5. [done] Tracked Buffs CDM validation
   Validate Tracked Buffs with hidden Blizzard viewer, active aura display in and out of combat, add/remove/reorder plus Sync to CDM.
   Result: behavior appears correct in current testing.

6. [done] Tracked Bars CDM validation
   Validate Tracked Bars with hidden Blizzard viewer, active aura display in and out of combat, add/remove/reorder plus Sync to CDM.
   Result: behavior appears correct in current testing.

7. [done] CDM scan comments
   Fix stale/incorrect `af_scan.lua` cooldown-mode comments.
   Result: comments now describe live Blizzard CDM child aura state, cooldown duration object fallback, and real spell cooldown grey state.

8. [done] Remove unused child-order cache clearing
   Remove unused `_lstweeks_cd_order` cache clearing unless it becomes used again.

9. [done] CDM viewer-frame map consolidation
   Consolidate duplicate CDM viewer-frame maps in `af_scan.lua` and `af_core.lua`.
   Result: `af_defaults.lua` owns shared `M.CDM_CATEGORIES`, `M.WOW_COOLDOWN_CATEGORIES`, and `M.CDM_VIEWER_FRAMES`; scan/core/main read from those shared tables. Defaults comments were tightened after consolidation.

10. [done] CDM manual sync label
   Rename `Refresh CDM` to a clearer sync/rebuild label.
   Result: button label is `Sync to CDM`.

11. [done] CDM auto-sync expectations
   Keep auto-refresh hooks best-effort; do not imply they fully replace manual sync unless testing proves it.
   Result: `Sync to CDM` tooltip explains that group changes usually update automatically, while same-group reorder may need manual sync.

12. [done] Test aura rendering refactor
   Refactor test aura previews toward "fake data, real rendering" so they follow the same render/ticker/layout rules as real aura and CDM entries.
   Result: `af_test_aura.lua` now only builds and updates synthetic preview state. Timer text, bars, stack text, and cooldown-mode timer hiding flow through the normal render/ticker path.

----

error was result of CLEU issue
on reload, a window is immediately displayed with a message and 2 buttons, disable, ignore

LsTweeks has been blocked from an action only available tot he Blizzard UI. You can disable this addon and relaod the UI.


