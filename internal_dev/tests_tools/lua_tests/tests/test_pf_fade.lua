-- Behavioral tests for the Player Frame out-of-combat fade state machine, replaying the
-- combat/delay/fade/health-gate sequences that previously required manual in-game checks.


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

local function reset_runtime()
    stub.in_combat = false
    stub.player_health_percent = 1
    F.stop_transition()
    PlayerFrame:SetAlpha(1)
end

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
