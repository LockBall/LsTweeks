-- Skyriding Vigor state detection: reads player vigor charges, glide/flying state, and advanced-flight mount context.
-- Runtime event routing and rendering decisions live in sv_main.lua.
local _, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local C_PlayerInfo_GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo
local C_Spell_GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local IsAdvancedFlyableArea = IsAdvancedFlyableArea
local IsFlying = IsFlying
local IsMounted = IsMounted
local UnitPower = UnitPower
local UnitPowerDisplayMod = UnitPowerDisplayMod
local UnitPowerMax = UnitPowerMax
local issecretvalue = issecretvalue
local floor = math.floor
local min = math.min
local ipairs = ipairs

local VIGOR_SPELL_IDS = {
    372610, -- Skyward Ascent
    372608, -- Surge Forward
}

local VIGOR_POWER_TYPES = {
    25, -- Enum.PowerType.AlternateMount
    10, -- Enum.PowerType.Alternate
}

-- ============================================================================
-- POWER STATE
-- ============================================================================

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

    local max_slots = M.MAX_SLOTS or 6
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

function M.get_charge_info()
    local current, max_charges, start_time, duration = get_vigor_power_info()
    if current and max_charges then
        return current, max_charges, start_time, duration
    end

    if not C_Spell_GetSpellCharges then return nil end

    for _, spell_id in ipairs(VIGOR_SPELL_IDS) do
        local info = C_Spell_GetSpellCharges(spell_id)
        if info and info.maxCharges and not is_secret(info.maxCharges) and info.maxCharges > 0 then
            local spell_current = info.currentCharges or 0
            -- Action spell charges can report maxCharges = 1; keep the six-node bar shape in fallback mode.
            local max_slots = M.MAX_SLOTS or 6
            if not is_secret(spell_current) then
                return min(spell_current, max_slots), max_slots, info.cooldownStartTime or 0, info.cooldownDuration or 0
            end
        end
    end

    return nil
end

-- ============================================================================
-- FLIGHT STATE
-- ============================================================================

function M.get_gliding_state()
    if not C_PlayerInfo_GetGlidingInfo then return false, false end
    local is_gliding, can_glide = C_PlayerInfo_GetGlidingInfo()
    return is_gliding and true or false, can_glide and true or false
end

function M.is_player_flying()
    return IsFlying and IsFlying()
end

function M.is_mounted_in_advanced_flyable_area()
    return IsMounted and IsMounted()
        and IsAdvancedFlyableArea and IsAdvancedFlyableArea()
end
