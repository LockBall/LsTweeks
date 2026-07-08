-- Behavioral tests for the Player Frame out-of-combat fade state machine, replaying the
-- combat/delay/fade/health-gate sequences that previously required manual in-game checks.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local stub = h.stub

h.load_addon("modules/player_frame")

local function fresh_db(overrides)
    local db = {
        fade_out_of_combat = true,
        fade_alpha = 0.5,
        fade_delay = 2.0,
        fade_length = 5.0,
        health_visible_threshold = 0, -- gate off unless a test opts in
        health_release_speed = 75,
    }
    for k, v in pairs(overrides or {}) do db[k] = v end
    Ls_Tweeks_DB = { player_frame = db, modules = { player_frame = true } }
    return db
end

local F = h.addon.player_frame.fade
local M = h.addon.player_frame

local function reset_runtime()
    stub.in_combat = false
    stub.player_health_percent = 1
    F.stop_transition()
    PlayerFrame:SetAlpha(1)
end

h.test("fade settings clamp through centralized ranges", function()
    for key, range in pairs(M.FADE_SETTING_RANGES) do
        local low_db = { [key] = range.min - 1000 }
        local high_db = { [key] = range.max + 1000 }
        h.eq(M.get_clamped_fade_value(low_db, key), range.min, key .. " lower clamp")
        h.eq(M.get_clamped_fade_value(high_db, key), range.max, key .. " upper clamp")
    end
end)

h.test("fade sliders use centralized ranges", function()
    fresh_db()
    local parent = CreateFrame("Frame", nil, UIParent)
    M.build_options_panel(parent)

    local controls = {
        fade_alpha = "fade_alpha_slider",
        fade_delay = "fade_delay_slider",
        fade_length = "fade_length_slider",
        health_visible_threshold = "health_visible_threshold_slider",
        health_release_speed = "health_release_speed_slider",
    }

    for key, control_key in pairs(controls) do
        local control = M.controls[control_key]
        h.ok(control and control.slider, key .. " slider exists")
        local lo, hi = control.slider:GetMinMaxValues()
        h.eq(lo, M.FADE_SETTING_RANGES[key].min, key .. " slider min")
        h.eq(hi, M.FADE_SETTING_RANGES[key].max, key .. " slider max")
    end
end)

h.test("truthy fade setting registers fade events", function()
    fresh_db({ fade_out_of_combat = 1 })
    reset_runtime()

    M.update_player_frame()
    local status = h.addon.module_status_builders.player_frame()
    h.ok(tContains(status, "fade_events=true"), "truthy fade setting should register fade events")
end)

h.test("leaving combat waits fade_delay then fades to fade_alpha over fade_length", function()
    local db = fresh_db()
    reset_runtime()

    F.on_leave_combat(db)
    h.eq(F.get_runtime_status().state, "delay", "state after leaving combat")
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "alpha during delay")

    h.advance(2.0)
    h.eq(F.get_runtime_status().state, "fading", "state after delay expires")

    h.advance(2.5)
    local mid = PlayerFrame:GetAlpha()
    h.ok(mid < 1 and mid > 0.5, "alpha mid-fade should be between targets, got " .. tostring(mid))

    h.advance(3.0)
    h.eq(F.get_runtime_status().state, "faded", "state after fade completes")
    h.near(PlayerFrame:GetAlpha(), 0.5, 0.011, "final faded alpha")
    h.eq(F.get_runtime_status().fade_ticker, false, "ticker cancelled after completion")
end)

h.test("zero fade_length snaps immediately to fade_alpha after the delay", function()
    local db = fresh_db({ fade_length = 0, fade_delay = 1 })
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(1.0)
    h.eq(F.get_runtime_status().state, "faded", "instant fade state")
    h.near(PlayerFrame:GetAlpha(), 0.5, 0.001, "instant fade alpha")
end)

h.test("entering combat mid-fade restores full alpha and cancels timers", function()
    local db = fresh_db()
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(3.0) -- 1s into the fade
    h.eq(F.get_runtime_status().state, "fading", "mid-fade")

    stub.in_combat = true
    F.on_enter_combat()
    h.eq(F.get_runtime_status().state, "combat", "combat state")
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "alpha restored in combat")
    h.eq(F.get_runtime_status().fade_ticker, false, "ticker cancelled")
    h.eq(F.get_runtime_status().fade_delay_timer, false, "delay timer cancelled")

    h.advance(20)
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "no stale timer fades during combat")
end)

h.test("fade disabled in settings leaves frame at full alpha", function()
    local db = fresh_db({ fade_out_of_combat = false })
    reset_runtime()

    F.on_leave_combat(db)
    h.eq(F.get_runtime_status().state, "idle", "idle when disabled")
    h.advance(20)
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "alpha stays 1 when disabled")
end)

h.test("health gate: low health keeps faded frame visible, full health releases it", function()
    local db = fresh_db({ health_visible_threshold = 80, fade_length = 1, fade_delay = 0 })
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(2.0)
    h.eq(F.get_runtime_status().state, "faded", "faded at full health")
    h.near(PlayerFrame:GetAlpha(), 0.5, 0.011, "fully faded at 100% health")

    stub.player_health_percent = 0.30 -- below 80% threshold release band start
    F.on_health_update(db)
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "frame forced visible at low health")

    stub.player_health_percent = 1
    F.on_health_update(db)
    h.near(PlayerFrame:GetAlpha(), 0.5, 0.011, "re-faded at full health")
end)

h.test("health updates are debounced through queue_health_update", function()
    local db = fresh_db({ health_visible_threshold = 80, fade_length = 1, fade_delay = 0 })
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(2.0)

    stub.player_health_percent = 0.30
    F.queue_health_update(function() return db end)
    h.ok(F.get_runtime_status().queued_health_timer, "debounce timer pending")
    h.advance(0.2)
    h.eq(F.get_runtime_status().queued_health_timer, false, "debounce timer fired")
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "debounced health update applied")
end)

h.test("health update debounce only queues while faded with health gate enabled", function()
    local db = fresh_db({ health_visible_threshold = 80 })
    reset_runtime()

    F.on_leave_combat(db)
    h.eq(F.get_runtime_status().state, "delay", "delay state")
    F.queue_health_update(function() return db end)
    h.eq(F.get_runtime_status().queued_health_timer, false, "no debounce while delayed")

    h.advance(3.0)
    h.eq(F.get_runtime_status().state, "fading", "fading state")
    F.queue_health_update(function() return db end)
    h.eq(F.get_runtime_status().queued_health_timer, false, "no debounce while fading")

    h.advance(5.0)
    h.eq(F.get_runtime_status().state, "faded", "faded state")
    F.queue_health_update(function() return db end)
    h.ok(F.get_runtime_status().queued_health_timer, "debounce while faded")
    h.advance(0.2)

    db.health_visible_threshold = 0
    F.queue_health_update(function() return db end)
    h.eq(F.get_runtime_status().queued_health_timer, false, "no debounce when health gate disabled")
end)

h.test("refresh while faded skips no-op fade ticker", function()
    local db = fresh_db({ fade_delay = 0, fade_length = 5 })
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(6.0)
    h.eq(F.get_runtime_status().state, "faded", "precondition: faded")

    M.update_player_frame()
    h.advance(0)
    h.eq(F.get_runtime_status().state, "faded", "still faded after refresh")
    h.eq(F.get_runtime_status().fade_ticker, false, "no no-op ticker started")
end)

h.test("slider change mid-fade retargets to the new value", function()
    local db = fresh_db({ fade_alpha = 0.5 })
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(4.0) -- mid-fade
    db.fade_alpha = 0.2
    F.on_fade_setting_changed(db, "fade_alpha")
    h.advance(10)
    h.eq(F.get_runtime_status().state, "faded", "fade restarted and completed")
    h.near(PlayerFrame:GetAlpha(), 0.2, 0.011, "faded to the new slider value")
end)

h.test("slider change while combat re-entered restores combat state, not a fade", function()
    local db = fresh_db()
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(3.0) -- mid-fade
    stub.in_combat = true -- combat began but event not yet processed
    F.on_fade_setting_changed(db, "fade_length")
    h.eq(F.get_runtime_status().state, "combat", "combat detected during setting change")
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "alpha restored")
end)

h.test("slider change while delayed and combat re-entered restores combat state", function()
    local db = fresh_db()
    reset_runtime()

    F.on_leave_combat(db)
    h.eq(F.get_runtime_status().state, "delay", "precondition: delay state")

    stub.in_combat = true -- combat began but event not yet processed
    F.on_fade_setting_changed(db, "fade_alpha")
    h.eq(F.get_runtime_status().state, "combat", "combat detected during delayed setting change")
    h.eq(F.get_runtime_status().fade_delay_timer, false, "delay timer cancelled")
    h.near(PlayerFrame:GetAlpha(), 1, 0.001, "alpha restored")
end)

h.test("threshold change while faded requeues an apply pass", function()
    local db = fresh_db({ fade_delay = 0, fade_length = 1 })
    reset_runtime()

    F.on_leave_combat(db)
    h.advance(2.0)
    h.eq(F.get_runtime_status().state, "faded", "precondition: faded")

    db.health_visible_threshold = 50
    F.on_threshold_changed(db)
    h.advance(5)
    h.eq(F.get_runtime_status().state, "faded", "re-applied fade after threshold change")
end)

h.test("no timers leak after a full cycle", function()
    local db = fresh_db()
    reset_runtime()
    h.advance(30) -- flush anything pending
    local baseline = stub.ActiveTimerCount()

    F.on_leave_combat(db)
    h.advance(30)
    stub.in_combat = true
    F.on_enter_combat()
    stub.in_combat = false
    F.on_leave_combat(db)
    h.advance(30)

    h.eq(stub.ActiveTimerCount(), baseline, "active timer count returns to baseline")
end)

h.run("pf_fade")

--#endregion FILE CONTENTS ===================================================
