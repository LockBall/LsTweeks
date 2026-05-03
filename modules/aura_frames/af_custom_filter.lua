-- Direct filtered scanning for custom aura frames.
-- Provides M.scan_custom_aura_map(), which reads C_UnitAuras.GetAuraDataByIndex
-- with a custom frame's selected HELPFUL/HARMFUL base and optional modifier.
local addon_name, addon = ...

local C_UnitAuras   = C_UnitAuras
local GetTime       = GetTime
local issecretvalue = issecretvalue
local math_max      = math.max
local pcall         = pcall

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local function safe_spell_id(aura)
    local sid = aura and aura.spellId
    if sid ~= nil and not issecretvalue(sid) then return sid end
    return nil
end

local function compute_remaining(duration, expiration)
    if duration == nil or expiration == nil then return nil end
    if issecretvalue(duration) or issecretvalue(expiration) then return nil end
    if duration <= 0 or expiration <= 0 then return 0 end
    return math_max(0, expiration - GetTime())
end

local function classify_for_timer(is_helpful, remaining, duration, short_threshold)
    if not is_helpful then return "debuff" end
    if remaining == nil then return "short" end
    if remaining <= 0 then return "static" end
    if duration ~= nil and not issecretvalue(duration) and duration == 0 then return "static" end
    if remaining <= short_threshold then return "short" end
    return "long"
end

local function add_custom_entry(target_map, aura, filter, short_threshold)
    if not (target_map and aura) then return false end
    local iid = aura.auraInstanceID
    if not iid then return false end

    local duration = aura.duration
    local expiration = aura.expirationTime
    local remaining = compute_remaining(duration, expiration)
    local live_remaining
    local live_expiration

    if remaining == nil and C_UnitAuras.GetAuraDuration then
        local ok, live_duration = pcall(C_UnitAuras.GetAuraDuration, "player", iid)
        if ok and live_duration then
            local r = live_duration:GetRemainingDuration()
            if r ~= nil and not issecretvalue(r) then
                live_remaining = r
                remaining = r
            end
            if live_duration.GetExpirationTime then
                local e = live_duration:GetExpirationTime()
                if e ~= nil and not issecretvalue(e) then live_expiration = e end
            end
        end
    end

    local applications = aura.applications
    local stacks = (applications and not issecretvalue(applications) and applications > 1) and applications or 0
    local live_count = (stacks == 0 and C_UnitAuras.GetAuraApplicationDisplayCount)
        and C_UnitAuras.GetAuraApplicationDisplayCount("player", iid)
        or nil
    local is_helpful = filter:find("HELPFUL", 1, true) ~= nil
    local category = classify_for_timer(is_helpful, remaining, duration, short_threshold)

    target_map[iid] = {
        instance_id = iid,
        spell_id = safe_spell_id(aura),
        name = aura.name,
        icon = aura.icon,
        duration = (duration ~= nil and not issecretvalue(duration)) and duration or 0,
        expiration = (expiration ~= nil and not issecretvalue(expiration)) and expiration or (live_expiration or 0),
        remaining = remaining or 0,
        count = stacks,
        live_remaining = live_remaining,
        live_count = live_count,
        filter = filter,
        is_helpful = is_helpful,
        category = category,
        order_key = aura.auraInstanceID,
        added_at = GetTime(),
    }
    return true
end

function M.scan_custom_aura_map(frame, custom_entry, target_map, max_limit, short_threshold)
    if not (frame and custom_entry and target_map and C_UnitAuras.GetAuraDataByIndex) then return end
    local filter = M.get_custom_aura_filter and M.get_custom_aura_filter(custom_entry) or "HELPFUL"
    max_limit = max_limit or custom_entry.max_icons or 40
    short_threshold = short_threshold or (M.db and M.db.short_threshold) or 60

    local i = 1
    local count = 0
    while count < max_limit do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
        if not ok or not aura then break end
        i = i + 1
        if add_custom_entry(target_map, aura, filter, short_threshold) then
            count = count + 1
        end
    end
end
