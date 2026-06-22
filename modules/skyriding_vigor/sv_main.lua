-- Skyriding Vigor runtime: events, visibility decisions, DB normalization, and settings hooks.
-- Visual bar construction and layout live in sv_bar.lua.
-- Alpha fade helpers live in sv_fade.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local CreateFrame = CreateFrame
local GetTime = GetTime
local floor = math.floor
local max = math.max
local min = math.min
local ipairs = ipairs
local tonumber = tonumber

local FILL_TEST_NODE_SECONDS = 2.0
local RUNTIME_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_CAN_GLIDE_CHANGED",
    "PLAYER_IS_GLIDING_CHANGED",
    "SPELL_UPDATE_CHARGES",
    "SPELL_UPDATE_COOLDOWN",
    "MOUNT_JOURNAL_USABILITY_CHANGED",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "VEHICLE_UPDATE",
}


--#region SETTINGS AND DEFAULTS ================================================
-- Module metadata and default values shared by runtime and settings code.
local DEFAULTS = addon.module_defaults and addon.module_defaults.sv and addon.module_defaults.sv.skyriding_vigor or {}
local SETTING_SPECS = M.SETTING_SPECS
M.MODULE_KEY = "skyriding_vigor"
M.CATEGORY_NAME = "Skyriding Vigor"
M.DEFAULTS = DEFAULTS
--#endregion SETTINGS AND DEFAULTS =============================================


--#region RUNTIME EVENT AND UPDATE FRAMES ======================================
-- Hidden frames that own event dispatch and active-only progress updates.
local loader = CreateFrame("Frame")
local progress_driver = CreateFrame("Frame")
progress_driver:Hide()
--#endregion RUNTIME EVENT AND UPDATE FRAMES ===================================


--#region DATABASE =============================================================
-- Saved-variable access, normalization, and compatibility cleanup.
local function clamp_number(value, fallback, spec)
    value = tonumber(value)
    if not value then value = fallback end
    if spec and value < spec.min then return spec.min end
    if spec and value > spec.max then return spec.max end
    return value
end

local function color_matches(color, r, g, b, a)
    if type(color) ~= "table" then return false end
    return color.r == r and color.g == g and color.b == b and (color.a or 1) == (a or 1)
end

local function normalize_db(db)
    if not db then return end

    db.scale = clamp_number(db.scale, DEFAULTS.scale or 1, SETTING_SPECS.scale)
    db.spacing = clamp_number(db.spacing, DEFAULTS.spacing or 5, SETTING_SPECS.spacing)
    db.fade_alpha = clamp_number(db.fade_alpha, DEFAULTS.fade_alpha or 0.25, SETTING_SPECS.fade_alpha)
    db.fade_length = clamp_number(db.fade_length, DEFAULTS.fade_length or 3, SETTING_SPECS.fade_length)
    db.spark_size = clamp_number(db.spark_size, DEFAULTS.spark_size or 1, SETTING_SPECS.spark_size)
    db.progress_update_hz = clamp_number(db.progress_update_hz, DEFAULTS.progress_update_hz or 20, SETTING_SPECS.progress_update_hz)
    if type(db.spark_color) ~= "table" then
        local color = DEFAULTS.spark_color or { r = 1, g = 1, b = 1, a = 1 }
        db.spark_color = { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = color.a or 1 }
    end
    db.spark_color.r = clamp_number(db.spark_color.r, DEFAULTS.spark_color and DEFAULTS.spark_color.r or 1)
    db.spark_color.g = clamp_number(db.spark_color.g, DEFAULTS.spark_color and DEFAULTS.spark_color.g or 1)
    db.spark_color.b = clamp_number(db.spark_color.b, DEFAULTS.spark_color and DEFAULTS.spark_color.b or 1)
    db.spark_color.a = clamp_number(db.spark_color.a, DEFAULTS.spark_color and DEFAULTS.spark_color.a or 1)
    if M.get_valid_bar_style_key then
        db.style = M.get_valid_bar_style_key(db.style or DEFAULTS.style or M.BAR_STYLE_DEFAULT)
    else
        db.style = db.style or DEFAULTS.style or "default"
    end
    if M.get_style_layout_table then
        local default_style_layout = M.get_style_layout_table(db, M.BAR_STYLE_DEFAULT or "default", true)
        if default_style_layout and (
            color_matches(default_style_layout.fill_color, 1, 1, 1, 1)
            or color_matches(default_style_layout.fill_color, 0.20, 0.82, 1.00, 1)
        ) then
            default_style_layout.fill_color = M.get_style_layout_default(M.BAR_STYLE_DEFAULT or "default", "fill_color")
        end

        local style_layout = M.get_style_layout_table(db, db.style, true, db.scale)
        if style_layout then
            style_layout.scale = clamp_number(style_layout.scale, db.scale or DEFAULTS.scale or 1, SETTING_SPECS.scale)
            local fill_add_default = M.get_style_layout_default and M.get_style_layout_default(db.style, "fill_add_alpha") or 0.18
            style_layout.fill_add_alpha = clamp_number(style_layout.fill_add_alpha, fill_add_default, SETTING_SPECS.fill_add_alpha)
        end
    end
    if M.get_valid_decor_style_key then
        db.decor_style = M.get_valid_decor_style_key(db.decor_style or DEFAULTS.decor_style or M.DECOR_STYLE_DEFAULT)
    else
        db.decor_style = db.decor_style or DEFAULTS.decor_style or "default"
    end
    if M.get_decor_layout_table then
        local decor_layout = M.get_decor_layout_table(db, db.decor_style, true)
        if decor_layout then
            local decor_scale_default = M.get_decor_layout_default and M.get_decor_layout_default(db.decor_style, "scale") or 1
            decor_layout.scale = clamp_number(decor_layout.scale, decor_scale_default, SETTING_SPECS.decor_scale)
        end
    end
    db.position = db.position or {}
    db.position.x = clamp_number(db.position.x, DEFAULTS.position and DEFAULTS.position.x or 0, SETTING_SPECS.x_position)
    db.position.y = clamp_number(db.position.y, DEFAULTS.position and DEFAULTS.position.y or 0, SETTING_SPECS.y_position)
    db.position.point = "CENTER"
    db.position.relativePoint = "CENTER"
end

local function get_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.skyriding_vigor = Ls_Tweeks_DB.skyriding_vigor or {}
    if not M._defaults_applied then
        addon.apply_defaults(addon.module_defaults and addon.module_defaults.sv or {}, Ls_Tweeks_DB)
        M._defaults_applied = true
        M._db_normalized = false
    end
    local db = Ls_Tweeks_DB.skyriding_vigor
    if M._db ~= db then
        M._db = db
        M._db_normalized = false
    end
    if not M._db_normalized then
        normalize_db(db)
        M._db_normalized = true
    end
    return db
end

M.get_db = get_db
--#endregion DATABASE ==========================================================


--#region RUNTIME LIFECYCLE ====================================================
-- Start/stop helpers for module-owned events, frame visibility, and update work.
function M.is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(M.MODULE_KEY)
end

local function stop_progress_driver()
    progress_driver:SetScript("OnUpdate", nil)
    progress_driver:Hide()
    M._progress_slot_index = nil
    M._progress_start_time = nil
    M._progress_duration = nil
    M._progress_refresh_only = nil
    M._progress_elapsed = nil
    M._progress_update_seconds = nil
end

local function sync_runtime_events(enabled)
    if not loader then return end
    enabled = enabled and true or false
    if M._runtime_events_registered == enabled then return end

    for _, event in ipairs(RUNTIME_EVENTS) do
        if enabled then
            loader:RegisterEvent(event)
        else
            loader:UnregisterEvent(event)
        end
    end
    M._runtime_events_registered = enabled
end

function M.stop_runtime()
    stop_progress_driver()
    M._fill_test_enabled = false
    M._fill_test_started_at = nil
    if M.sync_fill_test_button then
        M.sync_fill_test_button()
    end
    if M.frame then
        M.restore_frame_alpha(M.frame)
        M.frame:Hide()
        M.frame:EnableMouse(false)
        M.frame._mouse_enabled = false
    end
    sync_runtime_events(false)
end
--#endregion RUNTIME LIFECYCLE =================================================


--#region FILL TEST AND PROGRESS UPDATES =======================================
-- Simulated fill preview and active filling-node OnUpdate cadence.
local function get_fill_test_charge_info()
    local max_slots = M.MAX_SLOTS
    local elapsed = (GetTime() - (M._fill_test_started_at or GetTime())) / FILL_TEST_NODE_SECONDS
    local step = elapsed % (max_slots + 1)
    local full_count = min(floor(step), max_slots)
    local progress = step - full_count

    return full_count, max_slots, GetTime() - (progress * FILL_TEST_NODE_SECONDS), FILL_TEST_NODE_SECONDS
end

local function get_progress_update_seconds(db)
    local hz = clamp_number(db and db.progress_update_hz, DEFAULTS.progress_update_hz or 20, SETTING_SPECS.progress_update_hz)
    return 1 / hz
end

local function update_progress_driver(db, needs_progress_updates, slot_index, start_time, duration)
    local refresh_only = not slot_index and M._fill_test_enabled
    if not db or not db.enabled or not needs_progress_updates or (not slot_index and not refresh_only)
        or not start_time or not duration or duration <= 0
    then
        stop_progress_driver()
        return
    end

    M._progress_slot_index = slot_index
    M._progress_start_time = start_time
    M._progress_duration = duration
    M._progress_refresh_only = refresh_only
    M._progress_update_seconds = get_progress_update_seconds(db)
    M._progress_elapsed = M._progress_update_seconds

    if progress_driver:GetScript("OnUpdate") then
        return
    end

    progress_driver:SetScript("OnUpdate", function(_, elapsed)
        local active_slot = M._progress_slot_index
        local active_start = M._progress_start_time
        local active_duration = M._progress_duration
        local refresh_only_update = M._progress_refresh_only
        if (not active_slot and not refresh_only_update) or not active_start
            or not active_duration or active_duration <= 0
        then
            stop_progress_driver()
            return
        end

        M._progress_elapsed = (M._progress_elapsed or 0) + (elapsed or 0)
        local progress_update_seconds = M._progress_update_seconds or get_progress_update_seconds(get_db())
        if M._progress_elapsed < progress_update_seconds then
            return
        end
        M._progress_elapsed = 0

        local progress = min(max((GetTime() - active_start) / active_duration, 0), 1)
        if progress >= 1 then
            stop_progress_driver()
            M.refresh()
            return
        end

        if active_slot then
            M.update_filling_slot_progress(active_slot, progress)
        end
    end)
    progress_driver:Show()
end
--#endregion FILL TEST AND PROGRESS UPDATES ====================================


--#region RENDER REFRESH =======================================================
-- Main runtime render path: visibility decisions, slot state, alpha, and ticking.
function M.refresh()
    if not M.is_runtime_enabled() then
        M.stop_runtime()
        return
    end

    local db = get_db()
    if not db then return end

    if not db.enabled then
        M.stop_runtime()
        return
    end

    sync_runtime_events(true)

    local frame = M.ensure_frame()
    if not frame then return end

    M.apply_layout()
    M.set_move_mode(db.move_mode)

    local is_gliding, can_glide = M.get_gliding_state()
    local current, max_charges, start_time, duration = M.get_charge_info()
    local max_slots = M.MAX_SLOTS

    if M._fill_test_enabled then
        current, max_charges, start_time, duration = get_fill_test_charge_info()
        is_gliding = true
        can_glide = true
    end

    if not M._fill_test_enabled and db.move_mode and not current then
        current, max_charges, start_time, duration = 4, max_slots, GetTime() - 2, 5
    end

    local is_ridealong_passenger = not M._fill_test_enabled and not db.move_mode
        and M.is_player_ridealong_passenger and M.is_player_ridealong_passenger()
    local should_show = current and max_charges
        and not is_ridealong_passenger
        and (
            M._fill_test_enabled
            or db.move_mode
            or is_gliding
            or (can_glide and (M.is_player_flying() or M.is_mounted_in_advanced_flyable_area(can_glide)))
        )
    if not should_show then
        M.restore_frame_alpha(frame)
        frame:Hide()
        stop_progress_driver()
        return
    end
    current = current or 0
    max_charges = max_charges or max_slots

    local progress = 0
    if duration and duration > 0 and start_time and start_time > 0 then
        progress = min(max((GetTime() - start_time) / duration, 0), 1)
    end
    local filling_slot_index
    local needs_progress_updates = M._fill_test_enabled or (not db.move_mode
        and (current < max_charges and duration and duration > 0 and start_time and start_time > 0)
    )
    local visible_max_charges = min(max_charges, max_slots)
    if needs_progress_updates and current < visible_max_charges then
        filling_slot_index = current + 1
    end

    for i = 1, max_slots do
        if i <= max_charges then
            M.set_slot_visible(i, true)
            if i <= current then
                M.set_slot_state(i, "full", 1)
            elseif i == current + 1 and progress > 0 and progress < 1 then
                M.set_slot_state(i, "filling", progress)
            else
                M.set_slot_state(i, "empty", 0)
            end
        else
            M.set_slot_visible(i, false)
        end
    end

    local is_active_flight = is_gliding or (can_glide and M.is_player_flying())
    local charges_full = current >= min(max_charges, max_slots)
    M.apply_full_charge_fade(frame, db, charges_full, is_active_flight)

    if not frame:IsShown() then
        frame:Show()
    end
    update_progress_driver(db, needs_progress_updates, filling_slot_index, start_time, duration)
end
--#endregion RENDER REFRESH ====================================================


--#region PUBLIC RUNTIME CONTROLS ==============================================
-- Entry points called by module toggles and user-facing runtime controls.
function M.set_module_enabled(enabled)
    if enabled then
        M._db_normalized = false
        local db = get_db()
        if db and db.enabled then
            M.refresh()
        else
            M.stop_runtime()
        end
        return
    end

    M.stop_runtime()
end

if addon.register_module_status then
    addon.register_module_status(M.MODULE_KEY, function()
        return {
            "runtime_events=" .. tostring(M._runtime_events_registered == true),
            "frame_shown=" .. tostring(M.frame and M.frame:IsShown() == true),
            "mouse_enabled=" .. tostring(M.frame and M.frame._mouse_enabled == true),
            "progress_onupdate=" .. tostring(progress_driver and progress_driver:GetScript("OnUpdate") ~= nil),
            "progress_driver_shown=" .. tostring(progress_driver and progress_driver:IsShown() == true),
            "fill_test=" .. tostring(M._fill_test_enabled == true),
            "progress_slot=" .. tostring(M._progress_slot_index ~= nil),
        }
    end)
end

function M.set_fill_test_enabled(enabled)
    if not M.is_runtime_enabled() then
        M.stop_runtime()
        return
    end

    enabled = enabled and true or false
    if M._fill_test_enabled == enabled then return end
    local db = get_db()
    if enabled and (not db or not db.enabled) then return end

    M._fill_test_enabled = enabled
    if M.sync_fill_test_button then
        M.sync_fill_test_button()
    end

    if enabled then
        stop_progress_driver()
        M._fill_test_started_at = GetTime()
        M.refresh()
    else
        M._fill_test_started_at = nil
        M.refresh()
    end
end

function M.toggle_fill_test()
    M.set_fill_test_enabled(not M._fill_test_enabled)
end
--#endregion PUBLIC RUNTIME CONTROLS ===========================================


--#region SETTINGS MUTATION ====================================================
-- Settings write paths that normalize values and trigger the correct refresh.
function M.on_reset_complete()
    M._db_normalized = false
    local db = get_db()
    if not db then return end
    if M.invalidate_layout then
        M.invalidate_layout()
    end

    if M.sync_settings_controls then
        M.sync_settings_controls(db)
    end
    if M.apply_fill_color then
        M.apply_fill_color()
    end
    M.apply_position()
    M.refresh()
end

function M.set_db_value(key, value)
    local db = get_db()
    if not db then return end
    if key == "enabled" then
        value = value and true or false
    elseif key == "show_spark" then
        value = value and true or false
    elseif key == "spark_size" then
        value = clamp_number(value, DEFAULTS.spark_size or 1, SETTING_SPECS.spark_size)
    elseif key == "progress_update_hz" then
        value = clamp_number(value, DEFAULTS.progress_update_hz or 20, SETTING_SPECS.progress_update_hz)
    elseif key == "style" and M.get_valid_bar_style_key then
        value = M.get_valid_bar_style_key(value)
    elseif key == "scale" and M.set_style_scale then
        M.set_style_scale(value)
        return
    elseif key == "fill_add_alpha" and M.set_style_fill_add_alpha then
        M.set_style_fill_add_alpha(value)
        return
    elseif key == "node_color" and M.set_node_color then
        M.set_node_color(value)
        return
    elseif key == "decor_style" and M.get_valid_decor_style_key then
        value = M.get_valid_decor_style_key(value)
    elseif key == "decor_color" and M.set_decor_color then
        M.set_decor_color(value)
        return
    end
    db[key] = value
    if key == "style" and M.get_style_layout_table then
        local style_layout = M.get_style_layout_table(db, value, true)
        if style_layout and style_layout.scale ~= nil then
            db.scale = clamp_number(style_layout.scale, DEFAULTS.scale or 1, SETTING_SPECS.scale)
        end
        if M.sync_slider_controls then
            M.sync_slider_controls(db)
        end
        if M.sync_style_color_controls then
            M.sync_style_color_controls()
        end
        if M.sync_node_color_controls then
            M.sync_node_color_controls()
        end
    end
    if key == "decor_style" and M.get_decor_layout_table then
        M.get_decor_layout_table(db, value, true)
        if M.sync_decor_position_controls then
            M.sync_decor_position_controls(db)
        end
        if M.sync_decor_color_controls then
            M.sync_decor_color_controls()
        end
    end
    if key == "enabled" and not value then
        M.stop_runtime()
        return
    end
    if M.LAYOUT_SETTING_KEYS and M.LAYOUT_SETTING_KEYS[key] then
        M.refresh_layout()
    elseif key == "spark_size" and M.apply_spark_settings then
        M.apply_spark_settings()
    else
        M.refresh()
    end
end

function M.refresh_layout()
    if M.invalidate_layout then
        M.invalidate_layout()
    end
    M.refresh()
end

function M.set_snap_to_grid(value)
    local db = get_db()
    if not db then return end
    db.snap_to_grid = value and true or false
    if db.snap_to_grid then
        M.snap_position()
        M.save_position()
    end
    M.refresh()
end

function M.set_position_axis(axis, value)
    if M._syncing_position_controls then return end
    if axis ~= "x" and axis ~= "y" then return end

    local db = get_db()
    if not db then return end

    db.position = db.position or {}
    if value == nil then
        value = db.position[axis]
    end
    if value == nil then
        value = DEFAULTS.position and DEFAULTS.position[axis] or 0
    end
    db.position.point = "CENTER"
    db.position.relativePoint = "CENTER"
    db.position[axis] = value

    M.apply_position()
end

function M.reset_position()
    local db = get_db()
    if not db then return end
    db.position = {}
    addon.deep_copy_into(DEFAULTS.position or {}, db.position)
    M.apply_position()
    M.refresh()
    if M.sync_position_controls then
        M.sync_position_controls(db)
    end
end
--#endregion SETTINGS MUTATION =================================================


--#region EVENT BOOTSTRAP ======================================================
-- Addon-load registration and runtime event dispatch into the refresh path.
loader:RegisterEvent("ADDON_LOADED")

loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        Ls_Tweeks_DB = Ls_Tweeks_DB or {}
        local db = get_db()
        if addon.register_category then
            addon.register_category(M.CATEGORY_NAME, M.BuildSettings, { order = 901, module_key = M.MODULE_KEY })
        end
        if db and db.enabled then
            M.refresh()
        else
            M.stop_runtime()
        end
        return
    end

    M.refresh()
end)
--#endregion EVENT BOOTSTRAP ===================================================
