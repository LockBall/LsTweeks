# Aura Frames Reference

This document describes the current `modules/aura_frames` module. It should match the code loaded by `LsTweeks.toc`.

## Load Order

Files load in this order and all extend `addon.aura_frames` as `M`:

1. `af_defaults.lua` - category lists, defaults, custom-frame template, CDM mappings.
2. `af_test_aura.lua` - fake preview entries for Test Aura toggles.
3. `af_scan.lua` - player aura scanning, classification, important aura learning, CDM viewer reads.
4. `af_render.lua` - icon/bar rendering, timer text, UNIT_AURA payload merging.
5. `af_icon_layout.lua` - icon/bar geometry and frame height anchoring.
6. `af_custom_filter.lua` - custom whitelist matching and combat fallback.
7. `af_core.lua` - ticker, Blizzard visibility controls, per-frame update pipeline.
8. `af_spell_resolver.lua` - spell metadata lookup and persisted registry updates.
9. `af_gui.lua` - Aura Frames settings UI and Frames tree.
10. `af_gui_custom.lua` - custom frame settings and whitelist/capture panels.
11. `af_debug_outlines.lua` - optional slot outline debug helper.
12. `af_grid.lua` - move-mode grid overlay and snap helpers.
13. `af_main.lua` - frame construction, event wiring, startup, reset handling.

## Categories

Preset categories are defined in `af_defaults.lua`:

```lua
M.CATEGORIES = {
    "static", "short", "long", "important",
    "essential", "utility", "tracked_buffs", "tracked_bars",
    "debuff",
}
```

`static` has no timer controls. `essential`, `utility`, `tracked_buffs`, and `tracked_bars` are backed by live Blizzard Cooldown Manager viewer frames through `M.CDM_VIEWER_FRAMES`.

Custom whitelist frames are stored in `M.db.custom_frames`, capped by `M.MAX_CUSTOM_FRAMES = 4`, and use per-entry settings instead of flat DB keys.

## Startup

`af_main.lua` handles `ADDON_LOADED`:

- links `M.db` to `Ls_Tweeks_DB.aura_frames`
- applies `M.defaults`
- resets session learning tables (`M._known_static`, `M._known_long`)
- migrates timer font keys, bar background defaults, and old position anchors
- creates all preset aura frames
- creates saved custom frames
- starts the shared `C_Timer.NewTicker(0.1)` timer ticker
- applies Blizzard buff/debuff visibility preferences
- schedules CDM startup refreshes
- registers the `Buffs & Debuffs` settings category
- creates the move-mode grid overlay

Each aura frame owns a fixed icon pool created at startup. Changing `max_icons_<category>` requires `/reload`.

## Event Flow

Each frame registers:

- `UNIT_AURA` for `player`
- `PLAYER_ENTERING_WORLD`
- `PLAYER_REGEN_DISABLED`
- `PLAYER_REGEN_ENABLED`
- `PLAYER_SPECIALIZATION_CHANGED`

CDM-backed frames also register:

- `SPELL_UPDATE_COOLDOWN`
- `SPELL_UPDATE_CHARGES`

The frame `OnEvent` handler does not scan immediately. It merges `UNIT_AURA` payloads with `M.merge_aura_info()`, sets a `_scan_pending` guard, and defers work with `C_Timer.After(0.1)`.

Deferred callback flow:

```text
af_main OnEvent
  -> M.merge_aura_info()
  -> C_Timer.After(0.1)
  -> af_core:M.update_auras()
     -> af_scan:M.unified_scan() when shared scan cache is stale
     -> category/custom/CDM filtering
     -> af_test_aura:M.append_test_aura() when preview is enabled
     -> af_icon_layout:M.setup_layout() when layout cache changed
     -> af_render:M.render_aura_map()
     -> af_icon_layout:M.set_height_for_growth()
```

The shared ticker calls `M.tick_visible_icons()` every 0.1s to update visible timer text, bars, stack text, test previews, and cooldown icon grey state without forcing a full rescan.

## Aura Data

`M.unified_scan(info, short_threshold, max_helpful_hint, max_debuff_hint)` populates `M._aura_map`.

Entries are keyed by aura instance ID when live aura data provides one. Test previews use `"__test_preview__"`. Remembered custom-frame combat fallbacks can use synthetic keys such as `"__remembered_<spellID>"`.

Common entry fields:

- `instance_id`
- `spell_id`
- `name`
- `icon`
- `duration`
- `expiration`
- `remaining`
- `count`
- `live_remaining`
- `live_count`
- `filter`
- `is_helpful`
- `category`
- `is_important`
- `order_key`
- `added_at`

CDM cooldown-mode entries may also include:

- `is_spell_cooldown`
- `duration_object`
- `grey_cooldown`
- `cdm_order`

## Classification

Helpful player auras are classified into `static`, `short`, or `long`.

- `static`: permanent aura, or learned permanent aura.
- `short`: timed aura with remaining duration at or below `short_threshold`.
- `long`: timed aura above `short_threshold`, or a learned long aura whose fields are secret.

The `important` frame is not a separate base classification. `af_scan.lua` marks a helpful aura with `entry.is_important = true` when it appears in the `"HELPFUL|IMPORTANT"` scan. The Important frame displays entries with `entry.is_important`.

Harmful player auras are classified as `debuff`.

Classification is stabilized by:

- `M._known_static`
- `M._known_long`
- old entry carry-forward
- old category by spell ID
- one-removed/one-added replacement hints
- `C_UnitAuras.DoesAuraHaveExpirationTime()` when direct timing fields are secret

## CDM-Backed Frames

CDM categories are:

- `essential`
- `utility`
- `tracked_buffs`
- `tracked_bars`

`M.add_cooldown_viewer_category_entries(target_map, category)` reads live Blizzard viewer children. Active aura display prefers child `auraInstanceID`. Cooldown-mode fallback uses hooked cooldown timing data and real spell cooldown state.

`essential` and `utility` expose `cooldown_mode_<category>`. In icon mode with cooldown mode enabled, timer text is hidden and a native `Cooldown` overlay is used. Grey state comes from real spell cooldown data, not from the Blizzard child’s visual state.

Blizzard CDM viewers are not hidden with `Hide()` because hidden viewers stop producing useful child state. `M.update_blizz_cdm_visibility(category)` uses alpha and mouse enabling instead.

Manual `Sync to CDM` in the Frames tree calls the queued CDM refresh path. Startup/settings refreshes prepare the Blizzard viewers outside combat.

## Custom Frames

Custom frames are created from `M.CUSTOM_FRAME_TEMPLATE` and persisted under `M.db.custom_frames`.

`M.create_custom_frame(entry)` reuses `M.create_aura_frame()` but tags the frame with:

- `frame.is_custom = true`
- `frame.custom_entry = entry`

Custom frames store settings directly in the entry table (`show`, `move`, `timer`, `width`, etc.) and store position in `entry.position`.

`M.filter_custom_aura_map(frame, custom_entry, shared_map)` filters the shared scan by whitelist and filter type. Matching uses:

- readable spell IDs
- readable names
- persisted `M.db.spell_name_cache`
- per-frame `auraInstanceID -> spellID` memory
- direct whitelisted spell lookup for newly applied combat auras
- short-lived last-seen replay while in combat when fields are secret

The custom settings and whitelist panels are built lazily by `af_gui_custom.lua`.

## Rendering

`M.render_aura_map()` receives a per-frame aura map and writes visual state into the pre-created icon pool.

It handles:

- game-native sort order through `C_UnitAuras.GetUnitAuraInstanceIDs()`
- fallback sort by instance/preview ID
- stable short-frame ordering with `_short_order_map`
- CDM ordering with `cdm_order`
- icon texture
- stack/count text
- bar mode name/timer/count placement
- static timer suppression
- live duration fallback via `C_UnitAuras.GetAuraDuration()`
- native cooldown overlays for spell-cooldown entries
- unused icon hiding and state cleanup

`M.set_timer_text()` is the shared timer formatter for render-time and ticker updates.

## Layout

`M.setup_layout()` owns slot geometry and writes `_layout_cache` on the frame. It reads preset DB keys from `M.db` and custom settings from `frame._cfg_db`.

Layout is recalculated when relevant cached values change:

- frame width
- bar mode
- timer text visibility
- cooldown overlay mode
- spacing
- growth

`M.set_height_for_growth()` resizes frames while preserving the appropriate edge for `UP` and `DOWN` growth.

## Settings UI

`M.BuildSettings(parent)` builds three tabs:

- `General`
- `Frames`
- `Spell ID`

The Frames tab uses a left tree and a right lazy-built content panel. Preset rows are built once. Custom tree rows are pooled and reused by row index during `rebuild_tree()` so add/delete/rename/expand/collapse does not orphan old row frames.

The tree includes Static, Debuff, Short, Long, Important, and a grouped WoW Cooldown section for Essential, Utility, Tracked Buffs, and Tracked Bars. Custom entries appear below the preset section, each with a settings node and a `Custom` whitelist child node.

## Taint and Combat Rules

- Do not call `C_UnitAuras` scanning APIs directly in `OnEvent`.
- Defer aura scans by 0.1s and merge pending UNIT_AURA payloads first.
- Guard secret values with `issecretvalue()` before comparisons or arithmetic.
- Preserve old cached data when current aura fields are secret.
- Do not call protected Blizzard layout/update methods from addon context.
- Do not run layout/geometry changes in combat.
- Do not hide Blizzard CDM viewer frames with `Hide()` when their child state is needed.

## WoW APIs Used

- `C_UnitAuras.GetBuffDataByIndex`
- `C_UnitAuras.GetDebuffDataByIndex`
- `C_UnitAuras.GetAuraDataByIndex`
- `C_UnitAuras.GetAuraDuration`
- `C_UnitAuras.GetAuraApplicationDisplayCount`
- `C_UnitAuras.GetUnitAuraInstanceIDs`
- `C_UnitAuras.DoesAuraHaveExpirationTime`
- `C_UnitAuras.GetPlayerAuraBySpellID`
- `C_UnitAuras.GetUnitAuraBySpellID`
- `GameTooltip:SetUnitAuraByAuraInstanceID`
- `C_Spell.GetSpellCooldownDuration`
- `C_Spell.GetSpellCooldown`
- `C_Spell.GetSpellInfo`
- `C_Spell.RequestLoadSpellData`
- `C_AddOns.LoadAddOn`

## Compatibility

The addon target in `LsTweeks.toc` is `Interface: 120000`. The aura frame module is written for modern `C_UnitAuras` APIs and avoids legacy `UnitAura` scans.
