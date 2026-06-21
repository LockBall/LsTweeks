1. Priority: High | Impact: High | Change Risk: High - Review Cooldown Manager mirroring before adding more CDM behavior. Check whether public `C_CooldownViewer` APIs can replace any `af_scan.lua` Blizzard CooldownViewer child-frame reads or `CooldownViewerItemDataMixin` hooks.

2. Priority: High | Impact: High | Change Risk: High - Confirm Blizzard buff/debuff frame restoration on Retail 12.0.7. If the current `af_core.lua` best-effort restore is incomplete, record Blizzard's current event/script ownership before changing the toggle implementation.

3. Priority: Medium | Impact: Medium | Change Risk: Medium - Test profile load/reset behavior with saved profiles that include deleted or renamed custom frames. Verify orphan custom frames and stale controls are removed before touching profile storage.
