-- Unified aura scanning and classification for all aura frame categories.
-- M.unified_scan() runs one pass over all player buffs and debuffs, classifying each into M._aura_map
-- with an entry.category ("static"/"short"/"long"/"debuff") and entry.is_helpful flag.
-- It also rebuilds per-category bucket maps so preset frames do not each filter the full master map.
-- Custom frames scan with a selected AuraFilters string.

local addon_name, addon = ...

local floor      = math.floor
local math_max   = math.max
local GetTime    = GetTime
local wipe       = wipe
local issecretvalue = issecretvalue
local C_UnitAuras   = C_UnitAuras
local C_Spell       = C_Spell
local format        = format
local GCD_GREY_THRESHOLD = 2.0

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

-- Scratch tables reused every unified_scan call to avoid per-scan allocation.
local _scratch_old_map      = {}
local _scratch_old_cat      = {}
local _scratch_seen_iids    = {}
local _scratch_added_by_key = {}
local _scratch_added_lookup = {}
local _scratch_viewer_children = {}
local _scratch_custom_old_map = {}
local _custom_aura_scan_cache = {}
local AURA_SCAN_BUCKET_CATEGORIES = { "static", "short", "long", "debuff" }

--#region SHARED HELPERS =======================================================

local function reset_aura_category_buckets()
    M._aura_maps_by_category = M._aura_maps_by_category or {}
    for _, category in ipairs(AURA_SCAN_BUCKET_CATEGORIES) do
        local bucket = M._aura_maps_by_category[category]
        if bucket then
            wipe(bucket)
        else
            M._aura_maps_by_category[category] = {}
        end
    end
    return M._aura_maps_by_category
end

local function add_to_category_bucket(buckets, entry)
    local category = entry and entry.category
    local bucket = category and buckets[category]
    local iid = entry and entry.instance_id
    if bucket and iid ~= nil then
        bucket[iid] = entry
    end
end

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

-- Build an entry table.
local function make_entry(iid, name, icon, duration, expiration, spell_id, dispel_name, rem, count, is_helpful, category, added_at)
    return {
        instance_id  = iid,
        name         = name,
        icon         = icon,
        duration     = duration,
        expiration   = expiration,
        spell_id     = spell_id,
        dispel_name  = dispel_name,
        remaining    = rem,
        count        = count,
        is_helpful   = is_helpful,
        category     = category,
        filter       = is_helpful and "HELPFUL" or "HARMFUL",
        added_at     = added_at or GetTime(),
        order_key    = make_order_key(spell_id, name, icon, is_helpful),
    }
end

-- Update an existing entry in place (avoids allocation on unchanged auras).
local function update_entry(entry, name, icon, duration, expiration, spell_id, dispel_name, rem, count, scan_rem, live_cnt, category)
    entry.name          = name
    entry.icon          = icon
    entry.duration      = duration
    entry.expiration    = expiration
    entry.spell_id      = spell_id
    entry.dispel_name   = dispel_name
    entry.remaining     = rem
    entry.count         = count
    entry.scan_remaining = scan_rem
    entry.live_count    = live_cnt
    entry.order_key     = make_order_key(spell_id, name, icon, entry.is_helpful)
    if category then entry.category = category end
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

local function get_aura_data_by_instance_id(iid)
    if not (iid and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return nil end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", iid)
    if ok then return aura end
    return nil
end

local function build_cdm_active_aura_entry(iid, category, cdm_order)
    local aura = get_aura_data_by_instance_id(iid)
    if not aura then return nil end

    local is_harmful = aura.isHarmful == true
    if is_harmful then return nil end

    local duration = aura.duration
    local expiration = aura.expirationTime
    local remaining = compute_remaining(duration, expiration)
    local need_live = (remaining == nil) or issecretvalue(remaining) or issecretvalue(expiration)
    local live_remaining, live_expiration = read_live_aura_timing(iid, need_live)
    local stacks, live_count = get_aura_stack_counts(aura, iid)
    local safe_duration, safe_expiration, safe_remaining =
        resolve_safe_timing(duration, expiration, remaining, live_remaining, live_expiration, nil)

    local entry = make_entry(
        iid,
        aura.name,
        aura.icon,
        safe_duration,
        safe_expiration,
        get_aura_spell_id(aura),
        aura.dispelName,
        safe_remaining or 0,
        stacks,
        true,
        category,
        GetTime()
    )
    entry.scan_remaining = live_remaining
    entry.live_count = live_count
    entry.cdm_order = cdm_order
    entry.order_key = "cdm|" .. tostring(cdm_order)
    return entry
end

function M.clear_custom_aura_scan_cache()
    wipe(_custom_aura_scan_cache)
end

function M.scan_custom_aura_map(frame, custom_entry, target_map, max_limit, short_threshold)
    if not (frame and custom_entry and target_map and C_UnitAuras.GetAuraDataByIndex) then return end
    local aura_filter = M.get_custom_aura_filter(custom_entry)
    max_limit = max_limit or custom_entry.max_icons or M.MAX_ICONS_LIMIT
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

local function get_spell_cooldown_duration_object(spell_id)
    if not (spell_id and C_Spell and C_Spell.GetSpellCooldownDuration) then return nil end
    if issecretvalue(spell_id) then return nil end
    local ok, duration_object = pcall(C_Spell.GetSpellCooldownDuration, spell_id)
    if ok then return duration_object end
    return nil
end

local function is_spell_on_real_cooldown(spell_id)
    if not (spell_id and C_Spell and C_Spell.GetSpellCooldown) then return false end
    if issecretvalue(spell_id) then return false end

    local ok, cooldown = pcall(C_Spell.GetSpellCooldown, spell_id)
    if not (ok and cooldown) then return false end

    local is_on_gcd = cooldown.isOnGCD
    if is_on_gcd ~= nil then
        if issecretvalue(is_on_gcd) then return false end
        if is_on_gcd then return false end
    end

    local start_time = cooldown.startTime
    local duration = cooldown.duration
    if not (start_time and duration) then return false end
    if issecretvalue(start_time) or issecretvalue(duration) then return false end
    if duration <= GCD_GREY_THRESHOLD then return false end

    return (start_time + duration) > GetTime()
end

local function store_viewer_children(...)
    -- Reuse one scratch table instead of allocating { viewer:GetChildren() }
    -- during repeated CDM walks. Callers must consume it before the next call.
    local children = _scratch_viewer_children
    wipe(children)
    for i = 1, select("#", ...) do
        children[i] = select(i, ...)
    end
    return children
end

local function copy_viewer_children(viewer)
    return store_viewer_children(viewer:GetChildren())
end

-- Cache populated by hooks on Blizzard Cooldown widgets.
-- Keyed by Blizzard cooldownID: { expiration, duration, duration_object, spell_id, name, icon }.
-- Used as a fallback for cooldown display; active aura display prefers the
-- Blizzard child auraInstanceID, and grey state comes from real spell cooldown data.
M._cd_hook_cache = M._cd_hook_cache or {}
M._cd_child_state = M._cd_child_state or setmetatable({}, { __mode = "k" })

local function get_cd_child_state(child)
    local state = M._cd_child_state[child]
    if not state then
        state = {}
        M._cd_child_state[child] = state
    end
    return state
end

local function get_child_cooldown_id(child)
    if not child then return nil end
    if child.GetCooldownID then
        local ok, cooldown_id = pcall(child.GetCooldownID, child)
        if ok and cooldown_id ~= nil and not issecretvalue(cooldown_id) then
            return cooldown_id
        end
    end

    local cooldown_id = child.cooldownID
    if cooldown_id ~= nil and not issecretvalue(cooldown_id) then
        return cooldown_id
    end
    return nil
end

local function get_child_cooldown_info(child)
    if not child then return nil end
    if child.GetCooldownInfo then
        local ok, info = pcall(child.GetCooldownInfo, child)
        if ok and info then return info end
    end
    return child.cooldownInfo
end

local function get_child_spell_id(child)
    if not child then return nil end
    if child.GetSpellID then
        local ok, spell_id = pcall(child.GetSpellID, child)
        if ok and spell_id ~= nil and not issecretvalue(spell_id) then
            return spell_id
        end
    end

    local info = get_child_cooldown_info(child)
    if not info then return nil end
    local spell_id = info.overrideSpellID or info.spellID
    if spell_id ~= nil and not issecretvalue(spell_id) then
        return spell_id
    end
    return nil
end

local function get_child_aura_instance_id(child)
    if not child then return nil end
    if child.GetAuraSpellInstanceID then
        local ok, aura_instance_id = pcall(child.GetAuraSpellInstanceID, child)
        if ok and aura_instance_id then return aura_instance_id end
    end
    return child.auraInstanceID
end

function M.clear_cooldown_viewer_child_cache(category)
    local viewer = M.get_cdm_viewer_frame(category)
    if not viewer then return end
    local children = copy_viewer_children(viewer)
    for _, child in ipairs(children) do
        local state = get_cd_child_state(child)
        state.cooldown_id = nil
        state.spell_id = nil
        state.name = nil
        state.icon = nil
    end
end

local function queue_cooldown_viewer_refresh(category)
    M.queue_wow_cooldown_refresh("hook", category)
end

-- Lazily attaches hooks to a CooldownViewer child frame on first encounter.
-- The hooks preserve Blizzard's cooldown timing object/values when the viewer
-- writes them. This supplements the live child auraInstanceID path; it is not
-- the primary source for active aura state.
local function hook_cd_item_frame(child)
    local cd = child.Cooldown
    if not cd then return end
    local child_state = get_cd_child_state(child)
    if child_state.hooked_cd == cd then
        return
    end
    child_state.hooked_cd = cd

    local cache = M._cd_hook_cache

    -- Blizzard reuses CooldownViewer child frames across CDM categories/spells.
    -- Clear cached display identity whenever the child identity changes; otherwise
    -- Utility can render a current cooldown with a stale Essential spell name/icon.
    local function set_child_cooldown_id(child_frame, cooldown_id)
        if cooldown_id == nil or issecretvalue(cooldown_id) then return false end
        local state = get_cd_child_state(child_frame)
        if state.cooldown_id ~= cooldown_id then
            state.cooldown_id = cooldown_id
            state.name = nil
            state.icon = nil
        end
        return true
    end

    local function set_child_spell_id(child_frame, spell_id)
        if spell_id == nil or issecretvalue(spell_id) then return false end
        local state = get_cd_child_state(child_frame)
        if state.spell_id ~= spell_id then
            state.spell_id = spell_id
            state.name = nil
            state.icon = nil
        end
        return true
    end

    local function refresh_child_identity()
        local state = get_cd_child_state(child)
        local cooldown_id = get_child_cooldown_id(child)
        set_child_cooldown_id(child, cooldown_id)

        local info = get_child_cooldown_info(child)
        if info then
            local cid = info.cooldownID or info.cooldownId
            set_child_cooldown_id(child, cid)
            local sid = get_child_spell_id(child)
            set_child_spell_id(child, sid)
        end

        local sid = state.spell_id
        if sid then
            local cached = cache[state.cooldown_id]
            if cached and cached.name and cached.icon then
                state.name = cached.name
                state.icon = cached.icon
            else
                local name, icon = get_spell_display(sid)
                if name or icon then
                    state.name = name or state.name
                    state.icon = icon or state.icon
                end
            end
        end

        return state.cooldown_id
    end

    local function cache_timing(expiration, duration, duration_object)
        local cooldown_id = refresh_child_identity()
        if not cooldown_id then return end
        local state = get_cd_child_state(child)
        local sid = state.spell_id
        cache[cooldown_id] = {
            expiration = expiration,
            duration = duration,
            duration_object = duration_object,
            spell_id = sid,
            name = state.name,
            icon = state.icon,
        }
        queue_cooldown_viewer_refresh(get_cd_child_state(child).category)
    end

    -- Standard cooldown path: arguments are passed by Blizzard code, so read
    -- them directly when they are not secret. Ignore GCD-sized values here;
    -- GCD animation can still arrive through the DurationObject path.
    pcall(hooksecurefunc, cd, "SetCooldown", function(_, start, duration)
        if not (start and duration) then return end
        if issecretvalue(start) or issecretvalue(duration) then return end
        if duration <= 1.5 then return end  -- GCD
        cache_timing(start + duration, duration, nil)
    end)

    -- DurationObject path (modern combat cooldowns): preserve the object and
    -- only use numeric methods when readable. The renderer can pass the object
    -- onward without unpacking secret values.
    if cd.SetCooldownFromDurationObject then
        pcall(hooksecurefunc, cd, "SetCooldownFromDurationObject", function(_, dur_obj)
            if not dur_obj then return end
            local remaining, expiration
            local ok_r, result_r = pcall(function() return dur_obj:GetRemainingDuration() end)
            if ok_r and result_r and not issecretvalue(result_r) then
                remaining = result_r
            end
            local ok_e, result_e = pcall(function() return dur_obj:GetEndTime() end)
            if ok_e and result_e and not issecretvalue(result_e) then
                expiration = result_e
            end
            cache_timing(expiration, remaining, dur_obj)
        end)
    end

    refresh_child_identity()
end

local function install_cooldown_viewer_item_hooks()
    if M._lstweeks_cdv_item_hooks_installed then return end
    if not (CooldownViewerItemDataMixin and hooksecurefunc) then return end
    M._lstweeks_cdv_item_hooks_installed = true

    local function on_item_changed(child, cooldown_id)
        local state = get_cd_child_state(child)
        if cooldown_id ~= nil and not issecretvalue(cooldown_id) and state.cooldown_id ~= cooldown_id then
            state.cooldown_id = cooldown_id
            state.name = nil
            state.icon = nil
        end
        hook_cd_item_frame(child)
        queue_cooldown_viewer_refresh(state.category)
    end

    if CooldownViewerItemDataMixin.SetCooldownID then
        pcall(hooksecurefunc, CooldownViewerItemDataMixin, "SetCooldownID", on_item_changed)
    end

    if CooldownViewerItemDataMixin.ClearCooldownID then
        pcall(hooksecurefunc, CooldownViewerItemDataMixin, "ClearCooldownID", function(child)
            local state = get_cd_child_state(child)
            state.cooldown_id = nil
            queue_cooldown_viewer_refresh(state.category)
        end)
    end
end

-- Populates target_map by walking the Blizzard CooldownViewer frame for this category.
-- Aura mode:
--   Reads the child mixin's aura instance ID and maps directly to M._aura_map entries.
-- Cooldown mode:
--   1. Active phase: prefer the child mixin's live aura instance ID from the Blizzard CDM viewer.
--   2. Cooldown phase: use the hooked DurationObject/cache, with spell cooldown
--      duration as fallback for the overlay.
--   3. Grey state: use C_Spell.GetSpellCooldown(spellID), explicitly ignoring GCD.
function M.add_cooldown_viewer_category_entries(target_map, category)
    local viewer = M.get_cdm_viewer_frame(category)
    if not viewer then return end

    local cooldown_mode = M.db and M.db["cooldown_mode_" .. category]

    if cooldown_mode then
        install_cooldown_viewer_item_hooks()
        local now   = GetTime()
        local cache = M._cd_hook_cache
        local children = copy_viewer_children(viewer)
        for child_index, child in ipairs(children) do
            local cdm_order = child_index
            local left = child.GetLeft and child:GetLeft()
            local top = child.GetTop and child:GetTop()
            if left and top and not issecretvalue(left) and not issecretvalue(top) then
                cdm_order = (top * -10000) + left
            end
            local state = get_cd_child_state(child)
            state.category = category
            hook_cd_item_frame(child)

            local iid = get_child_aura_instance_id(child)
            local has_active_aura_entry = false
            if iid then
                local aura_entry = M._aura_map[iid]
                if not aura_entry then
                    aura_entry = build_cdm_active_aura_entry(iid, category, cdm_order)
                    if aura_entry then
                        M._aura_map[iid] = aura_entry
                    end
                end
                if aura_entry then
                    aura_entry.cdm_order = cdm_order
                    target_map[iid] = aura_entry
                    has_active_aura_entry = true
                end
            end

            -- Prefer readable cooldownID, fall back to the per-child cached ID set by hooks.
            local cooldown_id = get_child_cooldown_id(child)
            local info = get_child_cooldown_info(child)
            local saw_identity = false
            if info then
                local cid = info.cooldownID or info.cooldownId
                if cid ~= nil and not issecretvalue(cid) then
                    if state.cooldown_id ~= cid then
                        state.cooldown_id = cid
                        state.name = nil
                        state.icon = nil
                    end
                    cooldown_id = cid
                    saw_identity = true
                end
                local sid = get_child_spell_id(child)
                if sid and not issecretvalue(sid) then
                    if state.spell_id ~= sid then
                        state.spell_id = sid
                        state.name = nil
                        state.icon = nil
                    end
                    saw_identity = true
                end
            end
            if cooldown_id ~= nil and not issecretvalue(cooldown_id) then
                saw_identity = true
            end
            if not saw_identity then
                state.cooldown_id = nil
                state.spell_id = nil
                state.name = nil
                state.icon = nil
            end
            cooldown_id = cooldown_id or state.cooldown_id

            local spell_id = state.spell_id
            local name = state.name
            local icon = state.icon
            if spell_id and (not name or not icon) then
                local spell_name, spell_icon = get_spell_display(spell_id)
                name = name or spell_name
                icon = icon or spell_icon
                state.name = name
                state.icon = icon
            end

            local cached = cooldown_id and cache[cooldown_id]
            if cached then
                name = name or cached.name
                icon = icon or cached.icon
                spell_id = spell_id or cached.spell_id
            end

            -- Blizzard can retain a child aura instance ID after the active aura
            -- expires in combat. Fall back to cooldown display unless we mapped
            -- a live aura.
            if not has_active_aura_entry and cooldown_id and icon then
                local expiration = cached and cached.expiration or 0
                local duration = cached and cached.duration or 0
                local remaining = (expiration and expiration > now) and (expiration - now) or 0
                local duration_object = (cached and cached.duration_object) or get_spell_cooldown_duration_object(spell_id)
                local grey_cooldown = is_spell_on_real_cooldown(spell_id)
                local key = "cd_" .. tostring(cooldown_id)
                target_map[key] = {
                    instance_id       = key,
                    is_spell_cooldown = true,
                    spell_id          = spell_id,
                    name              = name or tostring(spell_id or cooldown_id),
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
                    cdm_order         = cdm_order,
                    order_key         = "cdm|" .. tostring(cdm_order),
                }
            end
        end
    else
        local children = copy_viewer_children(viewer)
        for _, child in ipairs(children) do
            local state = get_cd_child_state(child)
            state.category = category
            local iid = get_child_aura_instance_id(child)
            if iid then
                local entry = M._aura_map[iid]
                if not entry then
                    entry = build_cdm_active_aura_entry(iid, category)
                    if entry then
                        M._aura_map[iid] = entry
                    end
                end
                if entry then target_map[iid] = entry end
            end
        end
    end
end

local function build_added_by_key(map)
    local by_key = _scratch_added_by_key
    wipe(by_key)
    for _, entry in pairs(map) do
        local key = entry.order_key
        if key and entry.added_at and (not by_key[key] or entry.added_at < by_key[key]) then
            by_key[key] = entry.added_at
        end
    end
    return by_key
end

local function build_added_lookup(info)
    local lookup = _scratch_added_lookup
    wipe(lookup)
    local count  = 0
    if not info then return lookup, count end
    if info.addedAuras then
        for _, a in ipairs(info.addedAuras) do
            local iid = a and a.auraInstanceID
            if iid then lookup[iid] = a; count = count + 1 end
        end
    elseif info.addedAuraInstanceIDs then
        for _, iid in ipairs(info.addedAuraInstanceIDs) do
            if iid then lookup[iid] = true; count = count + 1 end
        end
    end
    return lookup, count
end

--#endregion SHARED HELPERS ====================================================

--#region HELPFUL AURA CLASSIFICATION ==========================================
-- Returns "static" | "short" | "long" for a helpful aura given its remaining time.
-- Returns nil when classification is deferred to caller (secret fields).
local function classify_helpful(classify_rem, short_threshold)
    if classify_rem == nil then return nil end
    if classify_rem == 0 then return "static" end
    if classify_rem <= short_threshold then return "short" end
    return "long"
end

local function get_max_icons_for_frame_defs(db, hint, include_debuff)
    local max_icons = hint or 0
    for _, frame_def in ipairs(M.FRAME_DEFS or {}) do
        if (frame_def.is_debuff == true) == include_debuff then
            max_icons = math_max(max_icons, db["max_icons_" .. frame_def.key] or M.MAX_ICONS_LIMIT)
        end
    end
    return max_icons
end

--#endregion HELPFUL AURA CLASSIFICATION =======================================

--#region UNIFIED SCAN =========================================================
-- Scans all player buffs and debuffs in one pass.
-- Populates M._aura_map: iid -> entry with is_helpful and category fields.
-- Preset frames filter by entry.category; custom frames use C_UnitAuras.GetAuraDataByIndex directly.
function M.unified_scan(info, short_threshold, max_helpful_hint, max_debuff_hint)
    M._aura_map = M._aura_map or {}
    local cur_map = M._aura_map
    local category_buckets = reset_aura_category_buckets()
    if M.clear_sorted_aura_ids_cache then
        M.clear_sorted_aura_ids_cache()
    end

    -- Snapshot old map for stable added_at and secret-field fallback.
    -- We build a shallow copy of keys only (old entries are referenced, not cloned).
    local old_map = _scratch_old_map
    wipe(old_map)
    for iid, entry in pairs(cur_map) do old_map[iid] = entry end

    local old_added_by_key = build_added_by_key(old_map)
    local added_lookup, added_count = build_added_lookup(info)

    local removed_count = 0
    local replacement_pref_cat = nil  -- category hint from a 1-for-1 swap
    if info and info.removedAuraInstanceIDs then
        removed_count = #info.removedAuraInstanceIDs
        if removed_count == 1 and added_count == 1 then
            local rid = info.removedAuraInstanceIDs[1]
            local old = old_map[rid]
            if old then replacement_pref_cat = old.category end
        end
    end

    local db = M.db
    local seen_iids = _scratch_seen_iids
    wipe(seen_iids)

    -- -------------------------------------------------------------------------
    -- PASS 1: HELPFUL (buffs)
    -- -------------------------------------------------------------------------
    local max_helpful = get_max_icons_for_frame_defs(db, max_helpful_hint, false)

    local old_cat_by_spell = nil
    local function get_old_category_by_spell(spell_id)
        if not spell_id then return nil end
        if not old_cat_by_spell then
            old_cat_by_spell = _scratch_old_cat
            wipe(old_cat_by_spell)
            for _, entry in pairs(old_map) do
                if entry.is_helpful and entry.spell_id and entry.category then
                    old_cat_by_spell[entry.spell_id] = entry.category
                end
            end
        end
        return old_cat_by_spell[spell_id]
    end

    local i, count = 1, 0
    while count < max_helpful do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then break end
        i = i + 1

        local iid = aura.auraInstanceID
        if not iid then break end

        local old_entry     = old_map[iid]
        local safe_spell_id = get_aura_spell_id(aura, old_entry)
        local duration      = aura.duration
        local expiration    = aura.expirationTime
        local rem           = compute_remaining(duration, expiration)

        -- GetAuraDuration is readable even when scan fields are secret (combat).
        local need_live = (rem == nil) or issecretvalue(rem) or issecretvalue(expiration)
        local live_remaining, live_expiration = read_live_aura_timing(iid, need_live)

        local classify_rem = live_remaining or rem

        local category = nil

        if classify_rem ~= nil then
            category = classify_helpful(classify_rem, short_threshold)
        else
            -- Secret fields: use DoesAuraHaveExpirationTime as final boolean.
            local expires = C_UnitAuras.DoesAuraHaveExpirationTime("player", iid)
            local expires_known
            if type(expires) ~= "boolean" or issecretvalue(expires) then
                expires_known = nil
            else
                expires_known = expires
            end

            if expires_known == false then
                category = "static"
            elseif expires_known == true then
                local old_cat = (old_entry and old_entry.category)
                    or get_old_category_by_spell(safe_spell_id)
                category = old_cat or "short"
            else
                local old_cat = (old_entry and old_entry.category)
                    or get_old_category_by_spell(safe_spell_id)
                if old_cat then
                    category = old_cat
                elseif added_lookup[iid] and replacement_pref_cat then
                    category = replacement_pref_cat
                else
                    category = "short"
                end
            end
        end

        if category then
            local name  = aura.name
            local icon  = aura.icon
            local dispel = aura.dispelName
            if issecretvalue(dispel) then dispel = nil end

            local stacks, live_count = get_aura_stack_counts(aura, iid)
            local safe_duration, safe_expiration, safe_remaining =
                resolve_safe_timing(duration, expiration, rem, live_remaining, live_expiration, old_entry)

            local entry = cur_map[iid]
            if entry then
                update_entry(entry, name, icon, safe_duration, safe_expiration,
                    safe_spell_id, dispel, safe_remaining or 0, stacks, live_remaining, live_count, category)
            else
                local key = make_order_key(aura.spellId, name, icon, true)
                local recovered_at = (old_entry and old_entry.added_at)
                    or (key and old_added_by_key[key]) or nil
                entry = make_entry(iid, name, icon, safe_duration, safe_expiration,
                    safe_spell_id, dispel, safe_remaining or 0, stacks,
                    true, category, recovered_at or GetTime())
                entry.scan_remaining = live_remaining
                entry.live_count     = live_count
                cur_map[iid] = entry
            end
            seen_iids[iid] = true
            add_to_category_bucket(category_buckets, entry)

            count = count + 1
        end
    end

    -- -------------------------------------------------------------------------
    -- PASS 2: HARMFUL (debuffs)
    -- -------------------------------------------------------------------------
    local max_debuff = get_max_icons_for_frame_defs(db, max_debuff_hint, true)

    i, count = 1, 0
    while count < max_debuff do
        local aura = C_UnitAuras.GetDebuffDataByIndex("player", i)
        if not aura then break end
        i = i + 1

        local iid = aura.auraInstanceID
        if not iid then break end

        local old_entry     = old_map[iid]
        local duration      = aura.duration
        local expiration    = aura.expirationTime
        local name          = aura.name
        local icon          = aura.icon
        local dispel        = aura.dispelName
        if issecretvalue(dispel) then dispel = nil end

        local rem = compute_remaining(duration, expiration)
        local belongs = false

        if rem == nil then
            -- Secret fields: use DoesAuraHaveExpirationTime.
            local expires = C_UnitAuras.DoesAuraHaveExpirationTime("player", iid)
            local expires_known
            if type(expires) ~= "boolean" then
                expires_known = false
            elseif issecretvalue(expires) then
                expires_known = nil
            else
                expires_known = expires
            end

            local added_data = added_lookup and added_lookup[iid]
            local is_new = (old_map[iid] == nil) and (added_data ~= nil)

            if is_new then
                -- Debuffs always belong to the debuff frame regardless of timing.
                belongs = true
            elseif expires_known == nil then
                belongs = (old_map[iid] ~= nil)
            else
                belongs = true
            end
        else
            -- Readable debuffs always belong to the debuff frame.
            belongs = true
        end

        if belongs then
            local safe_spell_id = get_safe_spell_id(aura.spellId, old_entry)
            local stacks, live_count = get_aura_stack_counts(aura, iid)
            local safe_duration, safe_expiration, safe_remaining =
                resolve_safe_timing(duration, expiration, rem, nil, nil, old_entry)

            local entry = cur_map[iid]
            if entry then
                update_entry(entry, name, icon, safe_duration, safe_expiration,
                    safe_spell_id, dispel, safe_remaining or 0, stacks, nil, live_count, "debuff")
                entry.is_helpful = false
            else
                local key = make_order_key(aura.spellId, name, icon, false)
                local recovered_at = (old_entry and old_entry.added_at)
                    or (key and old_added_by_key[key]) or nil
                entry = make_entry(iid, name, icon, safe_duration, safe_expiration,
                    safe_spell_id, dispel, safe_remaining or 0, stacks,
                    false, "debuff", recovered_at or GetTime())
                entry.live_count = live_count
                cur_map[iid] = entry
            end
            seen_iids[iid] = true
            add_to_category_bucket(category_buckets, entry)
            count = count + 1
        end
    end

    -- -------------------------------------------------------------------------
    -- CLEANUP: remove stale IIDs not seen this scan pass.
    -- -------------------------------------------------------------------------
    for iid in pairs(cur_map) do
        if not seen_iids[iid] then cur_map[iid] = nil end
    end
end

--#endregion UNIFIED SCAN ======================================================
