# LsTweeks Review - 2026 Jun

Rating format: `Priority` is review order, `Impact` is expected addon/user impact if the issue is real, and `Change Risk` is the risk of making changes in that area.

## Skyriding Vigor

1. Priority: Medium | Impact: Medium | Change Risk: Medium - Spark overlay option: added optional Blizzard spark atlas rendering for the actively filling vigor node, with color/alpha and size controls. Needs in-game visual tuning for Default and Storm Race styles to confirm the spark sits on the fill edge without clipping or overpowering custom fill colors.

2. Priority: Low | Impact: Low | Change Risk: Medium - Future style ownership review: re-examine `sv_styles.lua` after Skyriding Vigor settles; the style/default/validation getter surface is functional but dense and may benefit from clearer grouping or consolidation.

## WoW API Update Review

Source checked:
1. Gethe/wow-ui-source tags: https://github.com/Gethe/wow-ui-source/tags

2. Compared 12.0.5 to 12.0.7: https://github.com/Gethe/wow-ui-source/compare/12.0.5...12.0.7

Notes:
1. Priority: High | Impact: High | Change Risk: High - No evidence from the diff says we should broadly re-work the whole addon immediately. The safer next step is targeted audit/testing around APIs this addon already touches.

2. Priority: High | Impact: High | Change Risk: Medium - Skyriding Vigor should be reviewed around `UnitPower` and `UnitPowerMax`. The 12.0.5 -> 12.0.7 API docs include `ShouldUnitPowerBeSecret`, `ShouldUnitPowerMaxBeSecret`, and secret annotations for restricted unit power reads. `sv_state.lua` already has some `issecretvalue` handling, but verify both current and max vigor paths, especially when using `Enum.PowerType.AlternateMount` or the Alternate fallback.

3. Priority: High | Impact: High | Change Risk: High - The diff adds/expands `C_CooldownViewer` and Blizzard_CooldownViewer files. This is more relevant to cooldown/display modules than Skyriding Vigor. If LsTweeks currently hooks or reads Blizzard cooldown viewer frames directly, consider a later pass to see whether the public `C_CooldownViewer` API can replace any frame-level assumptions.

4. Priority: High | Impact: High | Change Risk: Medium - The diff contains broader restricted/secret-value documentation changes and notes around protected UI operations. Audit code that opens Blizzard UI panels, especially the Skyriding Talents button path, and guard or disable it in combat if testing shows blocked/protected behavior.

5. Priority: Medium | Impact: High | Change Risk: Medium - Aura APIs used elsewhere in the addon, including `C_UnitAuras.GetUnitAuraInstanceIDs`, `GetAuraDataByAuraInstanceID`, `GetAuraDataByIndex`, `GetAuraDuration`, `DoesAuraHaveExpirationTime`, and `GetAuraApplicationDisplayCount`, still appear in the API docs. No immediate aura rewrite is indicated from this source alone, but refresh local annotations and run diagnostics after the WoW API update.

6. Priority: Medium | Impact: Medium | Change Risk: Low - `C_PlayerInfo.GetGlidingInfo`, `Enum.PowerType.AlternateMount`, `C_Spell.GetSpellCharges`, `C_Spell.GetSpellCooldown`, and `C_Spell.GetSpellCooldownDuration` remain present in the compared source. This supports the current Skyriding Vigor approach, pending in-game validation.

7. Priority: Medium | Impact: Medium | Change Risk: Low - `C_Texture.GetAtlasInfo` remains present, so the atlas validation work for vigor textures and spark atlases does not need an immediate API rewrite. Still test selected atlas names in-game because art kit names can fail silently when assumptions are wrong.

8. Priority: Low | Impact: Low | Change Risk: Low - The mirror shows 12.0.5 as build 67602 and 12.0.7 as the latest tag available during this review. This is not Blizzard's official documentation, but it is a direct public mirror of Blizzard UI source/API docs and is useful for identifying addon-facing changes.

Recommended follow-up:
1. Priority: High | Impact: High | Change Risk: Low - Run LuaLS/Ketho diagnostics against updated API annotations.

2. Priority: High | Impact: High | Change Risk: Low - In-game smoke test Skyriding Vigor for normal flight, recharge, max vigor, and no-vigor states after the 12.0.7 client update.

3. Priority: High | Impact: Medium | Change Risk: Low - Test the Skyriding Talents button both out of combat and in combat.

4. Priority: High | Impact: High | Change Risk: High - Add a focused review of cooldown viewer integration if this addon is touching Blizzard cooldown viewer frames.

## Systematic Review Prep

### Aura Frames

1. Priority: High | Impact: High | Change Risk: High - Cooldown Manager mirroring is the largest API-drift risk. `af_scan.lua` still walks Blizzard CooldownViewer child frames and hooks `CooldownViewerItemDataMixin`; the 12.0.7 source adds/expands `C_CooldownViewer`, so review whether public API calls can replace any child-frame reads before more CDM behavior is added.

2. Priority: High | Impact: High | Change Risk: High - Blizzard buff/debuff frame toggles in `af_core.lua` hide frames, unregister all events, then best-effort restore only `UNIT_AURA` and `PLAYER_ENTERING_WORLD`. Confirm this still restores default Retail 12.0.7 buff/debuff behavior, or record the current Blizzard event/script ownership before changing anything.

3. Priority: High | Impact: High | Change Risk: High - Keep the current deferred `UNIT_AURA` scan model. The code is intentionally avoiding direct aura reads during event dispatch because combat/secret values can appear there; any rewrite should preserve that design.

4. Priority: Medium | Impact: Medium | Change Risk: Medium - Profile load/reset paths look combat-aware and schema-driven. Review custom-frame cleanup and profile apply behavior with saved profiles that include deleted/renamed custom frames before touching profile storage.

5. Priority: Medium | Impact: Medium | Change Risk: Medium - OOC frame fade is per-frame and ticker-based through `OnUpdate`; confirm hover restoration and fade timers stop when the Aura Frames module is disabled.

6. Priority: Low | Impact: Low | Change Risk: Medium - The Aura Frames defaults are broad but mostly centralized in `af_defaults.lua`. If future cleanup happens, keep `FRAME_DEFS` as the owner of preset/CDM category metadata.
---


### Skyriding Vigor
1. ~~Priority: High | Impact: Medium | Change Risk: Low - `sv_gui.lua` Skyriding Talents button now guards combat before opening `GenericTraitFrame`. Verified in game that combat clicks print the LsTweaks message instead of Blizzard's generic addon-blocked warning, and that out-of-combat clicks still open Skyriding Talents.~~

2. Priority: High | Impact: High | Change Risk: Medium - `sv_state.lua` guards secret values for both `UnitPowerMax` and `UnitPower`, which matches the 12.0.7 API concern. In-game testing covered normal skyriding, grounded skyriding, flying/gliding, full vigor, no-vigor, and non-skyriding mount states. Passenger/ridealong state still needs verification.

3. ~~Priority: Medium | Impact: Medium | Change Risk: Low - Fill Test cadence was reduced to `2.0` seconds per node to make spark inspection easier. Verified in game that the slower fill is enough for spark color/size/placement tuning without making the test feel stalled.~~

4. Priority: Medium | Impact: Medium | Change Risk: Medium - Spark rendering uses atlas metadata and caches spark bounds. Visual validation is still needed for Default and Storm Race styles because color, alpha, and size can overpower the fill or clip against frame art. Spark Size max is currently `10.00`; revisit after tuning to decide whether that range should stay broad or be narrowed.

5. Priority: Medium | Impact: Low | Change Risk: Medium - `sv_styles.lua` is functional but dense: style definitions, validation, per-style DB helpers, color helpers, spark helpers, and decor helpers all live together. Re-examine after behavior is stable.

6. Priority: Medium | Impact: Low | Change Risk: Low - `sv_defaults.lua` seeds `style_layouts` only with fill values; normalization fills scale/color/defaults later. This is acceptable but worth documenting clearly if saved-variable migrations are added.
---


### Player Frame
1. Priority: High | Impact: High | Change Risk: High - Health fade depends on pass-through `UnitHealthPercent("player", true, curve)` and avoids arithmetic on secret health values. Preserve this pattern; do not rewrite to direct health comparisons.

2. Priority: Medium | Impact: Medium | Change Risk: Medium - `pf_fade.lua` installs the `PlayerFrame:HookScript("OnShow")` hook only when fade is enabled, which matches project memory. Verify disable/re-enable cycles restore alpha and do not leave pending timers.

3. Priority: Medium | Impact: Medium | Change Risk: Low - `pf_main.lua` unregisters fade events when OOC fade is disabled; test toggling fade while already out of combat and while entering/exiting combat.
---


### Sound Levels
1. Priority: High | Impact: High | Change Risk: Low - Revalidate original FileDataIDs after the client update, especially Ready Check/LFG proposal sounds. The runtime mute/replacement approach depends on those IDs staying correct.

2. Priority: Medium | Impact: Medium | Change Risk: Medium - Fishing Focus restore paths look present on disable, preview stop, channel stop, reset, and logout. Test interrupted casts, logout/reload while active, and disabling the module while Fishing Focus is active.

3. Priority: Low | Impact: Low | Change Risk: Low - The asset key/path spelling `achievmentsound1` matches the on-disk folder; avoid "fixing" spelling unless all paths/files/docs are migrated together.
---


### Core, Settings, And Shared UI
1. Priority: High | Impact: Medium | Change Risk: Low - Add an in-game validation surface for module runtime state before relying on module-toggle testing. A lightweight diagnostic such as `/lst status` or a debug-only status panel should report each module's enabled flag plus observable runtime facts, for example registered events/tickers/frame visibility where applicable.

2. Priority: High | Impact: High | Change Risk: High - Revisit disabled-module architecture. User expectation is that a disabled module consumes effectively zero runtime resources and exposes no settings interface beyond a greyed module button. Current modules are soft-disabled after their Lua files load; a stronger design needs a lightweight core module manifest plus lazy construction, and possibly LoadOnDemand child addons if memory footprint must be minimized before a module is enabled.

3. Priority: Medium | Impact: Medium | Change Risk: Medium - Module enable toggles call each module's `set_module_enabled()`, and disabled module pages remain visible but unselectable. This matches project memory; test toggling each module without reload after there is a visible status/debug path to verify runtime shutdown.

4. Priority: Medium | Impact: Medium | Change Risk: Low - `CreateModuleReset()` blocks reset during combat and calls module-owned `after_reset` hooks. Continue using it for module resets; avoid cross-module reset side effects.

5. Priority: Low | Impact: Medium | Change Risk: Low - `CreateSliderWithBox()` now runs reset callbacks even when the slider value already equals default. Keep that behavior for layout-affecting sliders.
---


### Packaging And Docs
1. Priority: Medium | Impact: High | Change Risk: Low - Package policy excludes `internal_docs` and includes public media/readme assets. Run the package verifier before release rather than auditing the zip by hand.

2. Priority: Low | Impact: Low | Change Risk: Low - README credits and feature descriptions are broadly current, but Skyriding Vigor docs should mention spark controls once in-game tuning is accepted.
