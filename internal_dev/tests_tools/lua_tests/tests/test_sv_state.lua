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

h.test("spark color normalization clamps saved components", function()
    local root_db = SV.get_root_db()
    local old_color = root_db.spark_color
    root_db.spark_color = { r = -1, g = 2, b = "0.5", a = 99 }
    SV._db_normalized = false

    SV.get_root_db()

    h.eq(root_db.spark_color.r, 0, "red clamps to zero")
    h.eq(root_db.spark_color.g, 1, "green clamps to one")
    h.eq(root_db.spark_color.b, 0.5, "blue keeps valid numeric text")
    h.eq(root_db.spark_color.a, 1, "alpha clamps to one")

    root_db.spark_color = old_color
    SV._db_normalized = false
    SV.get_root_db()
end)

h.test("style fill color normalization clamps saved components", function()
    local root_db = SV.get_root_db()
    local layout = SV.get_style_layout_table(root_db, root_db.style, true)
    local old_color = layout.fill_color
    layout.fill_color = { r = -1, g = 2, b = "0.5", a = 9 }

    local color = SV.get_style_fill_color()
    h.eq(color.r, 0, "fill red clamps to zero")
    h.eq(color.g, 1, "fill green clamps to one")
    h.eq(color.b, 0.5, "fill blue coerces to a number")
    h.eq(color.a, 1, "fill alpha clamps to one")

    layout.fill_color = old_color
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

h.test("race events refresh only when race state changes", function()
    local root_db = SV.get_root_db()
    local original_refresh = SV.refresh
    local previous_enabled = root_db.race_profile_enabled
    local refresh_count = 0
    stub.item_counts[191140] = 0
    SV._race_active = false
    SV.set_race_profile_enabled(true)
    SV.refresh = function()
        refresh_count = refresh_count + 1
    end

    h.fire_event("QUEST_LOG_UPDATE")
    h.eq(refresh_count, 0, "unchanged race event skips refresh")

    stub.item_counts[191140] = 1
    h.fire_event("QUEST_LOG_UPDATE")
    h.eq(refresh_count, 1, "race state transition refreshes")

    SV.refresh = original_refresh
    stub.item_counts[191140] = 0
    SV.set_race_profile_enabled(previous_enabled)
end)

h.test("vehicle events refresh only for the player unit", function()
    local original_refresh = SV.refresh
    local refresh_count = 0
    SV.refresh = function()
        refresh_count = refresh_count + 1
    end

    h.fire_event("UNIT_ENTERED_VEHICLE", "party1")
    h.eq(refresh_count, 0, "other unit vehicle event is ignored")
    h.fire_event("UNIT_ENTERED_VEHICLE", "player")
    h.eq(refresh_count, 1, "player vehicle event refreshes")

    SV.refresh = original_refresh
end)

h.test("visibility gate skips charges only outside valid vigor states", function()
    local root_db = SV.get_root_db()
    local original_enabled = root_db.enabled
    local original_move_mode = root_db.move_mode
    local original_gliding_state = SV.get_gliding_state
    local original_charge_info = SV.get_charge_info
    local original_is_flying = SV.is_player_flying
    local original_is_mounted = SV.is_mounted_in_advanced_flyable_area
    local charge_reads = 0

    root_db.enabled = true
    root_db.move_mode = false
    SV._fill_test_enabled = nil
    SV.get_charge_info = function()
        charge_reads = charge_reads + 1
        return 6, 6, 0, 0
    end
    rawset(SV, "get_gliding_state", function() return false, false end)
    SV.refresh()
    h.eq(charge_reads, 0, "normal non-vigor state skips charge reads")

    rawset(SV, "get_gliding_state", function() return false, true end)
    SV.is_player_flying = function() return false end
    SV.is_mounted_in_advanced_flyable_area = function() return true end
    SV.refresh()
    h.eq(charge_reads, 1, "grounded vigor mount still reads charges")

    root_db.enabled = original_enabled
    root_db.move_mode = original_move_mode
    SV.get_gliding_state = original_gliding_state
    SV.get_charge_info = original_charge_info
    SV.is_player_flying = original_is_flying
    SV.is_mounted_in_advanced_flyable_area = original_is_mounted
end)

h.test("render context reuses stable style resolution and invalidates with layout", function()
    local db = SV.get_db()
    local original_frame_atlas = SV.get_frame_atlas
    local frame_atlas_reads = 0
    SV.get_frame_atlas = function(...)
        frame_atlas_reads = frame_atlas_reads + 1
        return original_frame_atlas(...)
    end
    SV.invalidate_render_context()

    local first = SV.get_render_context(db)
    local second = SV.get_render_context(db)
    h.eq(first, second, "stable refreshes reuse the same render context")
    h.eq(frame_atlas_reads, 1, "stable refreshes resolve frame atlas once")

    SV.invalidate_layout()
    local third = SV.get_render_context(db)
    h.ok(third ~= first, "layout invalidation rebuilds render context")
    h.eq(frame_atlas_reads, 2, "layout invalidation resolves the atlas again")

    SV.get_frame_atlas = original_frame_atlas
    SV.invalidate_render_context()
end)

h.test("Race Test control stays disabled while flight locks settings", function()
    local old_controls = SV.controls
    local old_lock_check = SV.is_settings_locked_by_flight
    local button = CreateFrame("Button")
    SV.controls = { race_profile_test_button = button }
    rawset(SV, "is_settings_locked_by_flight", function() return true end)

    SV.sync_race_profile_controls({ race_profile_enabled = true })

    h.ok(not button:IsEnabled(), "Race Test stays disabled during flight")
    rawset(SV, "is_settings_locked_by_flight", function() return false end)
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

h.test("settings flight-lock sync skips unchanged control writes", function()
    local old_controls = SV.controls
    local old_flight_controls = SV.flight_locked_controls
    local old_lock_check = SV.is_settings_locked_by_flight
    local old_cached_lock = SV._settings_controls_flight_locked
    local writes = 0
    local control = {
        SetEnabled = function(_, _enabled)
            writes = writes + 1
        end,
    }
    SV.controls = {}
    SV.flight_locked_controls = { { control = control } }
    SV._settings_controls_flight_locked = nil
    rawset(SV, "is_settings_locked_by_flight", function() return false end)

    SV.sync_settings_controls_enabled()
    SV.sync_settings_controls_enabled()
    h.eq(writes, 1, "unchanged flight state skips repeated control writes")

    rawset(SV, "is_settings_locked_by_flight", function() return true end)
    SV.sync_settings_controls_enabled()
    h.eq(writes, 2, "flight-lock change resynchronizes controls")
    SV.sync_settings_controls_enabled(true)
    h.eq(writes, 3, "forced sync refreshes rebuilt controls")

    SV.controls = old_controls
    SV.flight_locked_controls = old_flight_controls
    SV.is_settings_locked_by_flight = old_lock_check
    SV._settings_controls_flight_locked = old_cached_lock
end)

h.test("style control sync retains the registered flight lock", function()
    local old_controls = SV.controls
    local old_flight_controls = SV.flight_locked_controls
    local old_lock_check = SV.is_settings_locked_by_flight
    local old_get_node_color = SV.get_node_color
    local old_get_decor_color = SV.get_decor_color
    local node_enabled = nil
    local decor_enabled = nil
    local node = {
        SetValue = function() end,
        SetEnabled = function(_, enabled) node_enabled = enabled end,
    }
    local decor = {
        SetValue = function() end,
        SetEnabled = function(_, enabled) decor_enabled = enabled end,
    }

    SV.controls = { node_color = node, decor_color = decor }
    SV.flight_locked_controls = {
        { control = node, is_enabled = function() return true end },
        { control = decor, is_enabled = function() return true end },
    }
    SV.get_node_color = function() return "default" end
    SV.get_decor_color = function() return "default" end
    SV.is_settings_locked_by_flight = function() return true end

    SV.sync_node_color_controls()
    SV.sync_decor_color_controls()
    h.ok(node_enabled == false, "node color stays disabled while flight-locked")
    h.ok(decor_enabled == false, "decor color stays disabled while flight-locked")

    SV.controls = old_controls
    SV.flight_locked_controls = old_flight_controls
    SV.is_settings_locked_by_flight = old_lock_check
    SV.get_node_color = old_get_node_color
    SV.get_decor_color = old_get_decor_color
end)

h.test("visual scale sliders apply each drag value once without debounce", function()
    local old_controls = SV.controls
    local old_flight_controls = SV.flight_locked_controls
    local old_settings_grid = SV.settings_grid
    local old_controls_parent = SV.controls_parent
    local old_set_db_value = SV.set_db_value
    local old_set_decor_scale = SV.set_decor_scale
    local scale_calls = 0
    local decor_scale_calls = 0

    SV.BuildVigorTab(CreateFrame("Frame"))
    SV.set_db_value = function(key)
        if key == "scale" then scale_calls = scale_calls + 1 end
    end
    SV.set_decor_scale = function()
        decor_scale_calls = decor_scale_calls + 1
    end

    local timers_before = stub.ActiveTimerCount()
    SV.controls.scale.slider.__scripts.OnValueChanged(SV.controls.scale.slider, 1.1)
    SV.controls.decor_scale.slider.__scripts.OnValueChanged(SV.controls.decor_scale.slider, 1.1)

    h.eq(scale_calls, 1, "Vigor scale callback applies immediately")
    h.eq(decor_scale_calls, 1, "decor proxy applies scale without a duplicate callback")
    h.eq(stub.ActiveTimerCount(), timers_before, "visual scale drags do not queue debounce timers")

    SV.controls = old_controls
    SV.flight_locked_controls = old_flight_controls
    SV.settings_grid = old_settings_grid
    SV.controls_parent = old_controls_parent
    SV.set_db_value = old_set_db_value
    SV.set_decor_scale = old_set_decor_scale
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
