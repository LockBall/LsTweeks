# Aura Tooltip Notes

Completed: 2026-05-30

## Decision

Treat `GameTooltip:SetUnitAuraByAuraInstanceID(...)` warnings as a Ketho/Core annotation gap, not a client-version bug.

## Durable Rule

Keep the runtime guard:

```lua
if not GameTooltip.SetUnitAuraByAuraInstanceID then return false end
```

Keep the existing spell tooltip fallback path.

## Evidence

Ketho/LuaLS does not expose `GameTooltip.SetUnitAuraByAuraInstanceID` on the core `GameTooltip` type, but Ketho FrameXML annotations show Blizzard using it in BuffFrame, CooldownViewer, and NamePlate aura code. FrameXML maps the tooltip handler to `GetUnitAuraByAuraInstanceID`.

Test by hovering addon aura icons/bars for active player buffs and debuffs. The test aura should still show a spell tooltip when no live aura tooltip is available.
