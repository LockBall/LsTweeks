# Aura Frames Review
Deferred findings for `modules/aura_frames/`. Remove this file when every item is resolved, rejected, or moved to its future-work owner.

## Table of Contents
- [Deferred Work](#deferred-work)

## Deferred Work
1. [ ] Central `UNIT_AURA` dispatcher — enabled frames currently merge the same payload and queue separate buckets. Profile first; the established per-frame model is intentionally conservative around taint and frame ownership.
   - Central dispatch could reduce repeated payload merging and timers, but it would couple frame lifecycles and broaden event-order and taint risk. Reopen only when profiling attributes material cost to per-frame batching, with explicit disabled-frame, custom-frame, combat, and stale-payload ownership tests.
