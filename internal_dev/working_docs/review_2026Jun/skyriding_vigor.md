1. Priority: High | Impact: High | Change Risk: Medium - Verify passenger/ridealong state, its the remaining runtime case for the `sv_state.lua` visibility path.

2. Priority: Medium | Impact: Medium | Change Risk: Medium - Tune spark visuals in game for Default and Storm Race styles. Confirm the spark sits on the fill edge without clipping or overpowering custom fill colors, and decide whether Spark Size max `10.00` should stay broad or be narrowed.

3. Priority: Medium | Impact: Medium | Change Risk: Medium - Probe Skyriding race timer state before wiring race-specific behavior. Local Ketho annotations do not show a dedicated `C_SkyridingRace.IsActive()` style API; race POI APIs such as `C_AreaPoiInfo.GetDragonridingRacesForMap(uiMapID)` only describe map pins.

   Likely runtime signals are world elapsed timers and/or scenario header timer widgets. Probe during a Skyriding race:

   ```lua
   /run for _, id in ipairs({GetWorldElapsedTimers()}) do local name, elapsed, timerType = GetWorldElapsedTime(id); print("world timer", id, name, elapsed, timerType) end
   ```

   Also probe mirror timers, though they are less likely:

   ```lua
   /run for i=1,3 do local timer,value,maxvalue,scale,paused,label = GetMirrorTimerInfo(i); print("mirror", i, timer, value, maxvalue, scale, paused, label) end
   ```

   If world elapsed timer output is stable, add a helper in `sv_main.lua` similar to `is_skyriding_race_timer_active()`. Match by observed timer type/name only after capturing real race output. Blizzard FrameXML references `GetWorldElapsedTimers()` / `GetWorldElapsedTime(timerID)` in the Scenario Objective Tracker and checks `Enum.WorldElapsedTimerTypes.ChallengeMode` / `ProvingGround`; Skyriding may use one of those or another returned value.
