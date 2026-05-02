-- Unified aura scanning and classification for all aura frame categories.
-- M.unified_scan() runs one pass over all player buffs and debuffs, classifying each into M._aura_map
-- with an entry.category ("static"/"short"/"long"/"debuff") and entry.is_helpful flag.
-- Spell learning (M._known_static, M._known_long) is session-scoped only — never written to DB.
-- Custom frames post-filter M._aura_map by whitelist; preset frames filter by entry.category.

local addon_name, addon = ...

local floor      = math.floor
local math_max   = math.max
local GetTime    = GetTime
local wipe       = wipe
local issecretvalue = issecretvalue
local C_UnitAuras   = C_UnitAuras
local C_Spell       = C_Spell
local format        = format

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

-- Scratch tables reused every unified_scan call to avoid per-scan allocation.
local _scratch_old_map      = {}
local _scratch_old_cat      = {}
local _scratch_seen_iids    = {}
local _scratch_added_by_key = {}

-- Session-scoped spell classification memory (reset on every login/reload, never persisted).
-- Prevents mid-session category jumps when aura fields go secret in combat.
M._known_static = M._known_static or {}  -- spell_id -> true (confirmed permanent)
M._known_long   = M._known_long   or {}  -- spell_id -> true (confirmed long-duration)

-- ============================================================================
-- SHARED HELPERS

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
local function update_entry(entry, name, icon, duration, expiration, spell_id, dispel_name, rem, count, live_rem, live_cnt, category)
    entry.name          = name
    entry.icon          = icon
    entry.duration      = duration
    entry.expiration    = expiration
    entry.spell_id      = spell_id
    entry.dispel_name   = dispel_name
    entry.remaining     = rem
    entry.count         = count
    entry.live_remaining = live_rem
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
    local sid = get_safe_spell_id(aura and aura.spellId, nil)
    if sid then return sid end
    sid = get_safe_spell_id(aura and aura.spellID, nil)
    if sid then return sid end
    return get_safe_spell_id(nil, fallback_entry)
end

-- Persist known aura identity when fields are readable.
local function learn_aura_identity(spell_id, name, icon, filter)
    if not (M.CacheAuraInfo and spell_id) then return end
    if issecretvalue(spell_id) then return end
    local safe_name = (name ~= nil and not issecretvalue(name)) and name or nil
    local safe_icon = (icon ~= nil and not issecretvalue(icon)) and icon or nil
    if safe_name or safe_icon then
        M.CacheAuraInfo(spell_id, safe_name, safe_icon, filter)
    end
end

local function learn_important_aura(spell_id, name, icon)
    if not (M.db and spell_id) then return end
    if issecretvalue(spell_id) then return end

    local safe_name = (name ~= nil and not issecretvalue(name)) and name or nil
    local safe_icon = (icon ~= nil and not issecretvalue(icon)) and icon or nil
    if not (safe_name or safe_icon) then return end

    M.db.important_aura_cache = M.db.important_aura_cache or {}
    local cached = M.db.important_aura_cache[spell_id]
    if not cached then
        cached = {}
        M.db.important_aura_cache[spell_id] = cached
    end
    if safe_name then cached.name = safe_name end
    if safe_icon then cached.icon = safe_icon end
    cached.seen = time()
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

-- Blizzard global frame names for each WoW Cooldown Manager category.
-- Children of these frames carry an auraInstanceID field when their aura is active.
local VIEWER_FRAME_NAMES = {
    essential     = "EssentialCooldownViewer",
    utility       = "UtilityCooldownViewer",
    tracked_buffs = "BuffIconCooldownViewer",
    tracked_bars  = "BuffBarCooldownViewer",
}

-- Cache populated by hooks on Blizzard's Cooldown widgets.
-- Keyed by Blizzard cooldownID: { expiration, duration, duration_object, spell_id, name, icon }
-- Captures timing at the moment Blizzard sets it — before it becomes secret to addon code.
M._cd_hook_cache = M._cd_hook_cache or {}

local function queue_cooldown_viewer_refresh()
    if M._cd_hook_refresh_pending then return end
    M._cd_hook_refresh_pending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            M._cd_hook_refresh_pending = false
            if M.refresh_wow_cooldown_frames then
                M.refresh_wow_cooldown_frames()
            end
        end)
    else
        M._cd_hook_refresh_pending = false
    end
end

-- Lazily attaches hooks to a CooldownViewer child frame on first encounter.
-- SetCooldown arguments (start, duration) are readable in the hook even during combat
-- because they are passed explicitly by Blizzard code — only C API return values are secret.
-- SetCooldownFromDurationObject uses the Duration object path instead.
-- child._lstweeks_cooldown_id is stable even when spell fields go secret.
local function hook_cd_item_frame(child)
    local cd = child.Cooldown
    if not cd then return end
    if child._lstweeks_cd_hooked == cd then
        return
    end
    child._lstweeks_cd_hooked = cd

    local cache = M._cd_hook_cache

    local function refresh_child_identity()
        local cooldown_id = child.cooldownID
        if cooldown_id ~= nil and not issecretvalue(cooldown_id) then
            child._lstweeks_cooldown_id = cooldown_id
        end

        local info = child.cooldownInfo
        if info then
            local cid = info.cooldownID or info.cooldownId
            if cid ~= nil and not issecretvalue(cid) then
                child._lstweeks_cooldown_id = cid
            end
            local sid = info.overrideSpellID or info.spellID
            if sid and not issecretvalue(sid) then
                child._lstweeks_spell_id = sid
            end
        end

        local sid = child._lstweeks_spell_id
        if sid then
            local cached = cache[child._lstweeks_cooldown_id]
            if not (cached and cached.name and cached.icon) then
                local name, icon = get_spell_display(sid)
                if name or icon then
                    child._lstweeks_cd_name = name or child._lstweeks_cd_name
                    child._lstweeks_cd_icon = icon or child._lstweeks_cd_icon
                end
            end
        end

        return child._lstweeks_cooldown_id
    end

    local function cache_timing(expiration, duration, duration_object)
        local cooldown_id = refresh_child_identity()
        if not cooldown_id then return end
        local sid = child._lstweeks_spell_id
        cache[cooldown_id] = {
            expiration = expiration,
            duration = duration,
            duration_object = duration_object,
            spell_id = sid,
            name = child._lstweeks_cd_name,
            icon = child._lstweeks_cd_icon,
        }
        queue_cooldown_viewer_refresh()
    end

    -- Standard cooldown path: arguments are not secret, read directly.
    pcall(hooksecurefunc, cd, "SetCooldown", function(_, start, duration)
        if not (start and duration) then return end
        if issecretvalue(start) or issecretvalue(duration) then return end
        if duration <= 1.5 then return end  -- GCD
        cache_timing(start + duration, duration, nil)
    end)

    -- Duration-object path (12.x combat cooldowns): preserve the object and only
    -- use numeric methods when readable. The renderer can pass the object onward.
    if cd.SetCooldownFromDurationObject then
        pcall(hooksecurefunc, cd, "SetCooldownFromDurationObject", function(_, dur_obj)
            if not dur_obj then return end
            local remaining, expiration
            local ok_r, result_r = pcall(function() return dur_obj:GetRemainingDuration() end)
            if ok_r and result_r and not issecretvalue(result_r) then
                remaining = result_r
            end
            local ok_e, result_e = pcall(function() return dur_obj:GetExpirationTime() end)
            if ok_e and result_e and not issecretvalue(result_e) then
                expiration = result_e
            end
            if remaining and remaining <= 1.5 then return end  -- GCD
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
        if cooldown_id ~= nil and not issecretvalue(cooldown_id) then
            child._lstweeks_cooldown_id = cooldown_id
        end
        hook_cd_item_frame(child)
        queue_cooldown_viewer_refresh()
    end

    if CooldownViewerItemDataMixin.SetCooldownID then
        pcall(hooksecurefunc, CooldownViewerItemDataMixin, "SetCooldownID", on_item_changed)
    end

    if CooldownViewerItemDataMixin.SetCooldownInfo then
        pcall(hooksecurefunc, CooldownViewerItemDataMixin, "SetCooldownInfo", function(child)
            on_item_changed(child)
        end)
    end

    if CooldownViewerItemDataMixin.ClearCooldownID then
        pcall(hooksecurefunc, CooldownViewerItemDataMixin, "ClearCooldownID", function(child)
            child._lstweeks_cooldown_id = nil
            queue_cooldown_viewer_refresh()
        end)
    end
end

-- Populates target_map by walking the Blizzard CooldownViewer frame for this category.
-- Aura mode:     reads child.auraInstanceID → maps directly to M._aura_map entries.
-- Cooldown mode: hooks Blizzard's Cooldown widgets to capture timing on write, then reads
--                from that cache — never queries secret values at scan time.
function M.add_cooldown_viewer_category_entries(target_map, category)
    local frame_name = VIEWER_FRAME_NAMES[category]
    if not frame_name then return end
    local viewer = _G[frame_name]
    if not viewer then return end

    local cooldown_mode = M.db and M.db["cooldown_mode_" .. category]

    if cooldown_mode then
        install_cooldown_viewer_item_hooks()
        local now   = GetTime()
        local cache = M._cd_hook_cache
        for _, child in ipairs({viewer:GetChildren()}) do
            hook_cd_item_frame(child)

            local iid = child.auraInstanceID
            if iid then
                local aura_entry = M._aura_map[iid]
                if aura_entry then
                    target_map[iid] = aura_entry
                end
            end

            -- Prefer readable cooldownID, fall back to the per-child cached ID set by hooks.
            local cooldown_id = child.cooldownID
            if cooldown_id ~= nil and issecretvalue(cooldown_id) then cooldown_id = nil end
            local info = child.cooldownInfo
            if info then
                local cid = info.cooldownID or info.cooldownId
                if cid ~= nil and not issecretvalue(cid) then
                    child._lstweeks_cooldown_id = cid
                    cooldown_id = cid
                end
                local sid = info.overrideSpellID or info.spellID
                if sid and not issecretvalue(sid) then
                    child._lstweeks_spell_id = sid
                end
            end
            cooldown_id = cooldown_id or child._lstweeks_cooldown_id

            local spell_id = child._lstweeks_spell_id
            local name = child._lstweeks_cd_name
            local icon = child._lstweeks_cd_icon
            if spell_id and (not name or not icon) then
                local spell_name, spell_icon = get_spell_display(spell_id)
                name = name or spell_name
                icon = icon or spell_icon
                child._lstweeks_cd_name = name
                child._lstweeks_cd_icon = icon
            end

            local cached = cooldown_id and cache[cooldown_id]
            if cached then
                name = name or cached.name
                icon = icon or cached.icon
                spell_id = spell_id or cached.spell_id
            end

            if (not iid) and cooldown_id and icon then
                local expiration = cached and cached.expiration or 0
                local duration = cached and cached.duration or 0
                local remaining = (expiration and expiration > now) and (expiration - now) or 0
                local duration_object = (cached and cached.duration_object) or get_spell_cooldown_duration_object(spell_id)
                local key = "cd_" .. tostring(cooldown_id)
                target_map[key] = {
                    instance_id       = key,
                    is_spell_cooldown = true,
                    spell_id          = spell_id,
                    name              = name or tostring(spell_id or cooldown_id),
                    icon              = icon,
                    duration          = duration,
                    duration_object   = duration_object,
                    remaining         = remaining,
                    expiration        = expiration,
                    count             = 0,
                    live_count        = nil,
                    is_helpful        = true,
                    category          = category,
                    filter            = "HELPFUL",
                    order_key         = "cd|" .. tostring(cooldown_id),
                }
            end
        end
    else
        for _, child in ipairs({viewer:GetChildren()}) do
            local iid = child.auraInstanceID
            if iid then
                local entry = M._aura_map[iid]
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
    local lookup = {}
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

-- ============================================================================
-- HELPFUL AURA CLASSIFICATION
-- Returns "static" | "short" | "long" for a helpful aura given its remaining time.
-- Returns nil when classification is deferred to caller (secret fields).
local function classify_helpful(classify_rem, short_threshold)
    if classify_rem == nil then return nil end
    if classify_rem == 0 then return "static" end
    if classify_rem <= short_threshold then return "short" end
    return "long"
end

-- ============================================================================
-- UNIFIED SCAN
-- Scans all player buffs and debuffs in one pass.
-- Populates M._aura_map: iid -> entry with is_helpful and category fields.
-- Preset frames filter by entry.category; custom frames filter by whitelist.
function M.unified_scan(info, short_threshold, max_helpful_hint, max_debuff_hint)
    M._aura_map = M._aura_map or {}
    local cur_map = M._aura_map

    -- Snapshot old map for stable added_at and secret-field fallback.
    -- We build a shallow copy of keys only (old entries are referenced, not cloned).
    local old_map = _scratch_old_map
    wipe(old_map)
    for iid, entry in pairs(cur_map) do old_map[iid] = entry end
    for _, entry in pairs(cur_map) do
        entry.is_important = nil
    end

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
    local max_helpful = math_max(
        max_helpful_hint or 0,
            math_max(db.max_icons_static or 40,
                math_max(db.max_icons_short or 40,
                    math_max(db.max_icons_long or 40,
                    math_max(db.max_icons_essential or 40,
                        math_max(db.max_icons_utility or 40,
                            math_max(db.max_icons_tracked_buffs or 40, db.max_icons_tracked_bars or 40))))))
    )

    -- Track old category by spell for cross-session refresh hinting.
    -- Built lazily from old_map each scan — no persistent table needed.
    local old_cat_by_spell = _scratch_old_cat
    wipe(old_cat_by_spell)
    for _, entry in pairs(old_map) do
        if entry.is_helpful and entry.spell_id and entry.category then
            old_cat_by_spell[entry.spell_id] = entry.category
        end
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
        local live_duration = nil
        if need_live then
            local ok_live, result = pcall(C_UnitAuras.GetAuraDuration, "player", iid)
            if ok_live then live_duration = result end
        end
        local live_expiration = nil
        local live_remaining  = nil
        if live_duration then
            if live_duration.GetExpirationTime then
                local e = live_duration:GetExpirationTime()
                if e ~= nil and not issecretvalue(e) then live_expiration = e end
            end
            local r = live_duration:GetRemainingDuration()
            if r ~= nil and not issecretvalue(r) then live_remaining = r end
        end

        local classify_rem = live_remaining or rem

        -- Self-heal stale static-learning when we now see a readable duration > 0.
        if safe_spell_id and M._known_static[safe_spell_id]
                and classify_rem ~= nil and not issecretvalue(classify_rem)
                and classify_rem > 0 then
            M._known_static[safe_spell_id] = nil
        end

        local category     = nil
        local static_confirmed = false

        if safe_spell_id and M._known_static[safe_spell_id] then
            category = "static"
            static_confirmed = true
        elseif safe_spell_id and M._known_long[safe_spell_id] and classify_rem == nil then
            -- Brand-new long buff in combat: all time fields secret but we learned it OOC.
            category = "long"
        elseif classify_rem ~= nil then
            category = classify_helpful(classify_rem, short_threshold)
            if category == "static" then static_confirmed = true end
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
                static_confirmed = true
            elseif expires_known == true then
                local old_cat = (old_entry and old_entry.category)
                    or (safe_spell_id and old_cat_by_spell[safe_spell_id])
                category = old_cat or "short"
            else
                local old_cat = (old_entry and old_entry.category)
                    or (safe_spell_id and old_cat_by_spell[safe_spell_id])
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

            local applications = aura.applications
            local stacks = (not issecretvalue(applications) and applications and applications > 1) and applications or 0
            local live_count = (stacks == 0) and C_UnitAuras.GetAuraApplicationDisplayCount("player", iid) or nil

            local safe_duration = (not issecretvalue(duration)) and duration
                or (old_entry and old_entry.duration) or 0
            local safe_expiration = (not issecretvalue(expiration)) and expiration
                or live_expiration
                or (live_remaining and live_remaining > 0 and (GetTime() + live_remaining))
                or (old_entry and old_entry.expiration) or 0
            local safe_remaining = rem
            if live_remaining and live_remaining > 0 then
                safe_remaining = live_remaining
            elseif (not safe_remaining or safe_remaining <= 0) and safe_expiration and safe_expiration > 0 then
                safe_remaining = math_max(0, safe_expiration - GetTime())
            elseif (not safe_remaining or safe_remaining <= 0) and old_entry and old_entry.remaining then
                safe_remaining = old_entry.remaining
            end

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
                entry.live_remaining = live_remaining
                entry.live_count     = live_count
                cur_map[iid] = entry
            end
            learn_aura_identity(safe_spell_id, name, icon, "HELPFUL")
            seen_iids[iid] = true

            -- Session-scoped learning.
            if category == "static" and safe_spell_id and static_confirmed then
                M._known_static[safe_spell_id] = true
            end
            if category == "long" and safe_spell_id and classify_rem ~= nil then
                M._known_long[safe_spell_id] = true
            end

            count = count + 1
        end
    end

    -- -------------------------------------------------------------------------
    -- PASS 1B: HELPFUL IMPORTANT
    -- -------------------------------------------------------------------------
    if C_UnitAuras.GetAuraDataByIndex then
        local max_important = db.max_icons_important or 40
        i, count = 1, 0
        while count < max_important do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL|IMPORTANT")
            if not ok or not aura then break end
            i = i + 1

            local iid = aura.auraInstanceID
            if not iid then break end

            local old_entry     = old_map[iid]
            local current_entry = cur_map[iid]
            local safe_spell_id = get_aura_spell_id(aura, current_entry or old_entry)
            local name          = aura.name
            local icon          = aura.icon
            local duration      = aura.duration
            local expiration    = aura.expirationTime
            local rem           = compute_remaining(duration, expiration)
            local category      = classify_helpful(rem, short_threshold) or (old_entry and old_entry.category) or "short"
            local applications  = aura.applications
            local stacks = (not issecretvalue(applications) and applications and applications > 1) and applications or 0

            local safe_duration = (not issecretvalue(duration)) and duration
                or (old_entry and old_entry.duration) or 0
            local safe_expiration = (not issecretvalue(expiration)) and expiration
                or (old_entry and old_entry.expiration) or 0
            local safe_remaining = rem
            if (not safe_remaining or safe_remaining <= 0) and safe_expiration and safe_expiration > 0 then
                safe_remaining = math_max(0, safe_expiration - GetTime())
            elseif (not safe_remaining or safe_remaining <= 0) and old_entry and old_entry.remaining then
                safe_remaining = old_entry.remaining
            end

            local entry = cur_map[iid]
            if entry then
                if not seen_iids[iid] then
                    update_entry(entry, name, icon, safe_duration, safe_expiration,
                        safe_spell_id, nil, safe_remaining or 0, stacks, nil, nil, category)
                    entry.is_helpful = true
                end
                entry.is_important = true
                if not entry.category then entry.category = category end
            else
                entry = make_entry(iid, name, icon, safe_duration, safe_expiration,
                    safe_spell_id, nil, safe_remaining or 0, stacks,
                    true, category, (old_entry and old_entry.added_at) or GetTime())
                entry.is_important = true
                cur_map[iid] = entry
            end
            seen_iids[iid] = true
            local learn_spell_id = (entry and entry.spell_id) or safe_spell_id
            learn_aura_identity(learn_spell_id, name, icon, "HELPFUL")
            learn_important_aura(learn_spell_id, name, icon)
            count = count + 1
        end
    end

    -- -------------------------------------------------------------------------
    -- PASS 2: HARMFUL (debuffs)
    -- -------------------------------------------------------------------------
    local max_debuff = math_max(max_debuff_hint or 0, db.max_icons_debuff or 40)

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
        local applications  = aura.applications
        local stacks = (not issecretvalue(applications) and applications and applications > 1) and applications or 0

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

            local added_data  = added_lookup and added_lookup[iid]
            local safe_spell_id = get_safe_spell_id(aura.spellId, old_entry)
            local hinted_duration, hinted_expiration, hinted_spell_id
            if type(added_data) == "table" then
                hinted_duration = added_data.duration
                if issecretvalue(hinted_duration) then hinted_duration = nil end
                hinted_expiration = added_data.expirationTime
                if issecretvalue(hinted_expiration) then hinted_expiration = nil end
                hinted_spell_id = get_safe_spell_id(added_data.spellId, nil)
            end
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
            -- Readable duration: debuffs with a dispel type also belong.
            belongs = true
            if not belongs and not issecretvalue(dispel) and dispel and dispel ~= "" then
                belongs = true
            end
        end

        if belongs then
            local safe_spell_id = get_safe_spell_id(aura.spellId, old_entry)
            local safe_duration = (not issecretvalue(duration)) and duration
                or (old_entry and old_entry.duration) or 0
            local safe_expiration = (not issecretvalue(expiration)) and expiration
                or (old_entry and old_entry.expiration) or 0
            local safe_remaining = rem
            if (not safe_remaining or safe_remaining <= 0) and safe_expiration and safe_expiration > 0 then
                safe_remaining = math_max(0, safe_expiration - GetTime())
            elseif (not safe_remaining or safe_remaining <= 0) and old_entry and old_entry.remaining then
                safe_remaining = old_entry.remaining
            end
            local live_count = (stacks == 0) and C_UnitAuras.GetAuraApplicationDisplayCount("player", iid) or nil

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
            learn_aura_identity(safe_spell_id, name, icon, "HARMFUL")
            seen_iids[iid] = true
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
