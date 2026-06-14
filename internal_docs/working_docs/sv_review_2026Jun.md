# Skyriding Vigor Review - 2026 Jun

- Ridealong passenger visibility: fixed runtime guard to hide the restored vigor bar when the player is in a vehicle but not in the control seat. Needs in-game verification on both sides of Ride Along: passenger should not see LsTweeks vigor; mount owner/driver should still see it.
- Skyriding Talents settings button: added via Blizzard `GenericTraitFrame` with `Constants.MountDynamicFlightConsts.TRAIT_SYSTEM_ID` / `TREE_ID`. Needs in-game verification on a Skyriding-unlocked character that the button opens the expected talent tree and does not just toggle-close an already-open tree in an awkward state.
- Spark overlay option: added optional Blizzard spark atlas rendering for the actively filling vigor node, with color/alpha and size controls. Needs in-game visual tuning for Default and Storm Race styles to confirm the spark sits on the fill edge without clipping or overpowering custom fill colors.
