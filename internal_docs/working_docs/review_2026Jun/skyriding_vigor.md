# Skyriding Vigor Review - 2026 Jun

Rating format: `Priority` is review order, `Impact` is expected addon/user impact if the issue is real, and `Change Risk` is the risk of making changes in that area.

1. Priority: Medium | Impact: Medium | Change Risk: Medium - Spark overlay option: added optional Blizzard spark atlas rendering for the actively filling vigor node, with color/alpha and size controls. Needs in-game visual tuning for Default and Storm Race styles to confirm the spark sits on the fill edge without clipping or overpowering custom fill colors.

2. Priority: Low | Impact: Low | Change Risk: Medium - Future style ownership review: re-examine `sv_styles.lua` after Skyriding Vigor settles; the style/default/validation getter surface is functional but dense and may benefit from clearer grouping or consolidation.

## Systematic Review

1. ~~Priority: High | Impact: Medium | Change Risk: Low - `sv_gui.lua` Skyriding Talents button now guards combat before opening `GenericTraitFrame`. Verified in game that combat clicks print the LsTweaks message instead of Blizzard's generic addon-blocked warning, and that out-of-combat clicks still open Skyriding Talents.~~

2. Priority: High | Impact: High | Change Risk: Medium - `sv_state.lua` guards secret values for both `UnitPowerMax` and `UnitPower`, which matches the 12.0.7 API concern. In-game testing covered normal skyriding, grounded skyriding, flying/gliding, full vigor, no-vigor, and non-skyriding mount states. Passenger/ridealong state still needs verification.

3. ~~Priority: Medium | Impact: Medium | Change Risk: Low - Fill Test cadence was reduced to `2.0` seconds per node to make spark inspection easier. Verified in game that the slower fill is enough for spark color/size/placement tuning without making the test feel stalled.~~

4. Priority: Medium | Impact: Medium | Change Risk: Medium - Spark rendering uses atlas metadata and caches spark bounds. Default style spark extends past the frame at the bottom/top of the fill cycle; a height cap and clamped placement attempt behaved strangely and was reverted. Visual validation is still needed for Default and Storm Race styles. Spark Size max is currently `10.00`; revisit after tuning to decide whether that range should stay broad or be narrowed.

5. Priority: Medium | Impact: Low | Change Risk: Medium - `sv_styles.lua` is functional but dense: style definitions, validation, per-style DB helpers, color helpers, spark helpers, and decor helpers all live together. Re-examine after behavior is stable.

6. Priority: Medium | Impact: Low | Change Risk: Low - `sv_defaults.lua` seeds `style_layouts` only with fill values; normalization fills scale/color/defaults later. This is acceptable but worth documenting clearly if saved-variable migrations are added.
