-- Skyriding Vigor runtime: events, charge detection, visibility, and settings hooks.
-- Visual bar construction and layout live in sv_bar.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local C_Timer_NewTicker = C_Timer and C_Timer.NewTicker
local C_PlayerInfo_GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local C_Spell_GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local CreateFrame = CreateFrame
local GetTime = GetTime
local IsAdvancedFlyableArea = IsAdvancedFlyableArea
local IsFlying = IsFlying
local IsMounted = IsMounted
local UnitPower = UnitPower
local UnitPowerDisplayMod = UnitPowerDisplayMod
local UnitPowerMax = UnitPowerMax
local issecretvalue = issecretvalue
local floor = math.floor
local max = math.max
local min = math.min
local ipairs = ipairs
local tonumber = tonumber

local VIGOR_SPELL_IDS = {
    372610, -- Skyward Ascent
    372608, -- Surge Forward
}

local TICK_SECONDS = addon.UPDATE_INTERVALS.skyriding_vigor_tick or addon.UPDATE_INTERVALS.fifth_sec
local FILL_TEST_NODE_SECONDS = 0.55
local VIGOR_POWER_TYPES = {
    25, -- Enum.PowerType.AlternateMount
    10, -- Enum.PowerType.Alternate
}
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
local SLIDER_KEYS = M.SLIDER_KEYS
M.CATEGORY_NAME = "Skyriding Vigor"
M.DEFAULTS = DEFAULTS

local loader = CreateFrame("Frame")

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

local function is_secret(value)
    return issecretvalue and issecretvalue(value)
end

local function normalize_power_value(value, max_power, slot_count, power_type)
    if not value or not max_power or max_power <= 0 then return nil end

    local display_mod = UnitPowerDisplayMod and UnitPowerDisplayMod(power_type) or 0
    if display_mod and display_mod > 1 then
        return floor((value / display_mod) + 0.5)
    end

    if max_power > slot_count then
        return floor(((value / max_power) * slot_count) + 0.5)
    end

    return value
end

local function get_vigor_power_info()
    if not UnitPower or not UnitPowerMax then return nil end

    local max_slots = M.MAX_SLOTS
    for _, power_type in ipairs(VIGOR_POWER_TYPES) do
        local max_power = UnitPowerMax("player", power_type)
        if max_power and not is_secret(max_power) and max_power > 0 then
            local current = UnitPower("player", power_type)
            if current and not is_secret(current) then
                current = normalize_power_value(current, max_power, max_slots, power_type)
                max_power = normalize_power_value(max_power, max_power, max_slots, power_type)
                if current and max_power and max_power > 0 then
                    return min(current, max_slots), min(max_power, max_slots), 0, 0
                end
            end
        end
    end

    return nil
end

local function get_charge_info()
    local current, max_charges, start_time, duration = get_vigor_power_info()
    if current and max_charges then
        return current, max_charges, start_time, duration
    end

    if not C_Spell_GetSpellCharges then return nil end

    for _, spell_id in ipairs(VIGOR_SPELL_IDS) do
        local info = C_Spell_GetSpellCharges(spell_id)
        if info and info.maxCharges and not is_secret(info.maxCharges) and info.maxCharges > 0 then
            local spell_current = info.currentCharges or 0
            local max_slots = M.MAX_SLOTS
            if not is_secret(spell_current) then
                return min(spell_current, max_slots), max_slots, info.cooldownStartTime or 0, info.cooldownDuration or 0
            end
        end
    end

    return nil
end

local function get_gliding_state()
    if not C_PlayerInfo_GetGlidingInfo then return false, false end
    local is_gliding, can_glide = C_PlayerInfo_GetGlidingInfo()
    return is_gliding and true or false, can_glide and true or false
end

local function is_player_flying()
    return IsFlying and IsFlying()
end

local function is_mounted_in_advanced_flyable_area()
    return IsMounted and IsMounted()
        and IsAdvancedFlyableArea and IsAdvancedFlyableArea()
end

local function stop_ticker()
    if M.ticker then
        M.ticker:Cancel()
        M.ticker = nil
    end
end

local function sync_fill_test_button()
    local button = M.controls and M.controls.fill_test_button
    if button and button.SetText then
        button:SetText(M._fill_test_enabled and "Stop Test" or "Fill Test")
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
    sync_fill_test_button()
    if M.frame then
        M.frame:Hide()
        M.frame:EnableMouse(false)
        M.frame._mouse_enabled = false
    end
end

local function set_frame_alpha(frame, alpha)
    if frame._sv_alpha == alpha then return end
    frame:SetAlpha(alpha)
    frame._sv_alpha = alpha
end

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

local function sync_position_controls(db)
    local position = db and db.position
    if not position then return end

    local x_slider = M.controls.x_position
    if x_slider and x_slider.slider and position.x ~= nil and x_slider.slider:GetValue() ~= position.x then
        M._syncing_position_controls = true
        x_slider.slider:SetValue(position.x)
        M._syncing_position_controls = nil
    end

    local y_slider = M.controls.y_position
    if y_slider and y_slider.slider and position.y ~= nil and y_slider.slider:GetValue() ~= position.y then
        M._syncing_position_controls = true
        y_slider.slider:SetValue(position.y)
        M._syncing_position_controls = nil
    end
end

M.sync_position_controls = sync_position_controls

local function sync_slider_controls(db)
    M._syncing_slider_controls = true
    for _, key in ipairs(SLIDER_KEYS) do
        local control = M.controls[key]
        if control and control.slider then
            local value = db[key]
            if value == nil then value = DEFAULTS[key] end
            if value ~= nil and control.slider:GetValue() ~= value then
                control._suppress_callback = true
                control.slider:SetValue(value)
                control._suppress_callback = nil
            end
        end
    end
    M._syncing_slider_controls = nil
end

function M.refresh()
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

    local is_gliding, _ = get_gliding_state()
    local current, max_charges, start_time, duration = get_charge_info()
    local max_slots = M.MAX_SLOTS

    if M._fill_test_enabled then
        current, max_charges, start_time, duration = get_fill_test_charge_info()
        is_gliding = true
    end

    if not M._fill_test_enabled and db.move_mode and not current then
        current, max_charges, start_time, duration = 4, max_slots, GetTime() - 2, 5
    end

    local should_show = current and max_charges
        and (M._fill_test_enabled or db.move_mode or is_gliding or is_player_flying() or is_mounted_in_advanced_flyable_area())
    if not should_show then
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

    local is_active_flight = is_gliding or is_player_flying()
    local charges_full = current >= min(max_charges, max_slots)
    if db.fade_when_full and not M._fill_test_enabled and not db.move_mode and charges_full and not is_active_flight then
        set_frame_alpha(frame, db.fade_alpha or DEFAULTS.fade_alpha or 0.25)
    else
        set_frame_alpha(frame, 1)
    end

    if not frame:IsShown() then
        frame:Show()
    end
    update_ticker(db, needs_progress_updates)
end

function M.set_fill_test_enabled(enabled)
    enabled = enabled and true or false
    if M._fill_test_enabled == enabled then return end
    local db = get_db()
    if enabled and (not db or not db.enabled) then return end

    M._fill_test_enabled = enabled
    sync_fill_test_button()

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

function M.on_reset_complete()
    M._db_normalized = false
    local db = get_db()
    if not db then return end
    if M.invalidate_layout then
        M.invalidate_layout()
    end

    local enabled_cb = M.controls.enabled
    if enabled_cb and enabled_cb.SetChecked then
        enabled_cb:SetChecked(db.enabled or false)
    end
    local fade_cb = M.controls.fade_when_full
    if fade_cb and fade_cb.SetChecked then
        fade_cb:SetChecked(db.fade_when_full or false)
    end
    local move_cb = M.controls.move_mode
    if move_cb and move_cb.SetChecked then
        move_cb:SetChecked(db.move_mode or false)
    end
    local snap_cb = M.controls.snap_to_grid
    if snap_cb and snap_cb.SetChecked then
        snap_cb:SetChecked(db.snap_to_grid or false)
    end
    sync_slider_controls(db)
    sync_position_controls(db)
    sync_fill_test_button()
    M.apply_position()
    M.refresh()
end

function M.set_db_value(key, value)
    local db = get_db()
    if not db then return end
    if key == "enabled" then
        value = value and true or false
    end
    db[key] = value
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
    sync_position_controls(db)
end

loader:RegisterEvent("ADDON_LOADED")

loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        Ls_Tweeks_DB = Ls_Tweeks_DB or {}
        local db = get_db()
        sync_runtime_events(db and db.enabled)
        if addon.register_category then
            addon.register_category(M.CATEGORY_NAME, M.BuildSettings, { order = 901 })
        end
        if db and db.enabled then
            M.refresh()
        end
        return
    end

    M.refresh()
end)
