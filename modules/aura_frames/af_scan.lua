-- Aura scanning for custom frames and Blizzard Cooldown Manager-backed frames.

local addon_name, addon = ...

local math_max   = math.max
local GetTime    = GetTime
local wipe       = wipe
local issecretvalue = issecretvalue
local C_UnitAuras   = C_UnitAuras
local C_Spell       = C_Spell
local GCD_GREY_THRESHOLD = 2.0

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local _scratch_custom_old_map = {}
local _custom_aura_scan_cache = {}

--#region SHARED HELPERS =======================================================

local function make_order_key(spell_id, name, icon, is_helpful)
    local f = is_helpful and "H" or "D"
    local sid = (spell_id ~= nil and not issecretvalue(spell_id)) and tostring(spell_id) or nil
    local n   = (name    ~= nil and not issecretvalue(name))     and tostring(name)     or nil
    local ic  = (icon    ~= nil and not issecretvalue(icon))     and tostring(icon)     or nil
    if not sid and not n and not ic then return nil end
    return f .. "|" .. (sid or "") .. "|" .. (n or "") .. "|" .. (ic or "")
end

-- Returns remaining seconds, or nil if duration is nil/secret.
local function compute_remaining(duration, expiration)
    if not duration or issecretvalue(duration) then return nil end
    if duration <= 0 then return 0 end
    if not expiration or issecretvalue(expiration) then
        return duration
    end
    if expiration > 0 then return math_max(0, expiration - GetTime()) end
    return duration
end

local function read_live_aura_timing(iid, need_live)
    if not (need_live and C_UnitAuras.GetAuraDuration) then return nil, nil end
    local ok, live_duration = pcall(C_UnitAuras.GetAuraDuration, "player", iid)
    if not (ok and live_duration) then return nil, nil end

    local live_expiration
    if live_duration.GetEndTime then
        local e = live_duration:GetEndTime()
        if e ~= nil and not issecretvalue(e) then live_expiration = e end
    end

    local live_remaining
    local r = live_duration:GetRemainingDuration()
    if r ~= nil and not issecretvalue(r) then live_remaining = r end
    return live_remaining, live_expiration
end

local function get_aura_stack_counts(aura, iid)
    local applications = aura and aura.applications
    local stacks = (not issecretvalue(applications) and applications and applications > 1) and applications or 0
    local live_count = (stacks == 0 and C_UnitAuras.GetAuraApplicationDisplayCount)
        and C_UnitAuras.GetAuraApplicationDisplayCount("player", iid)
        or nil
    return stacks, live_count
end

local function resolve_safe_timing(duration, expiration, remaining, live_remaining, live_expiration, old_entry)
    local safe_duration = (not issecretvalue(duration)) and duration
        or (old_entry and old_entry.duration) or 0
    local safe_expiration = (not issecretvalue(expiration)) and expiration
        or live_expiration
        or (live_remaining and live_remaining > 0 and (GetTime() + live_remaining))
        or (old_entry and old_entry.expiration) or 0
    local safe_remaining = remaining
    if live_remaining and live_remaining > 0 then
        safe_remaining = live_remaining
    elseif (not safe_remaining or safe_remaining <= 0) and safe_expiration and safe_expiration > 0 then
        safe_remaining = math_max(0, safe_expiration - GetTime())
    elseif (not safe_remaining or safe_remaining <= 0) and old_entry and old_entry.remaining then
        safe_remaining = old_entry.remaining
    end
    return safe_duration, safe_expiration, safe_remaining
end

local function get_safe_spell_id(raw_spell_id, old_entry)
    if raw_spell_id ~= nil and not issecretvalue(raw_spell_id) then
        return raw_spell_id
    end
    if old_entry and old_entry.spell_id ~= nil and not issecretvalue(old_entry.spell_id) then
        return old_entry.spell_id
    end
    return nil
end

local function get_aura_spell_id(aura, fallback_entry)
    if aura then
        local sid = aura.spellId
        if sid ~= nil and not issecretvalue(sid) then return sid end
        sid = aura.spellID
        if sid ~= nil and not issecretvalue(sid) then return sid end
    end
    return get_safe_spell_id(nil, fallback_entry)
end

local function custom_aura_expires(iid)
    if not (iid and C_UnitAuras.DoesAuraHaveExpirationTime) then return nil end
    local ok, expires = pcall(C_UnitAuras.DoesAuraHaveExpirationTime, "player", iid)
    if ok and type(expires) == "boolean" and not issecretvalue(expires) then
        return expires
    end
    return nil
end

local function classify_custom_for_timer(is_helpful, iid, remaining, duration, short_threshold, fallback_category)
    if not is_helpful then return "debuff" end
    if remaining == nil then
        local expires = custom_aura_expires(iid)
        if expires == false then return "static" end
        if fallback_category then
            return fallback_category
        end
        return "short"
    end
    if remaining <= 0 then return "static" end
    if duration ~= nil and not issecretvalue(duration) and duration == 0 then return "static" end
    if remaining <= short_threshold then return "short" end
    return "long"
end

local function build_custom_aura_entry(aura, aura_filter, short_threshold, custom_order, old_entry)
    if not aura then return nil end
    local iid = aura.auraInstanceID
    if not iid then return nil end

    local duration = aura.duration
    local expiration = aura.expirationTime
    local remaining = compute_remaining(duration, expiration)

    local need_live = (remaining == nil) or issecretvalue(remaining) or issecretvalue(expiration)
    local live_remaining, live_expiration = read_live_aura_timing(iid, need_live)
    if live_remaining then
        remaining = live_remaining
    end

    local stacks, live_count = get_aura_stack_counts(aura, iid)
    local is_helpful = aura_filter:find("HELPFUL", 1, true) ~= nil
    local fallback_category = old_entry and old_entry.category
    local category = classify_custom_for_timer(is_helpful, iid, remaining, duration, short_threshold, fallback_category)
    local safe_duration, safe_expiration, safe_remaining =
        resolve_safe_timing(duration, expiration, remaining, live_remaining, live_expiration, old_entry)

    return {
        instance_id = iid,
        spell_id = get_aura_spell_id(aura, old_entry),
        name = aura.name,
        icon = aura.icon,
        duration = safe_duration,
        expiration = safe_expiration,
        remaining = safe_remaining or 0,
        count = stacks,
        scan_remaining = live_remaining,
        live_count = live_count,
        filter = aura_filter,
        is_helpful = is_helpful,
        category = category,
        order_key = aura.auraInstanceID,
        custom_order = custom_order,
        added_at = (old_entry and old_entry.added_at) or GetTime(),
    }
end

function M.clear_custom_aura_scan_cache()
    wipe(_custom_aura_scan_cache)
end

function M.scan_custom_aura_map(frame, custom_entry, target_map, max_limit, short_threshold)
    if not (frame and custom_entry and target_map and C_UnitAuras.GetAuraDataByIndex) then return end
    local aura_filter = M.get_custom_aura_filter(custom_entry)
    max_limit = max_limit or M.AURA_FRAME_LIMIT
    short_threshold = short_threshold or (M.db and M.db.short_threshold) or M.DEFAULT_SHORT_THRESHOLD

    local cache_key = aura_filter .. "|" .. tostring(short_threshold)
    local cached = _custom_aura_scan_cache[cache_key]
    local needs_old_map = not cached or ((not cached.complete) and #cached.entries < max_limit)
    local old_map
    if needs_old_map then
        old_map = _scratch_custom_old_map
        wipe(old_map)
        for iid, entry in pairs(target_map) do
            old_map[iid] = entry
        end
    end
    wipe(target_map)

    if not cached then
        cached = { entries = {}, next_index = 1, complete = false }
        _custom_aura_scan_cache[cache_key] = cached
    end

    local entries = cached.entries
    while (not cached.complete) and #entries < max_limit do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", cached.next_index, aura_filter)
        cached.next_index = cached.next_index + 1
        if not ok or not aura then
            cached.complete = true
            break
        end
        local iid = aura.auraInstanceID
        local old_entry = old_map and iid and old_map[iid]
        local entry = build_custom_aura_entry(aura, aura_filter, short_threshold, #entries + 1, old_entry)
        if entry then
            entries[#entries + 1] = entry
        end
    end

    for i = 1, math.min(max_limit, #entries) do
        local entry = entries[i]
        target_map[entry.instance_id] = entry
    end
end

local function get_spell_display(spell_id)
    if not (spell_id and C_Spell and C_Spell.GetSpellInfo) then return nil, nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, spell_id)
    if ok and info then
        return info.name, info.iconID or info.originalIconID
    end
    return nil, nil
end

local function get_spell_cooldown_duration_object(spell_id, uses_charges)
    if not (spell_id and C_Spell and C_Spell.GetSpellCooldownDuration) then return nil end
    if issecretvalue(spell_id) then return nil end
    if uses_charges and C_Spell.GetSpellChargeDuration then
        local charge_ok, charge_duration = pcall(C_Spell.GetSpellChargeDuration, spell_id)
        if charge_ok and charge_duration then return charge_duration end
    end
    local ok, duration_object = pcall(C_Spell.GetSpellCooldownDuration, spell_id, true)
    if ok then return duration_object end
    return nil
end

local function get_readable_spell_cooldown(spell_id)
    if not (spell_id and C_Spell and C_Spell.GetSpellCooldown) then
        return 0, 0, 0, false
    end
    local ok, is_active, is_on_gcd, start_time, duration = pcall(function()
        local cooldown = C_Spell.GetSpellCooldown(spell_id)
        if not cooldown then return nil end
        return rawget(cooldown, "isActive"), cooldown.isOnGCD, cooldown.startTime, cooldown.duration
    end)
    if not ok or is_on_gcd == true or is_active ~= true then
        return 0, 0, 0, false
    end
    if issecretvalue(start_time) or issecretvalue(duration) then
        return 0, 0, 0, true
    end
    if not (start_time and duration) or duration <= GCD_GREY_THRESHOLD then
        return 0, 0, 0, false
    end
    local expiration = start_time + duration
    return expiration, duration, math.max(0, expiration - GetTime()), expiration > GetTime()
end

local function get_effective_cdm_spell_id(info)
    if not info then return nil end
    local spell_id = info.overrideSpellID or info.spellID
    if spell_id == nil or issecretvalue(spell_id) then return nil end
    return spell_id
end

-- Populates target_map from the public CDM category and cooldown APIs.
-- Cooldown mode builds only the addon-owned cooldown layer. Managed Aura slots
-- overlay active Auras through Blizzard native bindings; Aura mode is rendered
-- entirely by compact managed Aura groups and therefore returns no map entries.
function M.add_cooldown_viewer_category_entries(target_map, category)
    if not (M.db and M.db["cooldown_mode_" .. category]) then return end
    local records = M.get_ordered_cdm_records and M.get_ordered_cdm_records(category)
    if not records then return end

    for _, record in ipairs(records) do
        local cooldown_id = record.cooldown_id
        local info = record.info
        local spell_id = get_effective_cdm_spell_id(info)
        local name, icon = get_spell_display(spell_id)
        if cooldown_id and spell_id and icon then
            local expiration, duration, remaining, grey_cooldown =
                get_readable_spell_cooldown(spell_id)
            local duration_object = get_spell_cooldown_duration_object(
                spell_id,
                info and info.charges == true
            )
            local key = "cd_" .. tostring(cooldown_id)
            target_map[key] = {
                instance_id       = key,
                cooldown_id       = cooldown_id,
                is_spell_cooldown = true,
                spell_id          = spell_id,
                name              = name or tostring(spell_id),
                icon              = icon,
                duration          = duration,
                duration_object   = duration_object,
                grey_cooldown     = grey_cooldown,
                remaining         = remaining,
                expiration        = expiration,
                count             = 0,
                live_count        = nil,
                is_helpful        = true,
                category          = category,
                filter            = "HELPFUL",
                cdm_order         = record.order,
                order_key         = "cdm|" .. tostring(record.order),
            }
        end
    end
end

--#endregion SHARED HELPERS ====================================================
