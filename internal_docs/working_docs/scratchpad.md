# Scratchpad

Temporary working notes only. Move durable architecture, defaults, API lessons, and completed-feature notes to `proj_mem/project.md`, the relevant `proj_mem/` module file, `README.md`, or `internal_docs/completed_features/` as appropriate.


## Skyriding Vigor Race Timer Probe

Need in-game verification before wiring race-specific behavior. There does not appear to be a dedicated `C_SkyridingRace.IsActive()` style API in local Ketho annotations. Race POI APIs exist (`C_AreaPoiInfo.GetDragonridingRacesForMap(uiMapID)`), but those only describe map pins.

Likely better runtime signal: race timer via world elapsed timers and/or scenario header timer widgets.

Probe during a Skyriding race:

```lua
/run for _, id in ipairs({GetWorldElapsedTimers()}) do local name, elapsed, timerType = GetWorldElapsedTime(id); print("world timer", id, name, elapsed, timerType) end
```

Also probe mirror timers, though they are less likely:

```lua
/run for i=1,3 do local timer,value,maxvalue,scale,paused,label = GetMirrorTimerInfo(i); print("mirror", i, timer, value, maxvalue, scale, paused, label) end
```

If world elapsed timer output is stable, add a helper in `sv_main.lua` similar to `is_skyriding_race_timer_active()`. Match by observed timer type/name only after capturing real race output. Blizzard FrameXML references `GetWorldElapsedTimers()` / `GetWorldElapsedTime(timerID)` in the Scenario Objective Tracker and checks `Enum.WorldElapsedTimerTypes.ChallengeMode` / `ProvingGround`; Skyriding may use one of those or another returned value.
