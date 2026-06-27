# Aura Frames Completed Features
Consolidated completed-feature notes for `modules/aura_frames/`.


## Table Of Contents
- [Aura Cancellation](#aura-cancellation)
- [Aura Tooltips](#aura-tooltips)
- [Runtime Event Ownership](#runtime-event-ownership)
- [Blizzard Frame Restore](#blizzard-frame-restore)
- [CDM Mirroring Review](#cdm-mirroring-review)
- [Profile Legacy Review](#profile-legacy-review)


## Aura Cancellation
Completed: 2026-05-26

Aura cancellation is supported only out of combat, only for real cancelable player buffs, and only when the configured modifier key is held (`OFF`, `CTRL`, `ALT`, or `SHIFT`). Do not add in-combat cancel support without a secure-button redesign.

Implementation rules:

- Addon aura icons are plain frames, not secure aura buttons.
- Never pass `obj.aura_index` directly to `CancelUnitBuff`; in LsTweeks it stores `auraInstanceID`, while `CancelUnitBuff("player", index, filter)` requires the current positional buff index.
- On click, reject cheaply first: feature off, combat lockdown, wrong modifier, nonnumeric aura identity, test preview, spell cooldown, disallowed frame/source.
- Allowed sources are preset `static` and `long` buff frames, plus custom frames when the clicked icon resolves to a current cancelable player buff.
- Treat a fresh `C_UnitAuras.GetBuffDataByIndex("player", i, "HELPFUL|CANCELABLE")` scan as authoritative. Cancel only when the scan finds the clicked `auraInstanceID`.
- Ignore unsupported states silently.
- Queue a normal aura refresh after a successful cancel attempt.

Source findings:

- `CancelUnitBuff` is restricted and `#nocombat`; name/rank cancellation was removed in patch 8.0.1.
- Secure templates support modifier attributes (`shift-`, `ctrl-`, `alt-`) and `cancelaura`, but combat-safe support would require secure action buttons and careful out-of-combat attribute updates.
- `SecureAuraButtonTemplate` uses right-click `type2 = cancelaura`.
- The `CANCELABLE` aura filter is the reliable way to identify buffs that can be cancelled.

Useful references for historical context:

- https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate
- https://warcraft.wiki.gg/wiki/API_CancelUnitBuff
- https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetBuffDataByIndex
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.xml

Non-goals: in-combat cancellation, debuff cancellation, preset short-buff cancellation unless intentionally changed later, CDM/cooldown-viewer cancellation unless backed by a real cancelable player buff, and global keyboard-only cancellation.


## Aura Tooltips
Completed: 2026-05-30

Treat `GameTooltip:SetUnitAuraByAuraInstanceID(...)` warnings as a Ketho/Core annotation gap, not a client-version bug.

Keep the runtime guard:

```lua
if not GameTooltip.SetUnitAuraByAuraInstanceID then return false end
```

Keep the existing spell tooltip fallback path.

Evidence: Ketho/LuaLS does not expose `GameTooltip.SetUnitAuraByAuraInstanceID` on the core `GameTooltip` type, but Ketho FrameXML annotations show Blizzard using it in BuffFrame, CooldownViewer, and NamePlate aura code. FrameXML maps the tooltip handler to `GetUnitAuraByAuraInstanceID`.

Test by hovering addon aura icons/bars for active player buffs and debuffs. The test aura should still show a spell tooltip when no live aura tooltip is available.


## Runtime Event Ownership
Completed: 2026-06-06

Do not centralize Aura Frames event handling into one dispatcher at this time.

Aura Frames creates one runtime frame per preset/custom frame. The normal upper bound is small: 8 preset frames plus up to 4 custom frames. CDM frames add cooldown update events.

Disabled frames return from `handle_aura_frame_event()` before aura-info merging, dirty/cache work, or deferred callbacks. Enabled frames still need their own render/update pass, and the shared scan prevents repeated full aura scans in the same dirty batch.

The measured CPU profile did not show event-handler overhead as a hotspot. A central dispatcher would be invasive because CDM refreshes, custom filters, profile loads, combat deferral, and per-frame update params all depend on the current frame-owned callback shape.

Revisit only if future profiling shows event-handler overhead is material or runtime frame count increases significantly.


## Blizzard Frame Restore
Completed: 2026-06-21

Aura Frames' **Enable Blizz Frame** toggles stopped restoring Blizzard `BuffFrame` / `DebuffFrame` after hiding them. The old code called `Hide()`, `UnregisterAllEvents()`, and cleared `OnShow`, then tried to restore with a guessed event list.

Retail 12.0.7 source showed those frames own more event/script state than LsTweeks should recreate. The original fix tracked addon-owned forced-hidden state in a weak table and avoided event/script replacement. A later Retail secret-value taint error showed the rule must be stricter: LsTweeks must not call `Hide()` / `Show()` on Blizzard `BuffFrame` / `DebuffFrame` either.

Durable rule: do not call `Hide()`, `Show()`, `UpdateShownState()`, `UpdateAuras()`, `UnregisterAllEvents()`, register guessed restore events, or replace scripts on Blizzard `BuffFrame` / `DebuffFrame`. Suppress them with addon-owned forced-hidden state plus alpha/mouse settings only. A one-time `OnShow` hook may reapply alpha/mouse state, but must never call `Hide()`.

Evidence:

- Source reviewed: Gethe/wow-ui-source 12.0.7 `Blizzard_BuffFrame` and `Blizzard_EditMode` files.
- Validation: `check_fast.ps1` passed on 2026-06-21.
- In-game: user verified Blizzard buff/debuff frame toggles restored correctly on 2026-06-21.


## CDM Mirroring Review
Completed: 2026-06-21

Reviewed whether public `C_CooldownViewer` APIs can replace LsTweeks' Blizzard Cooldown Manager viewer child reads and `CooldownViewerItemDataMixin` hooks in `modules/aura_frames/af_scan.lua`.

They cannot. Public APIs expose category cooldown IDs, static cooldown metadata, layout data, availability, and alert types. They do not expose live rendered child order, active aura instance IDs, per-item active state, target/player aura association, or cooldown widget timing.

Retail 12.0.7 source shows live state is held on viewer item frames through methods such as `GetAuraSpellInstanceID()`, `GetCooldownID()`, `GetCooldownInfo()`, and `GetSpellID()`. LsTweeks still needs the live child frame path for active aura display and cooldown fallback behavior.

Implementation result:

- No replacement with `C_CooldownViewer` was made.
- `af_scan.lua` now prefers Blizzard child mixin methods before fallback field reads: `GetAuraSpellInstanceID()`, `GetCooldownID()`, `GetCooldownInfo()`, and `GetSpellID()`.
- `CooldownViewerItemDataMixin` hooks remain necessary to attach cooldown-frame hooks lazily and queue refreshes when Blizzard item identity changes.

Durable rule: replace CDM viewer child reads/hooks with public `C_CooldownViewer` APIs only if Blizzard adds APIs for live rendered item state. Prefer child mixin methods over raw fields, and keep addon state in addon-owned weak tables.


## Profile Legacy Review
Completed: 2026-06-21

The remaining Aura Frames review item asked for testing profile load/reset behavior against saved profiles containing deleted or renamed custom frames.

Closed as not applicable for current project scope. The addon has a single user/developer workflow and there is no legacy saved-profile corpus to validate against. Block Aura Frames cleanup on profile migration cases only if real saved variables are found or profile storage is intentionally changed.

The existing implementation rule remains valid: if reset or profile load replaces `custom_frames`, remove orphan runtime frames and stale controls, then rebuild the Frames tree/content if present. Future changes to profile storage should test that path with synthetic profiles created for the change.
