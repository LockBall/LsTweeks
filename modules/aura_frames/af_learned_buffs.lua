-- Persistent out-of-combat helpful Aura duration learner.
-- Readable observations become a native spell-ID inclusion filter; combat and
-- secret Aura state are never inspected or used for addon-side display.

local addon_name, addon = ...

local M = addon.aura_frames

local LEARN_SCAN_LIMIT = 255
local learned_event_frame
local learned_listener_generation = 0

--#region LEARNED CACHE =======================================================

local function is_secret(value)
    return (issecretvalue and issecretvalue(value))
        or (issecrettable and issecrettable(value))
end

local function get_readable_number(value)
    if is_secret(value) or type(value) ~= "number" or value ~= value then return nil end
    return value
end

local function get_learned_cache()
    if not M.db then return nil end
    if type(M.db.learned_helpful_durations) ~= "table" then
        M.db.learned_helpful_durations = {}
    end
    return M.db.learned_helpful_durations
end

local function signal_learned_cache_changed()
    M._learned_buff_revision = (M._learned_buff_revision or 0) + 1
    if M.refresh_managed_learned_buff_filters then
        M.refresh_managed_learned_buff_filters()
    end
end

function M.note_learned_buff_cache_replaced()
    signal_learned_cache_changed()
end

function M.build_learned_long_static_spell_ids(db)
    db = db or M.db
    local included = {}
    local learned = db and db.learned_helpful_durations
    local short_max = tonumber(db and db.short_threshold) or M.DEFAULT_SHORT_THRESHOLD
    if type(learned) ~= "table" then return included end

    for spell_id, duration in pairs(learned) do
        spell_id = tonumber(spell_id)
        duration = tonumber(duration)
        if spell_id and spell_id > 0 and duration and duration >= 0
            and (duration == 0 or duration > short_max)
        then
            included[spell_id] = true
        end
    end
    return included
end

function M.get_learned_long_static_count(db)
    local count = 0
    for _spell_id in pairs(M.build_learned_long_static_spell_ids(db)) do
        count = count + 1
    end
    return count
end

function M.clear_learned_helpful_durations()
    if not M.db or (InCombatLockdown and InCombatLockdown()) then return false end
    M.db.learned_helpful_durations = {}
    signal_learned_cache_changed()
    return true
end

function M.learn_helpful_aura_durations_ooc()
    if (InCombatLockdown and InCombatLockdown()) or not M.db then return false, 0 end
    if not (C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function") then
        return false, 0
    end

    local learned_cache = get_learned_cache()
    if not learned_cache then return false, 0 end
    local changed = false
    local learned_count = 0
    for index = 1, LEARN_SCAN_LIMIT do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        if not ok then break end
        if aura == nil then break end
        if not is_secret(aura) and type(aura) == "table" then
            local spell_id = get_readable_number(aura.spellId)
            local duration = get_readable_number(aura.duration)
            if spell_id and spell_id > 0 and spell_id % 1 == 0 and duration and duration >= 0 then
                learned_count = learned_count + 1
                if learned_cache[spell_id] ~= duration then
                    learned_cache[spell_id] = duration
                    changed = true
                end
            end
        end
    end

    if changed then signal_learned_cache_changed() end
    return changed, learned_count
end

--#endregion LEARNED CACHE ====================================================

--#region OOC LEARNER LIFECYCLE ==============================================

function M.queue_learned_buff_scan()
    if M._learned_buff_scan_pending then return end
    M._learned_buff_scan_pending = true
    local generation = learned_listener_generation
    local function scan()
        if generation ~= learned_listener_generation then return end
        M._learned_buff_scan_pending = false
        if M._module_runtime_enabled then
            M.learn_helpful_aura_durations_ooc()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(M.UPDATE_INTERVALS.aura_event_bucket, scan)
    else
        scan()
    end
end

local function handle_learned_buff_event(_self, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if event == "PLAYER_REGEN_DISABLED" then return end
    M.queue_learned_buff_scan()
end

function M.start_learned_buff_listener()
    learned_listener_generation = learned_listener_generation + 1
    M._learned_buff_scan_pending = false
    if not learned_event_frame then
        learned_event_frame = CreateFrame("Frame")
        learned_event_frame:SetScript("OnEvent", handle_learned_buff_event)
    end
    learned_event_frame:RegisterUnitEvent("UNIT_AURA", "player")
    learned_event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    learned_event_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    learned_event_frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    M.queue_learned_buff_scan()
end

function M.stop_learned_buff_listener()
    learned_listener_generation = learned_listener_generation + 1
    M._learned_buff_scan_pending = false
    if learned_event_frame then learned_event_frame:UnregisterAllEvents() end
end

--#endregion OOC LEARNER LIFECYCLE ===========================================
