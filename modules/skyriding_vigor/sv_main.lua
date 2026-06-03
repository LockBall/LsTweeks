-- Skyriding Vigor runtime: events, charge detection, visibility, and settings hooks.
-- Visual bar construction and layout live in sv_bar.lua.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local C_PlayerInfo_GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local C_Spell_GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local GetTime = GetTime
local issecretvalue = issecretvalue
local max = math.max
local min = math.min

local VIGOR_SPELL_IDS = {
    372610, -- Skyward Ascent
    372608, -- Surge Forward
}

local TICK_SECONDS = 0.1
local FALLBACK_MAX_SLOTS = 6

local DEFAULTS = addon.module_defaults and addon.module_defaults.sv and addon.module_defaults.sv.skyriding_vigor or {}
M.CATEGORY_NAME = "Skyriding Vigor"
M.DEFAULTS = DEFAULTS

local function get_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.skyriding_vigor = Ls_Tweeks_DB.skyriding_vigor or {}
    addon.apply_defaults(addon.module_defaults and addon.module_defaults.sv or {}, Ls_Tweeks_DB)
    return Ls_Tweeks_DB.skyriding_vigor
end

M.get_db = get_db

local function is_secret(value)
    return issecretvalue and issecretvalue(value)
end

local function get_charge_info()
    if not C_Spell_GetSpellCharges then return nil end

    for _, spell_id in ipairs(VIGOR_SPELL_IDS) do
        local info = C_Spell_GetSpellCharges(spell_id)
        if info and info.maxCharges and not is_secret(info.maxCharges) and info.maxCharges > 0 then
            local current = info.currentCharges or 0
            local max_slots = M.MAX_SLOTS or FALLBACK_MAX_SLOTS
            local max_charges = info.maxCharges or max_slots
            if not is_secret(current) then
                return current, min(max_charges, max_slots), info.cooldownStartTime or 0, info.cooldownDuration or 0
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

local function stop_ticker()
    if M.ticker then
        M.ticker:Cancel()
        M.ticker = nil
    end
end

local function should_tick(db, can_glide)
    return db and db.enabled and (db.move_mode or can_glide or (M.frame and M.frame:IsShown()))
end

local function update_ticker(can_glide)
    local db = get_db()
    if should_tick(db, can_glide) then
        if not M.ticker then
            M.ticker = C_Timer.NewTicker(TICK_SECONDS, function()
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

function M.refresh()
    local db = get_db()
    local frame = M.ensure_frame()
    if not db or not frame then return end

    M.apply_layout()
    M.set_move_mode(db.move_mode)

    local is_gliding, can_glide = get_gliding_state()
    local current, max_charges, start_time, duration = get_charge_info()
    local max_slots = M.MAX_SLOTS or FALLBACK_MAX_SLOTS

    if db.move_mode and not current then
        current, max_charges, start_time, duration = 4, max_slots, GetTime() - 2, 5
    end

    local should_show = db.enabled and current and max_charges and (db.move_mode or can_glide)
    if not should_show then
        frame:Hide()
        update_ticker(can_glide)
        return
    end
    current = current or 0
    max_charges = max_charges or max_slots

    local progress = 0
    if duration and duration > 0 and start_time and start_time > 0 then
        progress = min(max((GetTime() - start_time) / duration, 0), 1)
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

    if db.fade_when_full and not db.move_mode and current >= max_charges and not is_gliding then
        frame:SetAlpha(db.fade_alpha or DEFAULTS.fade_alpha or 0.25)
    else
        frame:SetAlpha(1)
    end

    frame:Show()
    update_ticker(can_glide)
end

function M.on_reset_complete()
    local db = get_db()
    if not db then return end
    M.apply_position()
    M.refresh()

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
    for _, key in ipairs({ "fade_alpha", "spacing", "scale" }) do
        local slider = M.controls[key]
        if slider and slider.slider then
            slider.slider:SetValue(db[key] or DEFAULTS[key])
        end
    end
    sync_position_controls(db)
end

function M.set_db_value(key, value)
    local db = get_db()
    if not db then return end
    db[key] = value
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

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED")
loader:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")
loader:RegisterEvent("SPELL_UPDATE_CHARGES")
loader:RegisterEvent("SPELL_UPDATE_COOLDOWN")
loader:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
loader:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        Ls_Tweeks_DB = Ls_Tweeks_DB or {}
        addon.apply_defaults(addon.module_defaults and addon.module_defaults.sv or {}, Ls_Tweeks_DB)
        M.ensure_frame()
        M.apply_layout()
        if addon.register_category then
            addon.register_category(M.CATEGORY_NAME, M.BuildSettings, { order = 901 })
        end
        return
    end

    M.refresh()
end)
