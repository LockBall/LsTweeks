-- Archived Fishing Bobber sound probe.
-- The bobber replacement path was removed because tested Lua hooks/APIs did
-- not expose reliable bite timing. Keep this probe as long-term diagnostic
-- capture for future re-testing.
-- Usage:
-- 1. Temporarily add this file near the end of LsTweeks.toc, or paste it into
--    a small test addon.
-- 2. /reload
-- 3. Run /lstfishprobe
-- 4. Cast fishing and wait for a fish to hook.
-- 5. Copy chat lines around the bobber splash, then remove this file from TOC.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

local enabled = false
local wide_enabled = false
local fishing_window_until = 0
local last_soft_guid = nil
local last_object_signature = nil
local last_tooltip_signature = nil
local last_vignette_signature = nil
local last_channel_signature = nil
local last_gamepad_signature = nil
local frame = CreateFrame("Frame")
local poll_frame = CreateFrame("Frame")
local watched_file_ids = {
    [569285] = "Fishing bobber original 1",
    [568970] = "Fishing bobber original 2",
    [569044] = "Fishing bobber original 3",
}

-- Retained as negative-result probe context. These event classes were observed
-- as too noisy for useful bite-timing evidence during earlier wide testing.
local noisy_events = {
    COMBAT_LOG_EVENT_UNFILTERED = true,
    CURSOR_UPDATE = true,
    GLOBAL_MOUSE_DOWN = true,
    GLOBAL_MOUSE_UP = true,
    MODIFIER_STATE_CHANGED = true,
    PLAYER_STARTED_MOVING = true,
    PLAYER_STOPPED_MOVING = true,
    SCRIPTED_ANIMATIONS_UPDATE = true,
    SPELL_UPDATE_COOLDOWN = true,
    UNIT_AURA = true,
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_POWER_FREQUENT = true,
    UNIT_POWER_UPDATE = true,
}

local function now()
    return string.format("%.3f", GetTime())
end

local function out(...)
    if not enabled then return end
    print("|cff66ccffFishProbe|r", now(), ...)
end

local function normalize_sound_id(sound)
    local numeric = tonumber(sound)
    if numeric then return numeric end
    return sound
end

local function log_sound_api(api_name, sound, channel)
    local sound_id = normalize_sound_id(sound)
    local known = watched_file_ids[sound_id]
    if known then
        out(api_name, "MATCH", tostring(sound_id), known, "channel", tostring(channel))
    else
        out(api_name, tostring(sound_id), "channel", tostring(channel))
    end
end

local function format_info(info)
    if type(info) ~= "table" then return tostring(info) end
    return "inventoryType=" .. tostring(info.inventoryType)
        .. " atMaxQuality=" .. tostring(info.atMaxQuality)
        .. " isUpgrade=" .. tostring(info.isUpgrade)
end

local function format_tooltip_data(data)
    if type(data) ~= "table" then return tostring(data) end

    local lines = {}
    if type(data.lines) == "table" then
        for i, line in ipairs(data.lines) do
            local text = type(line) == "table" and line.leftText or nil
            if text and text ~= "" then
                lines[#lines + 1] = text
            end
        end
    end

    return "type=" .. tostring(data.type)
        .. " id=" .. tostring(data.id)
        .. " guid=" .. tostring(data.guid)
        .. " lines=" .. table.concat(lines, " / ")
end

local function format_vignette_info(info)
    if type(info) ~= "table" then return tostring(info) end

    return "name=" .. tostring(info.name)
        .. " objectGUID=" .. tostring(info.objectGUID)
        .. " atlasName=" .. tostring(info.atlasName)
        .. " type=" .. tostring(info.type)
        .. " onMinimap=" .. tostring(info.onMinimap)
        .. " hasTooltip=" .. tostring(info.hasTooltip)
        .. " isUnique=" .. tostring(info.isUnique)
end

local function format_position(pos)
    if type(pos) ~= "table" then return tostring(pos) end

    local x = nil
    local y = nil
    if type(pos.GetXY) == "function" then
        x, y = pos:GetXY()
    else
        x = pos.x or pos[1]
        y = pos.y or pos[2]
    end

    if x and y then
        return string.format("%.5f,%.5f", x, y)
    end

    return "table"
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function safe_call_results(fn, ...)
    if type(fn) ~= "function" then return nil end

    local results = { pcall(fn, ...) }
    if not results[1] then return nil end
    table.remove(results, 1)
    return results
end

local function format_results(results)
    if type(results) ~= "table" then return tostring(results) end

    local parts = {}
    for i = 1, #results do
        parts[#parts + 1] = tostring(i) .. "=" .. tostring(results[i])
    end
    return table.concat(parts, ",")
end

local function log_channel_state(reason)
    if not enabled then return end

    local channel_info = safe_call_results(UnitChannelInfo, "player")
    local casting_info = safe_call_results(UnitCastingInfo, "player")
    local signature = format_results(channel_info) .. "|" .. format_results(casting_info)

    if signature == last_channel_signature and reason == "poll" then
        return
    end
    last_channel_signature = signature

    out(
        "CHANNEL", reason,
        "UnitChannelInfo", format_results(channel_info),
        "UnitCastingInfo", format_results(casting_info)
    )
end

local function log_gamepad_state(reason)
    if not enabled then return end

    local cvar_value = C_CVar and C_CVar.GetCVar and safe_call(C_CVar.GetCVar, "GamePadVibrationStrength") or nil
    local gamepad_enabled = C_GamePad and C_GamePad.IsEnabled and safe_call(C_GamePad.IsEnabled) or nil
    local using_gamepad = IsUsingGamepad and safe_call(IsUsingGamepad) or nil
    local signature = table.concat({
        tostring(cvar_value),
        tostring(gamepad_enabled),
        tostring(using_gamepad),
    }, "|")

    if signature == last_gamepad_signature and reason == "poll" then
        return
    end
    last_gamepad_signature = signature

    out(
        "GAMEPAD", reason,
        "vibrationStrength", tostring(cvar_value),
        "enabled", tostring(gamepad_enabled),
        "using", tostring(using_gamepad)
    )
end

-- Retained as negative-result investigation paths. These object, tooltip, and
-- vignette probes did not expose reliable bobber bite timing, but they document
-- what was checked and can be re-enabled if Blizzard changes related APIs.
local function log_object_state(reason, guid)
    if not enabled then return end

    local soft_guid = UnitGUID and UnitGUID("softinteract") or nil
    guid = guid or soft_guid or last_soft_guid
    local unit_name = UnitName and UnitName("softinteract") or nil
    local unit_token = guid and UnitTokenFromGUID and UnitTokenFromGUID(guid) or nil
    local unit_is_object = UnitIsGameObject and UnitIsGameObject("softinteract") or nil
    local world_loot_exists = WorldLootObjectExists and WorldLootObjectExists("softinteract") or nil

    local is_world_loot = nil
    local in_range = nil
    local distance = nil
    local info = nil
    local info_by_guid = nil
    if C_WorldLootObject then
        is_world_loot = safe_call(C_WorldLootObject.IsWorldLootObject, "softinteract")
        in_range = safe_call(C_WorldLootObject.IsWorldLootObjectInRange, "softinteract")
        distance = safe_call(C_WorldLootObject.GetWorldLootObjectDistanceSquared, "softinteract")
        info = safe_call(C_WorldLootObject.GetWorldLootObjectInfo, "softinteract")
        if guid then
            info_by_guid = safe_call(C_WorldLootObject.GetWorldLootObjectInfoByGUID, guid)
        end
    end

    local signature = table.concat({
        tostring(guid),
        tostring(soft_guid),
        tostring(unit_name),
        tostring(unit_token),
        tostring(unit_is_object),
        tostring(world_loot_exists),
        tostring(is_world_loot),
        tostring(in_range),
        tostring(distance),
        format_info(info),
        format_info(info_by_guid),
    }, "|")

    if signature == last_object_signature and reason == "poll" then
        return
    end
    last_object_signature = signature

    out(
        "OBJECT", reason,
        "guid", tostring(guid),
        "softGUID", tostring(soft_guid),
        "name", tostring(unit_name),
        "token", tostring(unit_token),
        "unitObj", tostring(unit_is_object),
        "worldLootExists", tostring(world_loot_exists),
        "isWorldLoot", tostring(is_world_loot),
        "inRange", tostring(in_range),
        "dist2", tostring(distance),
        "info", format_info(info),
        "infoGUID", format_info(info_by_guid)
    )
end

local function log_tooltip_state(reason)
    if not enabled then return end
    if not GameTooltip then return end

    local lines = {}
    local line_count = GameTooltip.NumLines and GameTooltip:NumLines() or 0
    for i = 1, line_count do
        local left = _G["GameTooltipTextLeft" .. i]
        local text = left and left.GetText and left:GetText()
        if text and text ~= "" then
            lines[#lines + 1] = text
        end
    end

    local world_cursor = nil
    local world_loot = nil
    if C_TooltipInfo then
        world_cursor = safe_call(C_TooltipInfo.GetWorldCursor)
        world_loot = safe_call(C_TooltipInfo.GetWorldLootObject, "softinteract")
    end

    local signature = table.concat({
        tostring(GameTooltip:IsShown()),
        table.concat(lines, " / "),
        format_tooltip_data(world_cursor),
        format_tooltip_data(world_loot),
    }, "|")

    if signature == last_tooltip_signature and reason == "poll" then
        return
    end
    last_tooltip_signature = signature

    out(
        "TOOLTIP", reason,
        "shown", tostring(GameTooltip:IsShown()),
        "lines", table.concat(lines, " / "),
        "worldCursor", format_tooltip_data(world_cursor),
        "worldLoot", format_tooltip_data(world_loot)
    )
end

local function log_vignette_state(reason)
    if not enabled then return end
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettes then return end

    local vignette_guids = safe_call(C_VignetteInfo.GetVignettes)
    if type(vignette_guids) ~= "table" then return end

    local parts = {}
    local map_id = C_Map and C_Map.GetBestMapForUnit and safe_call(C_Map.GetBestMapForUnit, "player") or nil
    for i, vignette_guid in ipairs(vignette_guids) do
        local info = safe_call(C_VignetteInfo.GetVignetteInfo, vignette_guid)
        local pos = map_id and C_VignetteInfo.GetVignettePosition and safe_call(C_VignetteInfo.GetVignettePosition, vignette_guid, map_id) or nil
        parts[#parts + 1] = tostring(i) .. ":" .. tostring(vignette_guid) .. ":" .. format_vignette_info(info) .. ":pos=" .. format_position(pos)
    end

    local signature = table.concat(parts, "|")
    if signature == last_vignette_signature and reason == "poll" then
        return
    end
    last_vignette_signature = signature

    out("VIGNETTES", reason, signature)
end

if PlaySoundFile then
    hooksecurefunc("PlaySoundFile", function(sound, channel)
        log_sound_api("PlaySoundFile", sound, channel)
    end)
end

if C_Sound and C_Sound.PlaySoundFile then
    hooksecurefunc(C_Sound, "PlaySoundFile", function(sound, channel)
        log_sound_api("C_Sound.PlaySoundFile", sound, channel)
    end)
end

if PlaySound then
    hooksecurefunc("PlaySound", function(soundkit_id, channel)
        log_sound_api("PlaySound", soundkit_id, channel)
    end)
end

if C_Sound and C_Sound.PlaySound then
    hooksecurefunc(C_Sound, "PlaySound", function(soundkit_id, channel)
        log_sound_api("C_Sound.PlaySound", soundkit_id, channel)
    end)
end

if C_GamePad and C_GamePad.SetVibration then
    hooksecurefunc(C_GamePad, "SetVibration", function(vibration_type, intensity)
        out("GAMEPAD_VIBRATION", "SetVibration", tostring(vibration_type), tostring(intensity))
        log_gamepad_state("SetVibration")
    end)
end

if C_GamePad and C_GamePad.StopVibration then
    hooksecurefunc(C_GamePad, "StopVibration", function()
        out("GAMEPAD_VIBRATION", "StopVibration")
        log_gamepad_state("StopVibration")
    end)
end

local events = {
    "CVAR_UPDATE",
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "LOOT_READY",
    "LOOT_OPENED",
}

for _, event_name in ipairs(events) do
    if event_name:match("^UNIT_") then
        frame:RegisterUnitEvent(event_name, "player")
    else
        frame:RegisterEvent(event_name)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if not enabled then return end
    if event == "CVAR_UPDATE" then
        local cvar_name = ...
        if cvar_name == "GamePadVibrationStrength" or cvar_name == "GamePadEnable" then
            log_gamepad_state(event)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, _, spell_id = ...
        if unit == "player" and spell_id == 131476 then
            fishing_window_until = GetTime() + 30
            log_channel_state(event)
            log_gamepad_state(event)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit = ...
        if unit == "player" then
            log_channel_state(event)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit, _, spell_id = ...
        if unit == "player" and spell_id == 131476 then
            fishing_window_until = GetTime() + 3
            log_channel_state(event)
        end
    elseif event == "LOOT_OPENED" then
        fishing_window_until = GetTime() + 1
    end
    out(event, ...)
end)

poll_frame:SetScript("OnUpdate", function(self, elapsed)
    if not (enabled and wide_enabled) then return end
    if GetTime() > fishing_window_until then return end
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.2 then return end
    self.elapsed = 0
    log_channel_state("poll")
    log_gamepad_state("poll")
    log_object_state("poll")
    log_tooltip_state("poll")
    log_vignette_state("poll")
end)

SLASH_LSTWEEKS_FISHING_SOUND_PROBE1 = "/lstfishprobe"
SlashCmdList.LSTWEEKS_FISHING_SOUND_PROBE = function()
    enabled = not enabled
    print("|cff66ccffFishProbe|r", enabled and "enabled" or "disabled")
end

SLASH_LSTWEEKS_FISHING_WIDE_PROBE1 = "/lstfishwide"
SlashCmdList.LSTWEEKS_FISHING_WIDE_PROBE = function()
    wide_enabled = not wide_enabled
    print("|cff66ccffFishProbe|r focused polling", wide_enabled and "enabled" or "disabled")
end

--#endregion FILE CONTENTS ===================================================
