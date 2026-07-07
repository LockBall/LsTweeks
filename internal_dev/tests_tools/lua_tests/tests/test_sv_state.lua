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
    h.is_nil(SV.get_charge_info(), "no vigor resource, no spell-charge fallback data")
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
