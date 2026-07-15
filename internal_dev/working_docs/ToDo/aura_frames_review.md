# Aura Frames Review
Deferred findings for `modules/aura_frames/`. Remove this file when every item is resolved, rejected, or moved to its future-work owner.

## Table of Contents
- [Deferred Work](#deferred-work)

## Deferred Work
1. [ ] CDM viewer-child scratch ownership — `_scratch_viewer_children` is safe while every caller consumes it synchronously. Revisit only with CDM work; per-call tables trade a small allocation cost for a looser ownership contract.
   - The shared table avoids allocation during repeated CDM walks but would be overwritten by a nested or synchronously reentrant `copy_viewer_children()` call. Current callers consume it before another copy; change only if CDM work introduces nesting or reentrancy, then use a depth-aware scratch pool or accept measured per-call allocation.

2. [ ] Helpful scan-depth reduction — enabled CDM frames can increase helpful scan depth even though they render viewer children. Do not change without the Divine Protection CDM transition regression and in-game validation.
   - This is an unproven optimization, not a confirmed bug. Reopen only when profiling shows meaningful excess helpful scanning, then preserve active-aura-to-cooldown transitions and validate Divine Protection on Utility across combat entry and aura expiry.

3. [ ] Central `UNIT_AURA` dispatcher — enabled frames currently merge the same payload and queue separate buckets. Profile first; the established per-frame model is intentionally conservative around taint and frame ownership.
   - Central dispatch could reduce repeated payload merging and timers, but it would couple frame lifecycles and broaden event-order and taint risk. Reopen only when profiling attributes material cost to per-frame batching, with explicit disabled-frame, custom-frame, combat, and stale-payload ownership tests.

4. [ ] Restore rich Aura tooltip rendering only with an isolated, taint-safe implementation — Aura Frames currently renders cached `C_TooltipInfo` text through LsTweeks' plain tooltip frame instead of binding live aura data to Blizzard `GameTooltip`.
   - Live `GameTooltip` binding caused widespread secret-value errors later in Blizzard map, unit-frame, and widget tooltips. The current path preserves ordinary tooltip text but omits interactive and embedded Blizzard tooltip content. Reopen only after an in-game taint-log test proves a proposed isolated renderer cannot taint subsequent Blizzard `GameTooltip:SetOwner` calls; validate map POIs, unit-frame hover, Aura hover, and widget tooltips after both login and UI reload.
