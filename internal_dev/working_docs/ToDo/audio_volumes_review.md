# Audio Volumes Cleanup Review
Remaining follow-up items from the completed Audio Volumes review. Delete this file after the queue is resolved or rejected; durable module rules belong in `proj_mem/modules/audio_volumes.md`.

## Table of Contents
- [Cleanup Queue](#cleanup-queue)

## Cleanup Queue
- [x] 1. Mechanical source cleanup — renamed the inner `situation_grid`, derived slider alignment from `slider_count`, and collapsed the redundant `profile_db` assignment.
- [x] 2. Legacy alias audit — removed write-only `M._fishing_focus_cached`; the shared temporary-profile cache is the sole owner.
- [ ] 3. Normal-slider defaults ownership — consolidate the three `focus_defaults` / `combat_defaults` / `quiet_custom_defaults` seeding paths behind one local helper without changing Normal Volume behavior.
- [ ] 4. Original-preview unmute — verify whether `play_original_file` needs its defensive unmute loop; remove it only if the runtime mute contract makes it unreachable.
- [ ] 5. Quick Pick menu double sync — determine whether the next-frame `C_Timer.After(0)` refresh covers a menu lifecycle need; retain it with a comment or remove the redundant pass.
