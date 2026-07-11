# Audio Volumes Cleanup Review
Remaining follow-up items from the completed Audio Volumes review. Delete this file after the queue is resolved or rejected; durable module rules belong in `proj_mem/modules/audio_volumes.md`.

## Table of Contents
- [Cleanup Queue](#cleanup-queue)

## Cleanup Queue
- [x] 1. Mechanical source cleanup — renamed the inner `situation_grid`, derived slider alignment from `slider_count`, and collapsed the redundant `profile_db` assignment.
- [x] 2. Legacy alias audit — removed write-only `M._fishing_focus_cached`; the shared temporary-profile cache is the sole owner.
- [x] 3. Normal-slider defaults ownership — consolidated Fishing, Combat, and Quiet Custom default seeding behind one local helper while retaining Quiet Custom’s fixed initial value.
- [x] 4. Original-preview unmute — retained the defensive unmute loop and documented why preview playback must remain self-contained after unusual UI/runtime sequencing.
- [ ] 5. Quick Pick menu double sync — determine whether the next-frame `C_Timer.After(0)` refresh covers a menu lifecycle need; retain it with a comment or remove the redundant pass.
