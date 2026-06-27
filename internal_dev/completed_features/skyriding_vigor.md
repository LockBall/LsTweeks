# Skyriding Vigor Completed Notes
## Table of Contents
- [Race Profile](#race-profile)
- [Validation](#validation)


## Race Profile
Completed 2026-06-24.

- Skyriding race detection uses Bronze Timepiece itemID `191140`. In-game probe showed cached item info can exist outside a race, but `C_Item.GetItemCount(191140)` changes from `0` before a race to `1` after accepting a race quest such as `Dornogal Drift`.
- Race detection events are registered only while `skyriding_vigor.race_profile_enabled` is true: `BAG_UPDATE_DELAYED`, `QUEST_ACCEPTED`, `QUEST_LOG_UPDATE`, `QUEST_REMOVED`, and `QUEST_TURNED_IN`.
- The race profile is a nested full profile at `skyriding_vigor.race_profile`. The root table remains the normal profile and also owns global race controls such as `race_profile_enabled`.
- `Race Profile Test` forces the nested race profile active so the same settings UI edits the race profile without entering a race.
- Existing settings controls route through the active profile returned by `M.get_db()`. Use `M.get_root_db()` only for root/global controls such as `race_profile_enabled` and module reset.
- Module reset targets the root Skyriding Vigor DB so it resets both the normal profile and nested race profile.
- User in-game verification confirmed the Race Profile behavior worked correctly before this note was created.


## Validation
- Fast validation passed.
- Ketho/LuaLS helper reported only the known Sound Levels `C_Sound.PlaySound(soundKitID, "SFX")` warnings.
