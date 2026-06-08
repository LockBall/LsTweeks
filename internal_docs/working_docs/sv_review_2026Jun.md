# Skyriding Vigor Review - June 2026

## Open Review Items

- `sv_review_2026Jun.md` did not exist when the style-selector work began. I created this working-doc copy under `internal_docs/working_docs/` to keep review notes out of public release markdown.
- Storm Race atlas references found in a public DragonRider theme example include `dragonriding_sgvigor_fill_flipbook` for animated recharge and use `dragonriding_sgvigor_fillfull` desaturated for empty fill. An experimental Animated Fill checkbox was tested and discarded because the flipbook fill was hard to see and looked odd through the addon StatusBar path.
- DragonRider `Vigor.lua` confirms Storm side-art atlases: `dragonriding_sgvigor_decor_bronze`, `_dark`, `_gold`, and `_silver`. LsTweeks exposes these through the Decor Color dropdown when Storm Race end decor is selected.
- End-decoration alignment differs by style. `DECOR_STYLES` now owns per-style layout params, with current Storm Race values initialized to the old shared defaults pending visual tuning.
- Storm Race node background uses `dragonriding_sgvigor_background`, but it does not share the default background sizing. `BAR_STYLES` now owns per-style background scale/offset fields; Storm Race starts at full node scale while Default preserves the old 0.5 scale.
- End Decor UI now uses style/color dropdowns plus X/Y/Scale sliders. The controls write per-style overrides to `skyriding_vigor.decor_layouts` so Default and Storm Race can be tuned independently from the same controls.
- Removed the old shared end-decoration X/Y fallback from `WING_LAYOUT`; end-decor X/Y now comes from `DECOR_STYLES` defaults or saved `decor_layouts` overrides.
- Node Scale is now style-specific via `skyriding_vigor.style_layouts.<style>.scale`; switching node style resyncs the Scale slider to that style's remembered value.
- Node Color was added as a per-node-style frame atlas selector under `skyriding_vigor.style_layouts.<style>.node_color`. Storm Race frame atlas variants tested in-game: bronze, dark, gold, and silver exist; color-specific fill atlases did not.
- Decor Color was added as a per-end-decoration-style atlas selector under `skyriding_vigor.decor_layouts.<style>.decor_color`. Storm Race decor atlas variants tested in-game: bronze, dark, gold, and silver exist.
- Local DragonRider install (`../DragonRider/Vigor.lua`) confirms non-Storm/default vigor styles do not have separate bronze/dark/gold/silver atlas variants. DragonRider's default desaturated option reuses the same `dragonriding_vigor_*` atlases with desaturation, while color-specific frame/decor atlases are limited to the Storm/Algari `dragonriding_sgvigor_*` family.
- Fill Color picker was added as a per-node-style tint stored in `skyriding_vigor.style_layouts.<style>.fill_color`. Non-white fill colors now auto-desaturate the fill texture before tinting and use an additive duplicate fill layer to brighten custom colors. Fill Add is stored per style as `style_layouts.<style>.fill_add_alpha`. A per-style Fill Brightness slider was tested and discarded because RGB multiplication plus channel clamping shifted selected hues unpredictably.
- Settings now has top-level module toggles stored under `Ls_Tweeks_DB.modules`. Runtime stop/start hooks were added for Player Frame, Sound Levels, Skyriding Vigor, and Aura Frames; Aura Frames uses a best-effort disable path that hides/unregisters owned runtime frames instead of destroying frame pools.
- `sv_main.lua` still mixes DB normalization, ticker/event routing, and settings mutation. It remains workable; future cleanup could split DB normalization or setting mutation if either grows.
- Visibility originally allowed any readable charges plus `IsFlying()` or `IsMounted()` in `IsAdvancedFlyableArea()`, which made the bar display on normal non-skyriding mounts. Visibility is now gated by `GetGlidingInfo()`'s `can_glide` result for mounted/flying fallback paths.

## Resolved During Review

- Initial style-selector implementation used one shared `FRAME_LAYOUT.visible_edge_inset_x` spacing parameter. Storm Race art has a different node shape/padding, so forcing default layout metrics distorted the node shape. Fixed by restoring style-owned node metrics and moving visible-edge spacing parameters onto each style.
- Charge/flight state detection was split from `sv_main.lua` into `sv_state.lua`. `sv_main.lua` now calls `M.get_charge_info()`, `M.get_gliding_state()`, `M.is_player_flying()`, and `M.is_mounted_in_advanced_flyable_area()`.
- Active style scale, fill color, and decor position helpers were moved from `sv_main.lua` into `sv_bar.lua` so style-facing DB behavior stays with the bar style definitions.
- Skyriding Vigor GUI control synchronization moved from `sv_main.lua` into `sv_gui.lua`. `sv_main.lua` now delegates reset/style/decor/button sync through `M.sync_settings_controls()` and related GUI helpers.
- Skyriding Vigor alpha fade handling moved from `sv_main.lua` into `sv_fade.lua`. `sv_main.lua` now delegates full-charge fade policy through `M.apply_full_charge_fade()`.
- Public README Skyriding Vigor text now mentions Fill Color and separate End Decor controls.
