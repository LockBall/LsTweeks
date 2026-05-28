# Review Notes

Durable notes for review findings that were evaluated manually and do not require addon code changes.

## Aura Frames

- `modules/aura_frames/af_main.lua:207`: Ketho/LuaLS does not expose `GameTooltip.SetUnitAuraByAuraInstanceID` on the core `GameTooltip` type, but Ketho FrameXML annotations show Blizzard using `GameTooltip:SetUnitAuraByAuraInstanceID(...)` in BuffFrame, CooldownViewer, and NamePlate aura code. FrameXML also maps the tooltip handler to `GetUnitAuraByAuraInstanceID`.

  - Decision: treat this as a Ketho/Core annotation gap, not a client-version bug.

  - Runtime guard: keep `if not GameTooltip.SetUnitAuraByAuraInstanceID then return false end`.

  - Fallback: keep the existing spell tooltip fallback path.

  - Test: hover addon aura icons/bars for active player buffs and debuffs and confirm aura tooltips show; also verify the test aura still shows a spell tooltip when no live aura tooltip is available.

## Sound Levels

- `modules/sound_levels/sl_gui.lua`: Ketho/LuaLS reports type warnings around `MinimalSliderWithSteppersTemplate` frames passed to mixin-style methods such as `Init`, `RegisterCallback`, and `SetValue`.

  - Decision: treat this as a Ketho/LuaLS template-mixin inference limitation unless in-game slider behavior regresses.

  - Runtime status: the customized Sound Levels sliders have been tested in-game and work as intended.
