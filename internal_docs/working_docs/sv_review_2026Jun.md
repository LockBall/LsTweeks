# Skyriding Vigor Review - June 2026

## Open Review Items

- `sv_review_2026Jun.md` did not exist when the style-selector work began. I created this working-doc copy under `internal_docs/working_docs/` to keep review notes out of public release markdown.
- Storm Race atlas references found in a public DragonRider theme example include `dragonriding_sgvigor_fill_flipbook` for animated recharge and use `dragonriding_sgvigor_fillfull` desaturated for empty fill. LsTweeks currently renders Vigor fill through a static `StatusBar`, so the new Storm Race selector uses `dragonriding_sgvigor_fillfull` for both filling and full states and does not implement the flipbook animation yet.
- DragonRider `Vigor.lua` confirms Storm side-art atlases: `dragonriding_sgvigor_decor_bronze`, `_dark`, `_gold`, and `_silver`. LsTweeks currently exposes only `default` and bronze `storm_race` end-decoration styles.
- End-decoration alignment differs by style. `DECOR_STYLES` now owns per-style layout params, with current Storm Race values initialized to the old shared defaults pending visual tuning.
- Storm Race node background uses `dragonriding_sgvigor_background`, but it does not share the default background sizing. `BAR_STYLES` now owns per-style background scale/offset fields; Storm Race starts at full node scale while Default preserves the old 0.5 scale.
- End Decor UI now uses one dropdown plus X/Y sliders. The sliders write per-style overrides to `skyriding_vigor.decor_layouts` so Default and Storm Race can be tuned independently from the same controls.
- Removed the old shared end-decoration X/Y fallback from `WING_LAYOUT`; end-decor X/Y now comes from `DECOR_STYLES` defaults or saved `decor_layouts` overrides.

## Resolved During Review

- Initial style-selector implementation used one shared `FRAME_LAYOUT.visible_edge_inset_x` spacing parameter. Storm Race art has a different node shape/padding, so forcing default layout metrics distorted the node shape. Fixed by restoring style-owned node metrics and moving visible-edge spacing parameters onto each style.
