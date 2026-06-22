# Aura Cancel Notes

Completed: 2026-05-26

## Decision

Aura cancellation is supported only out of combat, only for real cancelable player buffs, and only when the configured modifier key is held (`OFF`, `CTRL`, `ALT`, or `SHIFT`). Do not add in-combat cancel support without a secure-button redesign.

## Implementation Rules

- Addon aura icons are plain frames, not secure aura buttons.
- Never pass `obj.aura_index` directly to `CancelUnitBuff`; in LsTweeks it stores `auraInstanceID`, while `CancelUnitBuff("player", index, filter)` requires the current positional buff index.
- On click, reject cheaply first: feature off, combat lockdown, wrong modifier, nonnumeric aura identity, test preview, spell cooldown, disallowed frame/source.
- Allowed sources are preset `static` and `long` buff frames, plus custom frames when the clicked icon resolves to a current cancelable player buff.
- Treat a fresh `C_UnitAuras.GetBuffDataByIndex("player", i, "HELPFUL|CANCELABLE")` scan as authoritative. Cancel only when the scan finds the clicked `auraInstanceID`.
- Ignore unsupported states silently.
- Queue a normal aura refresh after a successful cancel attempt.

## Source Findings

- `CancelUnitBuff` is restricted and `#nocombat`; name/rank cancellation was removed in patch 8.0.1.
- Secure templates support modifier attributes (`shift-`, `ctrl-`, `alt-`) and `cancelaura`, but combat-safe support would require secure action buttons and careful out-of-combat attribute updates.
- `SecureAuraButtonTemplate` uses right-click `type2 = cancelaura`.
- The `CANCELABLE` aura filter is the reliable way to identify buffs that can be cancelled.

Useful references if this is revisited:

- https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate
- https://warcraft.wiki.gg/wiki/API_CancelUnitBuff
- https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetBuffDataByIndex
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.xml

## Non-Goals

- In-combat cancellation.
- Debuff cancellation.
- Preset short-buff cancellation unless intentionally changed later.
- CDM/cooldown-viewer entries unless backed by a real cancelable player buff.
- Global keyboard-only cancellation flow.
