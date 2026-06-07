-- Skyriding Vigor runtime: events, visibility decisions, DB normalization, and settings hooks.
-- Visual bar construction and layout live in sv_bar.lua.
-- Alpha fade helpers live in sv_fade.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local C_Timer_NewTicker = C_Timer and C_Timer.NewTicker
local CreateFrame = CreateFrame
local GetTime = GetTime
local floor = math.floor
local max = math.max
local min = math.min
local ipairs = ipairs
local tonumber = tonumber

local TICK_SECONDS = addon.UPDATE_INTERVALS.skyriding_vigor_tick or addon.UPDATE_INTERVALS.fifth_sec
local FILL_TEST_NODE_SECONDS = 0.55
local RUNTIME_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_CAN_GLIDE_CHANGED",
    "PLAYER_IS_GLIDING_CHANGED",
    "SPELL_UPDATE_CHARGES",
    "SPELL_UPDATE_COOLDOWN",
    "MOUNT_JOURNAL_USABILITY_CHANGED",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
}

local DEFAULTS = addon.module_defaults and addon.module_defaults.sv and addon.module_defaults.sv.skyriding_vigor or {}
local SETTING_SPECS = M.SETTING_SPECS
M.CATEGORY_NAME = "Skyriding Vigor"
M.DEFAULTS = DEFAULTS

local loader = CreateFrame("Frame")

-- ============================================================================
-- DATABASE
-- ============================================================================

local function clamp_number(value, fallback, spec)
    value = tonumber(value)
    if not value then value = fallback end
    if spec and value < spec.min then return spec.min end
    if spec and value > spec.max then return spec.max end
    return value
end

local function normalize_db(db)
    if not db then return end

    db.scale = clamp_number(db.scale, DEFAULTS.scale or 1, SETTING_SPECS.scale)
    db.spacing = clamp_number(db.spacing, DEFAULTS.spacing or 5, SETTING_SPECS.spacing)
    db.fade_alpha = clamp_number(db.fade_alpha, DEFAULTS.fade_alpha or 0.25, SETTING_SPECS.fade_alpha)
    db.fade_length = clamp_number(db.fade_length, DEFAULTS.fade_length or 3, SETTING_SPECS.fade_length)
    if M.get_valid_bar_style_key then
        db.style = M.get_valid_bar_style_key(db.style or DEFAULTS.style or M.BAR_STYLE_DEFAULT)
    else
        db.style = db.style or DEFAULTS.style or "default"
    end
    if M.get_style_layout_table then
        local style_layout = M.get_style_layout_table(db, db.style, true, db.scale)
        if style_layout then
            style_layout.scale = clamp_number(style_layout.scale, db.scale or DEFAULTS.scale or 1, SETTING_SPECS.scale)
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

-- ============================================================================
-- RUNTIME LIFECYCLE
-- ============================================================================

local function stop_ticker()
    if M.ticker then
        M.ticker:Cancel()
        M.ticker = nil
    end
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

local function disable_runtime()
    stop_ticker()
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
end

-- ============================================================================
-- FILL TEST AND TICKING
-- ============================================================================

local function get_fill_test_charge_info()
    local max_slots = M.MAX_SLOTS
    local elapsed = (GetTime() - (M._fill_test_started_at or GetTime())) / FILL_TEST_NODE_SECONDS
    local step = elapsed % (max_slots + 1)
    local full_count = min(floor(step), max_slots)
    local progress = step - full_count

    return full_count, max_slots, GetTime() - (progress * FILL_TEST_NODE_SECONDS), FILL_TEST_NODE_SECONDS
end

local function should_tick(db, needs_progress_updates)
    return db and db.enabled and needs_progress_updates
end

local function update_ticker(db, needs_progress_updates)
    if should_tick(db, needs_progress_updates) then
        if not M.ticker then
            M.ticker = C_Timer_NewTicker(TICK_SECONDS, function()
                M.refresh()
            end)
        end
    else
        stop_ticker()
    end
end

-- ============================================================================
-- RENDER REFRESH
-- ============================================================================

function M.refresh()
    if addon.is_module_enabled and not addon.is_module_enabled("skyriding_vigor") then
        disable_runtime()
        sync_runtime_events(false)
        return
    end

    local db = get_db()
    if not db then return end

    if not db.enabled then
        disable_runtime()
        sync_runtime_events(false)
        return
    end

    sync_runtime_events(true)

    local frame = M.ensure_frame()
    if not frame then return end

    M.apply_layout()
    M.set_move_mode(db.move_mode)

    local is_gliding, _ = M.get_gliding_state()
    local current, max_charges, start_time, duration = M.get_charge_info()
    local max_slots = M.MAX_SLOTS

    if M._fill_test_enabled then
        current, max_charges, start_time, duration = get_fill_test_charge_info()
        is_gliding = true
    end

    if not M._fill_test_enabled and db.move_mode and not current then
        current, max_charges, start_time, duration = 4, max_slots, GetTime() - 2, 5
    end

    local should_show = current and max_charges
        and (M._fill_test_enabled or db.move_mode or is_gliding or M.is_player_flying() or M.is_mounted_in_advanced_flyable_area())
    if not should_show then
        M.restore_frame_alpha(frame)
        frame:Hide()
        update_ticker(db, false)
        return
    end
    current = current or 0
    max_charges = max_charges or max_slots

    local progress = 0
    if duration and duration > 0 and start_time and start_time > 0 then
        progress = min(max((GetTime() - start_time) / duration, 0), 1)
    end
    local needs_progress_updates = M._fill_test_enabled or (not db.move_mode
        and (current < max_charges and duration and duration > 0 and start_time and start_time > 0)
    )

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

    local is_active_flight = is_gliding or M.is_player_flying()
    local charges_full = current >= min(max_charges, max_slots)
    M.apply_full_charge_fade(frame, db, charges_full, is_active_flight)

    if not frame:IsShown() then
        frame:Show()
    end
    update_ticker(db, needs_progress_updates)
end

-- ============================================================================
-- PUBLIC RUNTIME CONTROLS
-- ============================================================================

function M.set_module_enabled(enabled)
    if enabled then
        M._db_normalized = false
        local db = get_db()
        sync_runtime_events(db and db.enabled)
        if db and db.enabled then
            M.refresh()
        end
        return
    end

    disable_runtime()
    sync_runtime_events(false)
end

function M.set_fill_test_enabled(enabled)
    enabled = enabled and true or false
    if M._fill_test_enabled == enabled then return end
    local db = get_db()
    if enabled and (not db or not db.enabled) then return end

    M._fill_test_enabled = enabled
    if M.sync_fill_test_button then
        M.sync_fill_test_button()
    end

    if enabled then
        stop_ticker()
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

-- ============================================================================
-- SETTINGS MUTATION
-- ============================================================================

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
    M.apply_position()
    M.refresh()
end

function M.set_db_value(key, value)
    local db = get_db()
    if not db then return end
    if key == "enabled" then
        value = value and true or false
    elseif key == "style" and M.get_valid_bar_style_key then
        value = M.get_valid_bar_style_key(value)
    elseif key == "scale" and M.set_style_scale then
        M.set_style_scale(value)
        return
    elseif key == "decor_style" and M.get_valid_decor_style_key then
        value = M.get_valid_decor_style_key(value)
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
    end
    if key == "decor_style" and M.get_decor_layout_table then
        M.get_decor_layout_table(db, value, true)
        if M.sync_decor_position_controls then
            M.sync_decor_position_controls(db)
        end
    end
    if key == "enabled" and not value then
        disable_runtime()
        sync_runtime_events(false)
        return
    end
    if M.LAYOUT_SETTING_KEYS and M.LAYOUT_SETTING_KEYS[key] then
        M.refresh_layout()
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

-- ============================================================================
-- EVENT BOOTSTRAP
-- ============================================================================

loader:RegisterEvent("ADDON_LOADED")

loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        Ls_Tweeks_DB = Ls_Tweeks_DB or {}
        local db = get_db()
        if not addon.is_module_enabled or addon.is_module_enabled("skyriding_vigor") then
            sync_runtime_events(db and db.enabled)
        end
        if addon.register_category then
            addon.register_category(M.CATEGORY_NAME, M.BuildSettings, { order = 901, module_key = "skyriding_vigor" })
        end
        if db and db.enabled and (not addon.is_module_enabled or addon.is_module_enabled("skyriding_vigor")) then
            M.refresh()
        end
        return
    end

    M.refresh()
end)
