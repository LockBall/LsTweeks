# Aura Frames Review - 2026 Jun

Rating format: `Priority` is review order, `Impact` is expected addon/user impact if the issue is real, and `Change Risk` is the risk of making changes in that area.

1. Priority: High | Impact: High | Change Risk: High - Cooldown Manager mirroring is the largest API-drift risk. `af_scan.lua` still walks Blizzard CooldownViewer child frames and hooks `CooldownViewerItemDataMixin`; the 12.0.7 source adds/expands `C_CooldownViewer`, so review whether public API calls can replace any child-frame reads before more CDM behavior is added.

2. Priority: High | Impact: High | Change Risk: High - Blizzard buff/debuff frame toggles in `af_core.lua` hide frames, unregister all events, then best-effort restore only `UNIT_AURA` and `PLAYER_ENTERING_WORLD`. Confirm this still restores default Retail 12.0.7 buff/debuff behavior, or record the current Blizzard event/script ownership before changing anything.

3. Priority: High | Impact: High | Change Risk: High - Keep the current deferred `UNIT_AURA` scan model. The code is intentionally avoiding direct aura reads during event dispatch because combat/secret values can appear there; any rewrite should preserve that design.

4. Priority: Medium | Impact: Medium | Change Risk: Medium - Profile load/reset paths look combat-aware and schema-driven. Review custom-frame cleanup and profile apply behavior with saved profiles that include deleted/renamed custom frames before touching profile storage.

5. Priority: Medium | Impact: Medium | Change Risk: Medium - OOC frame fade is per-frame and ticker-based through `OnUpdate`; confirm hover restoration and fade timers stop when the Aura Frames module is disabled.

6. Priority: Low | Impact: Low | Change Risk: Medium - The Aura Frames defaults are broad but mostly centralized in `af_defaults.lua`. If future cleanup happens, keep `FRAME_DEFS` as the owner of preset/CDM category metadata.
