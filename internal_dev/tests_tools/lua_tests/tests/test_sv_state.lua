-- Behavioral tests for Skyriding Vigor charge detection (power normalization plus spell-charge
-- fallback) and the frame fade primitives with the full-charge fade policy.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")
local stub = h.stub

h.load_addon("modules/skyriding_vigor")
h.boot({})

local SV = h.addon.skyriding_vigor
local ALT_MOUNT_POWER = 25 -- Enum.PowerType.AlternateMount

local function reset_power()
    stub.power = {}
    stub.power_display_mod = 1
end

h.test("charge info scales raw power onto the six-slot bar", function()
    reset_power()
    stub.power[ALT_MOUNT_POWER] = { current = 100, max = 100 }
    local current, max_charges = SV.get_charge_info()
    h.eq(current, 6, "full power = 6 charges")
    h.eq(max_charges, 6, "max charges")

    stub.power[ALT_MOUNT_POWER] = { current = 50, max = 100 }
    current, max_charges = SV.get_charge_info()
    h.eq(current, 3, "half power = 3 charges")
    h.eq(max_charges, 6, "max unchanged")

    stub.power[ALT_MOUNT_POWER] = { current = 0, max = 100 }
    current = SV.get_charge_info()
    h.eq(current, 0, "empty power = 0 charges")
end)

h.test("display mod divides raw power before slotting", function()
    reset_power()
    stub.power_display_mod = 10
    stub.power[ALT_MOUNT_POWER] = { current = 40, max = 60 }
    local current, max_charges = SV.get_charge_info()
    h.eq(current, 4, "current divided by display mod")
    h.eq(max_charges, 6, "max divided by display mod")
end)

h.test("no power type reports nil charge info", function()
    reset_power()
    h.eq(select("#", SV.get_charge_info()), 4, "nil charge info return arity")
    local current, max_charges, start_time, duration = SV.get_charge_info()
    h.is_nil(current, "no vigor resource current charges")
    h.is_nil(max_charges, "no vigor resource max charges")
    h.is_nil(start_time, "no vigor resource cooldown start")
    h.is_nil(duration, "no vigor resource cooldown duration")
end)

h.test("spell-charge fallback keeps the six-node bar shape", function()
    reset_power()
    stub.spell_charges = {
        [372610] = { currentCharges = 2, maxCharges = 1, cooldownStartTime = 5, cooldownDuration = 10 },
    }
    local current, max_charges, start_time, duration = SV.get_charge_info()
    stub.spell_charges = nil
    h.eq(current, 2, "fallback current charges")
    h.eq(max_charges, 6, "fallback forces six slots despite maxCharges=1")
    h.eq(start_time, 5, "cooldown start passed through")
    h.eq(duration, 10, "cooldown duration passed through")
end)

h.test("secret charge timing and display values fall back safely", function()
    local secret_value = { __lstweeks_test_secret_value = true }
    reset_power()
    stub.power_display_mod = secret_value
    stub.power[ALT_MOUNT_POWER] = { current = 4, max = 6 }
    local current, max_charges = SV.get_charge_info()
    h.eq(current, 4, "secret display mod does not enter arithmetic")
    h.eq(max_charges, 6, "power path remains usable without a readable display mod")

    reset_power()
    stub.spell_charges = {
        [372610] = { currentCharges = 2, maxCharges = 1, cooldownStartTime = secret_value, cooldownDuration = secret_value },
    }
    local start_time, duration
    current, max_charges, start_time, duration = SV.get_charge_info()
    stub.spell_charges = nil
    h.eq(current, 2, "fallback current charges survive secret timing")
    h.eq(max_charges, 6, "fallback keeps six slots with secret timing")
    h.eq(start_time, 0, "secret cooldown start falls back to zero")
    h.eq(duration, 0, "secret cooldown duration falls back to zero")
end)

h.test("charge event bursts coalesce before the Skyriding refresh", function()
    local original_refresh = SV.refresh
    local refresh_count = 0
    SV.refresh = function()
        refresh_count = refresh_count + 1
    end

    h.fire_event("SPELL_UPDATE_CHARGES")
    h.fire_event("SPELL_UPDATE_COOLDOWN")

    h.eq(refresh_count, 0, "charge events defer the refresh")
    h.advance(h.addon.UPDATE_INTERVALS.skyriding_vigor_event_bucket)
    h.eq(refresh_count, 1, "charge event burst performs one refresh")
    SV.refresh = original_refresh
end)

h.test("Race Test control stays disabled while flight locks settings", function()
    local old_controls = SV.controls
    local old_lock_check = SV.is_settings_locked_by_flight
    local button = CreateFrame("Button")
    SV.controls = { race_profile_test_button = button }
    SV.is_settings_locked_by_flight = function() return true end

    SV.sync_race_profile_controls({ race_profile_enabled = true })

    h.ok(not button:IsEnabled(), "Race Test stays disabled during flight")
    SV.is_settings_locked_by_flight = function() return false end
    SV.sync_race_profile_controls({ race_profile_enabled = true })
    h.ok(button:IsEnabled(), "Race Test enables when flight lock clears")

    SV.controls = old_controls
    SV.is_settings_locked_by_flight = old_lock_check
end)

h.test("control-sync guards clear after a control error", function()
    local old_controls = SV.controls
    SV.controls = {
        spacing = {
            GetValue = function() return 0 end,
            SetValueSilently = function() error("slider sync failure") end,
        },
        x_position = {
            GetValue = function() return 0 end,
            SetValueSilently = function() error("position sync failure") end,
        },
    }

    local slider_ok = pcall(SV.sync_slider_controls, { spacing = 5 })
    h.ok(not slider_ok, "slider sync still reports control errors")
    h.is_nil(SV._syncing_slider_controls, "slider guard clears after an error")

    local position_ok = pcall(SV.sync_position_controls, { position = { x = 5 } })
    h.ok(not position_ok, "position sync still reports control errors")
    h.is_nil(SV._syncing_position_controls, "position guard clears after an error")

    SV.controls = old_controls
end)

h.test("fade_frame_alpha animates to target over the duration", function()
    local frame = CreateFrame("Frame")
    SV.set_frame_alpha(frame, 1)

    SV.fade_frame_alpha(frame, 0.25, 2)
    h.advance(1)
    local mid = frame:GetAlpha()
    h.ok(mid < 1 and mid > 0.25, "mid-fade alpha between endpoints, got " .. tostring(mid))

    h.advance(1.5)
    h.near(frame:GetAlpha(), 0.25, 0.001, "final alpha")
    h.is_nil(frame:GetScript("OnUpdate"), "OnUpdate removed after completion")
end)

h.test("repeating the same fade request does not restart the animation", function()
    local frame = CreateFrame("Frame")
    SV.set_frame_alpha(frame, 1)

    SV.fade_frame_alpha(frame, 0.25, 2)
    h.advance(1)
    local mid = frame:GetAlpha()

    SV.fade_frame_alpha(frame, 0.25, 2) -- identical signature: must be a no-op
    h.advance(0.5)
    local later = frame:GetAlpha()
    h.ok(later < mid, "fade continued from prior progress instead of restarting, got " .. tostring(later))
end)

h.test("fade driver remains independent from the frame drag callback", function()
    local frame = CreateFrame("Frame")
    SV.set_frame_alpha(frame, 1)
    SV.fade_frame_alpha(frame, 0.25, 2)

    frame:SetScript("OnUpdate", function() end)
    h.advance(1)

    h.ok(frame:GetAlpha() < 1 and frame:GetAlpha() > 0.25, "fade continues while the frame owns a drag callback")
    h.ok(frame._sv_fade_driver and frame._sv_fade_driver:GetScript("OnUpdate"), "fade uses a dedicated driver")
    SV.restore_frame_alpha(frame)
    h.is_nil(frame._sv_fade_driver:GetScript("OnUpdate"), "restore stops the dedicated fade driver")
end)

h.test("zero duration snaps and restore cancels a running fade", function()
    local frame = CreateFrame("Frame")
    SV.set_frame_alpha(frame, 1)

    SV.fade_frame_alpha(frame, 0.25, 0)
    h.near(frame:GetAlpha(), 0.25, 0.001, "instant snap")

    SV.fade_frame_alpha(frame, 1, 5)
    h.advance(1)
    SV.restore_frame_alpha(frame)
    h.near(frame:GetAlpha(), 1, 0.001, "restore forces full alpha")
    h.is_nil(frame:GetScript("OnUpdate"), "restore cancels the animation")
    h.advance(10)
    h.near(frame:GetAlpha(), 1, 0.001, "no stale animation after restore")
end)

h.test("full-charge fade policy: fades only when full, idle, and not in move mode", function()
    local frame = CreateFrame("Frame")
    local db = { fade_when_full = true, fade_alpha = 0.25, fade_length = 1, move_mode = false }
    SV._fill_test_enabled = nil

    SV.set_frame_alpha(frame, 1)
    SV.apply_full_charge_fade(frame, db, true, false)
    h.advance(2)
    h.near(frame:GetAlpha(), 0.25, 0.001, "faded at full charges while idle")

    SV.apply_full_charge_fade(frame, db, true, true)
    h.near(frame:GetAlpha(), 1, 0.001, "restored during active flight")

    SV.apply_full_charge_fade(frame, db, false, false)
    h.near(frame:GetAlpha(), 1, 0.001, "no fade while charges regenerate")

    db.move_mode = true
    SV.apply_full_charge_fade(frame, db, true, false)
    h.near(frame:GetAlpha(), 1, 0.001, "no fade in move mode")

    db.move_mode = false
    db.fade_when_full = false
    SV.apply_full_charge_fade(frame, db, true, false)
    h.near(frame:GetAlpha(), 1, 0.001, "no fade when setting disabled")
end)

h.run("sv_state")

--#endregion FILE CONTENTS ===================================================
