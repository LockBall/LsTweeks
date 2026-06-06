# LsTweeks Project Memory

Shared memory for coding agents. Keep this file concise and durable: architecture, ownership, defaults, workflow rules, and hard-won debugging notes only.

## Table of Contents
- [Project Operations](#project-operations)
  - [Workflow](#workflow)
  - [Ketho / LuaLS](#ketho--luals)
  - [Packaging / Release](#packaging--release)
- [Project Overview](#project-overview)
  - [AddOn Summary](#addon-summary)
  - [Design Principles](#design-principles)
  - [File Map](#file-map)
  - [Saved Variables Shape](#saved-variables-shape)
- [Shared Architecture](#shared-architecture)
  - [Core Architecture Rules](#core-architecture-rules)
  - [GUI/Layout Rules](#guilayout-rules)
  - [Key WoW APIs And Lessons](#key-wow-apis-and-lessons)
- [Modules](#modules)
  - [Player Frame](#player-frame)
  - [Sound Levels](#sound-levels)
  - [Skyriding Vigor](#skyriding-vigor)
  - [Aura Frames](#aura-frames)

## Project Operations

### Workflow
- Treat this file as the project source of truth before non-trivial edits.
- Update it when architecture, defaults, APIs, or debugging lessons change.
- Do not store secrets, personal data, machine-local scratch notes, or session logs.
- Internal docs live under `internal_docs/`. Active working docs live under `internal_docs/working_docs/`: `proj_mem.md`, `ToDo.md`, and `scratchpad.md`. Completed-feature notes live under `internal_docs/completed_features/` and are reviewed on demand. Root markdown is public-facing release documentation.
- `internal_docs/tests/` is long-term capture for probes, experiments, and developing tests. Do not delete files from it during cleanup unless the user explicitly asks to remove that specific test artifact.
- Environment recovery notes live in `internal_docs/environment_tools.md`; check them first if Codex shell execution, Windows sandbox setup, or the local `.venv` breaks.
- Format ToDo plans in `internal_docs/working_docs/ToDo.md` with numbered sections (`### 1. file/topic`) and lettered checkbox substeps (`- [ ] a) ...`).
- After significant changes, provide a concise git commit message.
- Lua syntax check: `& 'C:\Program Files (x86)\Lua\5.1\luac.exe' -p <files>`.
- Vendored libraries under `libs/` are excluded from LuaLS diagnostics in workspace settings. Do not edit third-party library files for style/type warnings unless intentionally updating the library.
- Default shell for project work: use modern PowerShell via `pwsh.exe` unless a command explicitly needs another shell.

### Ketho / LuaLS
- Use VS Code WoW API (`ketho.wow-api`) with LuaLS (`sumneko.lua`) for Blizzard API reviews. Enable `wowAPI.luals.frameXML` for FrameXML/CDM/widget work.
- Treat LuaLS diagnostics as review prompts, not automatic change requests.
- Shell LuaLS checks can run with `--check`, but need explicit Ketho `Annotations/Core` and `Annotations/FrameXML` library paths plus workspace-local `--logpath`/`--metapath`.
- Direct annotation root: `C:\Users\D00D\.vscode\extensions\ketho.wow-api-0.22.3\Annotations\`.
- For APIs, grep annotations by name and cross-check call sites before changing code.
- Sound annotations are split between `Core/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua` (`C_Sound`) and `Core/Data/Wiki.lua` (globals such as `PlaySoundFile`, `MuteSoundFile`, `UnmuteSoundFile`, `StopSound`); sound aliases live in `Core/Type/BlizzardType.lua`.

### Packaging / Release
- Release package command: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File tools/package.ps1`. It writes `dist/<toc-name>-<version>.zip` and runs `tools/verify-package.ps1`.
- Packaging docs and policy live in `tools/package_me.md` and `tools/package-policy.json`.
- Packaging is data-driven. Update `tools/package-policy.json` before changing public include/exclude behavior; verifier invariants still protect required/forbidden paths.
- README image assets and Sound Levels reference/log files are public-facing and included.

## Project Overview

### AddOn Summary
**L's Tweeks** is a modular WoW 12.0.5+ UI addon by LockBall. Keep the intentional **Tweeks** spelling.

- Slash command: `/lst` (`SLASH_LSTWEEKS1`)
- SavedVariables: `Ls_Tweeks_DB`
- Version edit point: `LsTweeks.toc` only
- Current TOC Interface: `120005`; re-verify future bumps in-game with `/dump (select(4, GetBuildInfo()))`

### Design Principles
- **Single source of truth:** Defaults, category metadata, timing buckets, layout constants, and source-specific rules should have one owner.
- **Single-path behavior:** Prefer one deterministic runtime path. Centralize unavoidable branching and route callers through it.
- **Readability:** Small helpers are fine when they clarify real work. Avoid abstractions that hide WoW API, taint, combat, timing, or hot-path state.
- **Efficiency:** Aura scanning, rendering, layout, and GUI rebuilds are budgeted work. Cache hot globals, batch noisy events, skip disabled frames early, and avoid frame churn.
- **Conservative refactors:** Match existing file ownership and visible GUI unless the request explicitly changes behavior.
- Treat what I say as a hypothesis, not a fact, unless we have proof. If I am wrong, then correct me directly.

### File Map
```
README.md                 public release/readme documentation
sources.md                single source ledger for APIs, release references, tools, and embedded libraries
LsTweeks.toc              addon metadata, interface number, version, load order
LICENSE
core/
  init.lua              addon entry, DB init, slash command, addon.UPDATE_INTERVALS, addon.UI_THEME
  main_frame.lua        settings shell and addon.register_category()
  minimap_button.lua    LibDataBroker / LibDBIcon minimap button
functions/
  utils.lua             deep_copy_into(), apply_defaults()
  checkbox.lua          CreateCheckbox()
  color_picker.lua      CreateColorPicker()
  dropdown.lua          CreateDropdown() custom popup, not UIDropDownMenu
  module_reset.lua      CreateModuleReset() ARM-code module reset
  panel_riveted.lua     riveted panel style helpers
  slider_with_box.lua   CreateSliderWithBox() with built-in tenth-sec debounce
modules/
  about.lua
  player_frame/
    pf_main.lua          Player Frame settings, GUI, portrait combat text, event routing
    pf_fade.lua          Player Frame OOC fade runtime, health curve gate, fade timers
  sound_levels/          preset sound controls; mutes known FileDataIDs and plays addon replacement audio
  skyriding_vigor/       restored Skyriding Vigor display using Blizzard atlas assets and spell charges
    sv_defaults.lua      Skyriding Vigor DB defaults
    sv_bar.lua           Skyriding Vigor bar visuals, Blizzard atlas slots, wing layout, positioning, bar setting specs
    sv_gui.lua           Skyriding Vigor settings UI
    sv_main.lua          Skyriding Vigor runtime, events, charge/glide state, category bootstrap
  settings/             settings defaults + minimap/open-on-reload/interface alpha panel
  aura_frames/
    af_defaults.lua        Aura Frame defaults, FRAME_DEFS, category lists, custom template
    af_functions.lua       shared AF helpers: position, settings fallback, activity, timer behavior, custom filters, grid/backdrops
    af_scan.lua            unified aura scan, custom AuraFilters scan cache, CDM viewer reads/hooks
    af_render.lua          render_aura_map(), set_timer_text(), merge_aura_info()
    af_icon_layout.lua     icon/bar layout, growth metadata, bar params, height preservation
    af_core.lua            tick_visible_icons(), update_auras(), Blizzard frame/CDM visibility
    af_profiles.lua        Aura Frame profile save/load/apply schema
    af_gui*.lua            settings shell, tree, content panel builders
    af_gui_grid.lua        shared Aura Frames settings grid row/column placement helper
    af_main.lua            runtime init, frame/icon pool creation, events, drag/resize, reset
    af_test_aura.lua       preview aura entries
    af_debug_outlines.lua  optional icon-slot outlines
    af_screen_grid.lua     screen grid and snap helpers
libs/                    embedded libraries, documented in sources.md
media/
  fonts/                 SourceCodePro selectable; other monospace fonts on disk
  readme_images/         public README image assets
  svg/                   public README SVG assets
tools/
  package.ps1            builds dist/<toc-name>-<version>.zip
  package-policy.json    single source of truth for release zip include/exclude policy
  package_me.md          packaging instructions
  verify-package.ps1     verifies release zips against package-policy.json and TOC references
internal_docs/           internal docs excluded from release zips
  environment_tools.md   Codex shell/sandbox and project venv recovery notes
  working_docs/          active development docs
    proj_mem.md          project memory for coding agents
    ToDo.md              active internal task list
    scratchpad.md        local scratch notes
  completed_features/    completed-feature notes reviewed on demand
    aura_cancel.md       aura cancellation research, boundaries, and lessons learned
    aura_tooltips.md     tooltip annotation gap review and test notes
    sound_levels.md      slider template warning review and runtime notes
dist/                    generated package output, ignored
```

Every Lua file starts with a short responsibility header before `local addon_name, addon = ...`.

### Saved Variables Shape
Top-level keys include:
`minimap.hide`, `open_on_reload`, `interface_alpha`, `last_open_module`, `player_frame`, `sound_levels`, and `aura_frames`.

## Shared Architecture

### Core Architecture Rules
- Module pattern: `local addon_name, addon = ...`; share state through `addon` and `addon.aura_frames` (`M`).
- Sidebar categories use `addon.register_category(name, builder, { order = n })`; equal order values preserve registration order. Default order is 100.
- Stateful modules implement `on_reset_complete()` and resync controls/runtime after reset. Module reset panels use `CreateModuleReset()` and pass `opts.after_reset = M.on_reset_complete` so only that module is synchronized.
- Apply defaults with `addon.apply_defaults(defaults, db)`; guard DB tables with `or {}`.
- Shared timing values live in `addon.UPDATE_INTERVALS`; do not hardcode repeated refresh/debounce delays.
- Cache hot globals at file top (`local floor = math.floor`, `local GetTime = GetTime`, etc.).
- Never call protected Blizzard frame methods such as `UpdateAuras` or `UpdateLayout` from addon context. Restore events/Show and let Blizzard handlers run.
- Defer layout/geometry changes in combat. `update_auras()` skips scale, anchors, size, layout setup, and height changes during combat or while `frame._is_user_positioning`.

### GUI/Layout Rules
Violations here can create invisible or unstable controls.

- Widget internals anchor only to their own container.
- One `SetPoint` per anchor direction per frame; duplicate TOPLEFT/TOPRIGHT constraints can produce undefined layout.
- Do not use `frame:GetWidth()` at build time; it can be 0 before render.
- Factory functions should not place controls externally when the caller owns placement.
- `CreateSliderWithBox` already debounces callbacks at `addon.UPDATE_INTERVALS.tenth_sec`.
- `M.create_settings_grid()` in `af_gui_grid.lua` owns the Aura Frames 4-column settings grid used by preset and custom panels.
- Aura Frames tab and tree heights derive from `addon.main_frame:GetContentAreaSize()`, so the main settings window height in `core/main_frame.lua` is the single height knob.

### Key WoW APIs And Lessons
- Aura APIs: `C_UnitAuras.GetBuffDataByIndex`, `GetDebuffDataByIndex`, `GetAuraDuration`, `GetUnitAuraInstanceIDs`, `DoesAuraHaveExpirationTime`, `GetAuraApplicationDisplayCount`.
- Tooltip APIs: prefer `GameTooltip:SetUnitAuraByAuraInstanceID("player", auraInstanceID)`, fall back to `GameTooltip:SetSpellByID`.
- CDM APIs/hooks: `CooldownViewerItemDataMixin`, `hooksecurefunc`, `Settings.OpenToCategory("Cooldown Viewer")`.
- Combat/taint: `InCombatLockdown()` guards protected paths. If Blizzard’s blocked-action dialog appears, treat it as taint first.
- Sound APIs: `PlaySoundFile(fileDataID_or_path, channel?)` returns `(willPlay, soundHandle)`. `C_Sound.PlaySound(soundKitID, uiSoundSubType?)` returns `(success, soundHandle)`, though in-game testing confirmed `PlaySound(soundKitID, "SFX")` works on this client. `MuteSoundFile` / `UnmuteSoundFile` accept `number|string`; Ketho lists them as globals, not `C_Sound` members. Resolve sound API upvalues at file load.
- Lua operator precedence trap: `and` binds tighter than `or`, so `a and b ~= nil or false` parses as `(a and (b ~= nil)) or false`. The trailing `or false` is always a no-op when the left side already evaluates to a boolean. Write `a and b ~= nil` directly.

## Modules

### Player Frame

Important `player_frame` keys:
- `hide_portrait_combat_text`: hides Player Frame portrait combat text.
- `fade_out_of_combat`: enables Out Of Combat (OOC) Player Frame fading.
- `fade_alpha`: target OOC alpha, default `0.5`.
- `fade_delay`: seconds to stay fully visible after combat, default `2.0`.
- `fade_length`: seconds to fade from full alpha to `fade_alpha`, default `5.0`.
- `health_visible_threshold`: health curve release point for OOC fade, default `80`. Below this point the pass-through curve keeps PlayerFrame fully visible; above it the curve eases toward the normal time-fade alpha instead of snapping.
- `health_release_speed`: 0-100 health curve tuning for how quickly visibility drops above `health_visible_threshold`, default `75`.

#### Player Frame Runtime Notes
- `modules/player_frame/pf_main.lua` owns Player Frame settings, GUI, portrait combat text hiding, and event routing. `modules/player_frame/pf_fade.lua` owns OOC fade runtime state, combat transitions, fade timers, and the health curve gate. The old health API probe is archived at `internal_docs/tests/player_frame_health_probe.lua` and is not loaded by the addon.
- Player Frame fade combat/health events are registered only while `fade_out_of_combat` is enabled. When enabling fade, refresh combat state from `InCombatLockdown()` because the module may not have been receiving regen events while disabled.
- OOC fade is delay plus fade length. Combat always cancels pending fade work and restores `PlayerFrame` alpha to `1`.
- Combat state for Player Frame fade is owned by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` with `InCombatLockdown()` fallback. Do not use `UnitAffectingCombat("player")`; it can remain sticky after regen and block post-combat refade.
- On `PLAYER_REGEN_ENABLED`, schedule the delay and set visible alpha, but do not immediately call the combat-gated full update while the delay is active; transient combat state can cancel the new delay timer.
- Do not use `CreateAnimationGroup()` / `AnimationGroup:Play()` on `PlayerFrame`; it tainted Blizzard unit-frame heal prediction on reload. Use the module-owned `OnUpdate` fade path instead.
- Retail 12.x health APIs can return Secret Values from tainted addon paths. Player Frame health fade is strictly OOC: combat cancels fade and sets plain alpha `1`.
- In-game testing showed `UnitHealth`, `UnitHealthPercent`, `CurveConstants.ScaleTo100`, custom `UnitHealthPercent` curves, and PlayerFrame health bars all return secret current-health values OOC. The usable pattern is pass-through only: compute a normal time-based base alpha, build a `C_CurveUtil` curve where low health maps to `1` and health above the threshold eases toward the base alpha, then pass `UnitHealthPercent("player", true, curve)` directly to `PlayerFrame:SetAlpha()`.
- The health curve cache signature must include current base alpha, `health_visible_threshold`, and `health_release_speed`. Base alpha changes during the fade animation, so caching only by DB settings gives stale curve geometry.
- Do not use Lua comparisons/arithmetic/string conversion on current health or curve output. Health events should not stop or restart an active fade; after the base fade is already at target, health events only refresh the gated target alpha.
- Threshold slider changes must route through `M.fade.on_threshold_changed(db)` so the curve cache clears and already-faded alpha is reapplied without waiting for the next health event.

### Sound Levels

Important `sound_levels` keys:
- `sound_levels.targets.<target>.preset` where Ready Check replacement presets store file-level strings `"0"` through `"19"`; the UI maps these to `100%` through `5%`, with slider `0%` setting `sound_off`
- `sound_levels.targets.<target>.use_original`
- `sound_levels.targets.<target>.sound_off`
- `sound_levels.targets.<target>.play_on_adjust`
- `sound_levels.fishing_focus.enabled` toggles the Fishing Focus channel profile.
- `sound_levels.fishing_focus.master`, `sfx`, `music`, `ambience`, and `dialog` store 0-100 channel volumes applied only while the player is channeling Fishing. Missing/reset Fishing Focus channel values initialize from the user's current normal Sound_*Volume CVars, not hardcoded volume defaults.
- Fishing Focus Effects (`sfx`) initializes 25 percentage points above the user's normal Effects volume, clamped to 100; other Fishing Focus channels initialize from current normal channel values.
- `sound_levels.last_tab_index` and `sound_levels.last_sound_key` restore the Sound Levels UI tab and selected sound when reopening after reload

#### Sound Levels Ownership
- Sound target metadata lives in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_TARGETS`.
- Replacement audio file sets are configured only in `modules/sound_levels/sl_defaults.lua` under `M.SOUND_ASSETS`; targets reference them with `replacement_asset`.
- Fishing Focus behavior lives in `modules/sound_levels/sl_fishing.lua`; keep fishing-channel CVar profile logic out of the generic replacement sound runtime.
- Completed Sound Levels investigation notes live in `internal_docs/completed_features/sound_levels.md`.

#### Sound Levels Runtime Notes
- WoW does not expose true per-sound volume control or custom channels. This module uses preset replacement behavior: mute known original FileDataIDs with `MuteSoundFile` / `C_Sound.MuteSoundFile`, then optionally play addon-owned replacement files with `PlaySoundFile` / `C_Sound.PlaySoundFile`.
- File-backed targets use `M.REPLACEMENT_FILE_MIN_LEVEL` through `M.REPLACEMENT_FILE_MAX_LEVEL`, currently 20 files where `_0.ogg` is loudest and `_19.ogg` is quietest. The UI presents this as `0-100%` in 5% steps; slider `0%` is off.
- The removed Fishing Bobber replacement experiment was the only multi-file target. Current replacement targets use one `replacement_asset` each.
- Original playback is controlled by `use_original` for targets with original FileDataIDs or a SoundKit fallback; when selected, the replacement slider remains at its saved position but is dimmed/inactive until the user moves it, which clears Original.
- Sound reference/log files under `modules/sound_levels/sounds/` are public-facing and included in release zips.
- Each sound target declares a `channel` field (e.g. `"SFX"`, `"Master"`) used for all playback calls; defaults to `"Master"` if absent. Achievement and Ready Check both use `"SFX"`. In-game testing confirmed `PlaySound(soundKitID, "SFX")` succeeds on the current client despite Ketho annotating `C_Sound.PlaySound` with numeric `UISoundSubType`.
- Hot path performance: `M._event_cache` is a flat pre-baked table keyed by event name; each slot holds only actionable replacement playback data (`paths` or `soundkit_id`, plus `channel`). Off and Original targets do not create event-cache slots. `handle_event` must not touch DB/defaults and should fall back to the cached SoundKit when replacement file playback fails. `sync_registered_events()` diffs registrations against the actionable cache.
- `get_db()` and per-target defaults are guarded once per session; reset clears both guards.
- Preview cleanup must cancel pending timers as well as stop active sound handles; reset/logout should use the combined preview cleanup path.
- Fishing Focus channel events use `RegisterUnitEvent(..., "player")`; keep the Fishing spell ID guard (`131476`) and do not add a redundant unit guard.
- WoW sound APIs are resolved to upvalue locals at file load in `sl_core.lua` (`_PlaySoundFile`, `_PlaySound`, `_StopSound`, `_MuteSoundFile`, `_UnmuteSoundFile`). Call them directly — do not re-check `C_Sound` at call sites.

#### Fishing Focus Runtime Notes
- Fishing Bobber bite timing is not exposed through tested Lua hooks/APIs (sound hooks, soft-interact/world-loot/object state, tooltip APIs, vignettes, channel updates, or gamepad vibration hooks). Do not re-add Bobber replacement controls without a new confirmed runtime trigger.
- Fishing Focus is an opt-in second channel-volume profile. It caches current Sound_* CVars on Fishing channel start (`131476`), applies configured Master/SFX/Music/Ambience/Dialog values, and restores cached values on channel stop/reset/logout.
- Fishing Focus preview buttons play FishingBobber SoundKit `3355` on the Effects/SFX channel. **Normal Volumes** preview must not write Sound_* CVars; **Fishing Volumes** preview temporarily applies the Fishing Focus channel profile, plays the bobber sound, then restores cached channel CVars.

### Skyriding Vigor

Important `skyriding_vigor` keys:
- `enabled`: toggles the restored vigor display.
- `fade_when_full`: lowers alpha when vigor is full and move mode is off.
- `fade_alpha`: alpha used by `fade_when_full`.
- `move_mode`: shows the frame and enables left-drag positioning.
- `snap_to_grid`: snaps drag-saved position offsets to a 20px grid.
- `spacing` and `scale`: presentation settings. Slider ranges/steps live near bar layout params in `sv_bar.lua`; DB defaults stay in `sv_defaults.lua`.
- `spacing` is a 0-25px user-facing range at 0.5 steps. Runtime layout applies it directly between visible `FRAME_LAYOUT` frame edges. `FRAME_LAYOUT.visible_edge_inset_x` compensates for transparent atlas padding; node dimensions come only from `dragonriding_vigor_frame` atlas metadata.
- Slider reset buttons must write the DB and run their callback even when the slider already shows the default. Layout-affecting sliders such as `spacing` and `scale` must call `M.refresh_layout()` so the signature cache invalidates even when values appear unchanged.
- `position`: UIParent-center-relative saved position; Reset Position restores true screen center (`x = 0`, `y = 0`).
- The settings panel uses `CreateModuleReset()` for a module-scoped ARM-code reset of all Skyriding Vigor settings.
- `sv_settings.lua` is old/gone. The active settings file is `modules/skyriding_vigor/sv_gui.lua`.
- X/Y position sliders intentionally use `HookScript("OnValueChanged", ...)` and `M.set_position_axis()` instead of the generic `set_setting_from_slider()` wrapper. The slider binding and position setter both write DB state, but this is harmless and keeps position behavior centralized.

#### Skyriding Vigor Runtime Notes
- The module uses only Blizzard atlas assets (`dragonriding_vigor_*`) and does not copy DragonRider textures or implementation.
- Credit DragonRider in public docs for the restored vigor-display concept and prior local performance-assessment reference.
- Visibility comes from readable vigor charges plus move mode, active gliding from `C_PlayerInfo.GetGlidingInfo()`, `IsFlying()`, or the mounted advanced-flight fallback (`IsMounted()` + `IsAdvancedFlyableArea()`). Grounded mounted visibility is allowed; `fade_when_full` handles idle/full states.
- `fade_when_full` is keyed to visually full charges while not in move mode. Active gliding or `IsFlying()` restores full alpha even when charges are full; plain ground movement must not.
- Vigor charges prefer mounted/alternate unit power (`Enum.PowerType.AlternateMount`, then `Alternate`) and fall back to `C_Spell.GetSpellCharges()` for spell IDs `372610` (Skyward Ascent) and `372608` (Surge Forward). The spell-charge fallback must not drive visual node count because action spell charges can report `maxCharges = 1`; always keep the six-node bar shape in that path. Guard secret values with `issecretvalue`.
- Default Vigor node dimensions come from Blizzard atlas metadata for `dragonriding_vigor_frame`; decor wing dimensions come from `C_Texture.GetAtlasInfo("dragonriding_vigor_decor")`. Do not use live texture `GetWidth()`/`GetHeight()` reads for layout.
- When reusing `UIWidgetFillUpFrameTemplate` outside Blizzard's widget manager, force-clear/reanchor the inherited `BG`, `Bar`, and `Frame` regions and hide unused spark/flash/flipbook regions. Do not keep template-provided anchors; they can leave node art detached from the custom slot layout.
- Vigor fill/background dimensions are driven by the local `FILL_LAYOUT` table in `sv_bar.lua`; tune scale/offset there instead of changing node dimensions or adding alternate fill sizing paths.
- Skyriding Vigor wing placement is centralized in the local `WING_LAYOUT` table in `sv_bar.lua`; tune `node_gap_x`, wing scale, and shared `offset_y` instead of changing node sizing.
- Skyriding Vigor reset hooks must resync controls/runtime from the DB only. Do not write defaults in `on_reset_complete()`: `CreateModuleReset()` wipes only the calling module's DB and invokes only that module's `after_reset` hook.
- `M.apply_layout()` intentionally returns early only when both conditions hold: `not M._layout_dirty and M._layout_signature`. If the signature is nil, layout must rebuild.
- `FILL_TEST_TICK_SECONDS = 0.05` remains module-local because it is animation cadence, not normal runtime refresh cadence.
- Move mode intentionally injects fake charge data for a static preview. `needs_progress_updates` must explicitly exclude move mode, otherwise the fake nonzero duration can restart a ticker.
- Avoid always-running `OnUpdate`; use a `C_Timer.NewTicker()` only while enabled and relevant to display/recharge progress. Runtime refresh should not redo stable layout, reset slot visuals, or normalize DB on each tick.
- When Skyriding Vigor `enabled` is false, `sv_main.lua` must stop normal/fill-test tickers, hide any existing frame, disable frame mouse input, and unregister runtime events. Disabled refreshes should return before `M.ensure_frame()` so the module does not construct or lay out the bar from event traffic.

### Aura Frames

Important `aura_frames` keys:
- Session/UI: `last_tab_index`, `last_frames_node`, `last_profile_name`
- Global AF settings: `short_threshold`, `enable_blizz_buffs`, `enable_blizz_debuffs`, `snap_to_grid`, `show_grid`, `show_bar_section_outlines`
- Timer fallback: `timer_number_font`, `timer_number_font_size`, `timer_number_font_bold`
- Preset per-category keys: `<setting>_<category>` such as `show_static`, `color_debuff`, `scale_short`
- OOC fade: preset frames use `fade_ooc_<category>`, `ooc_alpha_<category>`, `fade_delay_<category>`, and `fade_length_<category>`; custom frames use flat `fade_ooc`, `ooc_alpha`, `fade_delay`, and `fade_length`. Fade timing defaults are 2s delay and 3s fade length. Legacy global CDM fade keys are migrated into per-CDM-frame settings when missing.
- Aura Frames OOC fade immediately restores full alpha while the mouse is over title bars, the resize handle, or visible icons/bars; leaving the visible frame controls resumes the configured delay/fade.
- Timer swipe keys: preset frames use `timer_swipe_<category>` and custom frames use `timer_swipe`; Bar Mode suppresses normal icon timer swipes regardless of the saved timer swipe value, and CDM cooldown-mode swipe overlays intentionally remain visible even when timer swipe is off.
- Aura cancel modifier: `cancel_modifier` is a global Aura Frames setting (`OFF`, `CTRL`, `ALT`, `SHIFT`; default `CTRL`). Modifier + right `OnMouseUp` cancellation is out-of-combat only, owned by `M.try_cancel_aura_icon()` in `af_functions.lua`, and only cancels auras resolved through a fresh `HELPFUL|CANCELABLE` scan.
- Positions: `aura_frames.positions.<category> = { point, x, y }`
- Custom frames: array entries with `id`, `name`, filter fields, flat presentation keys, and `position`
- Profiles: complete Aura Frames snapshots excluding editor/session state such as selected tabs/nodes, grid visibility, and debug outlines

#### Aura Frames Ownership
- Built-in category metadata lives in `M.FRAME_DEFS` (`af_defaults.lua`). Derive category lists, labels, CDM viewer names, preset key names, and test labels from it.
- Completed Aura Frames feature notes live in `internal_docs/completed_features/`, including aura cancellation and tooltip annotation-gap reviews.
- Preset categories: `static`, `debuff`, `short`, `long`, `essential`, `utility`, `tracked_buffs`, `tracked_bars`.
- CDM-backed categories: `essential`, `utility`, `tracked_buffs`, `tracked_bars`.
- First-install visible frames are only `static`, `short`, `long`, `debuff`. CDM defaults keep `show_*`, `move_*`, and `test_aura_*` false.
- Preset DB keys use `aura_frames.<setting>_<category>`; custom frame entries use flat keys.
- Preset and custom frame settings share the same presentation model via normalized `frame_config.keys` and `build_frame_settings_panel()` in `af_gui_frame_builders.lua`.

#### Aura Frames Runtime Gates And Refresh
- Frame processing is enabled-rooted. Disabled frames must not do move-shell work, previews, scans, render, layout, or CDM viewer prep.
- Use `M.get_frame_activity_state()` for activity decisions and `M.cdm_category_needs_viewer()` for CDM prep.
- UNIT_AURA is batched at `UPDATE_INTERVALS.tenth_sec`; timer text/bar updates also tick at `tenth_sec`.
- `render_aura_map()` stores `frame._display_count`; `tick_visible_icons()` should tick only displayed pooled icons, not the full pool.
- Aura Frames visible-icon ticker is managed on demand by `M.refresh_visible_icon_ticker()` / `M.ensure_visible_icon_ticker()`. It starts only when visible rendered icons need timer/bar/preview/CDM cooldown updates and cancels itself when no frame needs ticking.
- CDM refresh scheduling is centralized in `M.queue_wow_cooldown_refresh(profile)` (`af_main.lua`). Use profiles `"immediate"`, `"startup"`, `"settings"`, `"hook"` instead of local timer chains.
- CDM viewer frames are alpha-hidden with mouse disabled; do not `Hide()` them or they stop producing useful child state.
- CDM Blizzard-viewer hide settings must be applied for every CDM category on startup/reload, independent of whether the matching addon CDM frame is enabled.
- CDM cooldown icon grey state is based on real spell cooldown data and intentionally ignores the global cooldown.
- CDM cooldown-mode entries must transition from active aura display to grey/cooldown display while already in combat. Divine Protection on Utility is the regression test: cast out of combat, enter combat, let the active aura expire, and verify the cooldown appears without waiting for combat exit. Do not gate cooldown fallback only on `not child.auraInstanceID`; Blizzard children can retain a stale `auraInstanceID` after the active aura is gone.
- CDM viewer child frames are reused by Blizzard across categories/spells. When cached child identity changes (`cooldownID` or spell ID), clear `_lstweeks_cd_name` and `_lstweeks_cd_icon` before refilling them. Do not revert this: stale child display caches caused Utility to render active/cooldown states with mismatched Essential spell identity.

#### Aura Frames Scanning, Rendering, Timers
- Aura classification uses live timing plus scan-local old-map fallback for secret fields. Do not reintroduce learned static/long spell tables.
- `M._aura_map` remains the master auraInstanceID map. `M.unified_scan()` rebuilds `M._aura_maps_by_category` as derived preset buckets each scan.
- Sorted aura ID results are shared in `af_render.lua`; invalidate them through `M.clear_sorted_aura_ids_cache()` when aura data is marked dirty or rescanned.
- Render helpers guard stable visual setters where practical; timer countdown and bar progress must continue updating live.
- Custom frames are AuraFilters-driven, not whitelist-driven. They scan with `C_UnitAuras.GetAuraDataByIndex("player", i, M.get_custom_aura_filter(entry))`.
- Custom scan results are cached by `aura_filter` plus threshold and lazily extended for larger frame limits; aura-affecting events clear the cache.
- Timer text enable/format behavior is centralized in `af_functions.lua` via `M.get_timer_behavior()` and `M.is_timer_text_enabled()`. Timer alignment remains layout behavior in `af_icon_layout.lua`.

#### Aura Frames Position, Drag, Resize
- Aura frame positions are stored as unscaled UIParent-center coordinates.
- CDM default positions are dynamic: new/missing CDM positions are placed outside the current main GUI right edge with a 32px gap via `M.refresh_cdm_default_positions()` / `M.apply_cdm_default_positions_to_db()`.
- New custom frame default positions also use the current main GUI right edge with a 32px gap; existing saved/profile custom positions are not overwritten.
- Use `M.apply_frame_position()`, `M.read_frame_position()`, `M.sync_frame_position_to_db()`, `M.apply_saved_frame_position()`, and `M.sync_frame_position_from_drag()` rather than branching on preset vs custom manually.
- Drag/resize state is centralized through `M.start_frame_drag()` / `M.stop_frame_drag()` and `frame._is_user_positioning`.
- Runtime refreshes, especially CDM refreshes, must not reapply saved anchors, scale, size, layout, or height while the user is positioning.
- `update_auras()` guards stable frame-shell setters for scale, position, size, height, alpha, backdrop, and move-shell visibility.
- Move Reset uses `M.create_move_reset_button()` and `M.reset_frame_move_placement()`. It resets position/width, not Move Mode.

#### Aura Frames Profiles And Reset
- Aura Frame Profiles live under `M.db.profiles`; save/load is owned by `af_profiles.lua` with an explicit schema.
- Loading a profile is blocked in combat. It replaces `M.db.custom_frames`, creates missing custom runtime frames, then runs reset refresh.
- General reset uses `CreateModuleReset(..., opts)` with checked-by-default **Keep Profiles**. When unchecked, `profiles` and `last_profile_name` must be cleared and cached profile UI refreshed.
- If reset replaces `custom_frames`, remove orphan runtime frames and stale controls, then rebuild the Frames tree/content if present.

#### Aura Frames GUI
- `af_gui.lua` owns the shell: tabs are **General**, **Frames**, **Profiles**.
- `af_gui_tree.lua` owns the Frames sidebar groups: **Buffs**, **WoW Cooldown**, **Filters**.
- `af_gui_frame_builders.lua` owns General, preset/CDM, custom settings, and custom filter panels.
- CDM controls are source-specific additions layered through `opts.build_source_controls`.
- Shared presentation controls stay in the common builder; use hooks only for real source-specific behavior.

#### Aura Frames Debug, Grid, Style
- Debug outlines: `M.db.show_bar_section_outlines`; remove tagged textures with `Hide()` + `SetTexture(nil)`, not `SetParent(nil)`.
- Screen grid: `M.snap_to_grid()`, `M.snap_frame_position()`, `M.set_grid_visible()`. Grid preserves flush screen-edge positions before rounding.
- Riveted panel style: `addon.ApplyRivetedPanelStyle()` / `addon.AddRivetCorners()`.
- `addon.CreateRivetedPanel()` owns default text padding through `addon.RIVETED_PANEL_STYLE.padding`; callers should not clear/reanchor returned text just to avoid rivets.
