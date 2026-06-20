# Aura Tooltip Notes

Date: 2026-05-30


## LuaLS/Ketho Finding

`modules/aura_frames/af_main.lua` uses `GameTooltip:SetUnitAuraByAuraInstanceID(...)`.
Ketho/LuaLS does not expose `GameTooltip.SetUnitAuraByAuraInstanceID` on the core
`GameTooltip` type, but Ketho FrameXML annotations show Blizzard using
`GameTooltip:SetUnitAuraByAuraInstanceID(...)` in BuffFrame, CooldownViewer, and
NamePlate aura code. FrameXML also maps the tooltip handler to
`GetUnitAuraByAuraInstanceID`.


## Decision

Treat this as a Ketho/Core annotation gap, not a client-version bug.

Keep the runtime guard:

```lua
if not GameTooltip.SetUnitAuraByAuraInstanceID then return false end
```

Keep the existing spell tooltip fallback path.


## Test Notes

Hover addon aura icons/bars for active player buffs and debuffs and confirm aura
tooltips show. Also verify the test aura still shows a spell tooltip when no live
aura tooltip is available.
