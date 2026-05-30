# Sound Levels Notes

Date: 2026-05-30

## LuaLS/Ketho Finding

`modules/sound_levels/sl_gui.lua` can report type warnings around
`MinimalSliderWithSteppersTemplate` frames passed to mixin-style methods such as
`Init`, `RegisterCallback`, and `SetValue`.

## Decision

Treat this as a Ketho/LuaLS template-mixin inference limitation unless in-game
slider behavior regresses.

## Runtime Status

The customized Sound Levels sliders have been tested in-game and work as intended.
