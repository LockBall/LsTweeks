-- Custom whitelist aura-frame filtering.
-- Owns spell-ID whitelist lookups, aura registry fallback, and per-frame
-- auraInstanceID -> spellID memory for combat-restricted aura fields.
local addon_name, addon = ...

local C_UnitAuras   = C_UnitAuras
local C_CooldownViewer = C_CooldownViewer
local issecretvalue = issecretvalue
local tonumber      = tonumber
local tostring      = tostring
local GetTime       = GetTime

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local FULL_AURA_SCAN_LIMIT = 255
local _debug_last = {}
M._custom_debug_lines = M._custom_debug_lines or {}
M._custom_debug_baseline_done = M._custom_debug_baseline_done or false

local function value_state(value)
    if value == nil then return "nil" end
    if issecretvalue(value) then return "secret" end
    return "value"
end

local function safe_value(value)
    if value == nil then return "nil" end
    if issecretvalue(value) then return "secret" end
    return tostring(value)
end

local function debug_custom_match(frame, sid, message)
    if not (M.db and M.db.debug_custom_aura) then return end
    local key = (frame and frame.category or "?") .. ":" .. tostring(sid) .. ":" .. message
    local now = GetTime()
    if _debug_last[key] and (now - _debug_last[key]) < 2 then return end
    _debug_last[key] = now
    local line = string.format("%.1f %s", now, message)
    local lines = M._custom_debug_lines
    lines[#lines + 1] = line
    if #lines > 80 then
        table.remove(lines, 1)
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffLsT custom|r " .. message)
    end
end

function M.clear_custom_debug_log()
    wipe(M._custom_debug_lines)
    wipe(_debug_last)
    M._custom_debug_baseline_done = false
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffLsT custom|r debug log cleared")
    end
end

function M.print_custom_debug_log()
    if not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffLsT custom|r debug log:")
    for _, line in ipairs(M._custom_debug_lines or {}) do
        DEFAULT_CHAT_FRAME:AddMessage(line)
    end
end

local function cdm_category(name, fallback)
    local enum = Enum and Enum.CooldownViewerCategory
    return (enum and enum[name]) or fallback
end

local function probe_cooldown_viewer(frame, sid)
    if not (M.db and M.db.debug_custom_aura) then return end
    local api_ok = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
        and C_CooldownViewer.GetCooldownViewerCooldownInfo
    local icon_viewer = _G["BuffIconCooldownViewer"]
    local bar_viewer = _G["BuffBarCooldownViewer"]
    debug_custom_match(frame, sid,
        "cdv api=" .. (api_ok and "yes" or "no")
        .. " iconViewer=" .. (icon_viewer and "yes" or "no")
        .. " barViewer=" .. (bar_viewer and "yes" or "no"))

    if api_ok then
        local categories = {
            cdm_category("TrackedBuff", 2),
            cdm_category("TrackedBar", 3),
        }
        for _, category in ipairs(categories) do
            local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
            local count = (ok and ids) and #ids or 0
            local found = "no"
            if ok and ids then
                for _, cooldown_id in ipairs(ids) do
                    local info_ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldown_id)
                    if info and info.spellID == sid then
                        found = "cd=" .. tostring(cooldown_id)
                            .. " hasAura=" .. safe_value(info.hasAura)
                            .. " name=" .. safe_value(info.name)
                            .. " icon=" .. safe_value(info.icon)
                        break
                    end
                end
            end
            debug_custom_match(frame, sid,
                "cdv cat=" .. tostring(category)
                .. " count=" .. tostring(count)
                .. " sid=" .. tostring(sid)
                .. " found=" .. found)
        end
    end

    local function probe_viewer(viewer, label)
        if not viewer then return end
        local children = { viewer:GetChildren() }
        debug_custom_match(frame, sid, "cdv " .. label .. " children=" .. tostring(#children))
        for idx = 1, math.min(#children, 5) do
            local child = children[idx]
            local cooldown_id = child.cooldownID or child.cooldownId or child.id
                or (child.GetCooldownID and child:GetCooldownID())
            local spell_id = child.spellID or child.spellId
            debug_custom_match(frame, sid,
                "cdv " .. label .. idx
                .. " shown=" .. safe_value(child:IsShown())
                .. " cd=" .. safe_value(cooldown_id)
                .. " spell=" .. safe_value(spell_id)
                .. " name=" .. safe_value(child:GetName()))
        end
    end
    probe_viewer(icon_viewer, "icon")
    probe_viewer(bar_viewer, "bar")
end

local function probe_cooldown_viewer_baseline(frame)
    if not (M.db and M.db.debug_custom_aura) then return end
    if M._custom_debug_baseline_done then return end
    M._custom_debug_baseline_done = true

    debug_custom_match(frame, "baseline", "baseline begin")
    probe_cooldown_viewer(frame, -1)
    debug_custom_match(frame, "baseline", "baseline end")
end

local function normalize_spell_id(sid)
    if sid == nil or issecretvalue(sid) then return nil end
    return tonumber(sid) or sid
end

local function build_whitelist_lookups(whitelist)
    local by_id = {}
    local by_name = {}
    for raw_sid, wname in pairs(whitelist or {}) do
        local sid = normalize_spell_id(raw_sid)
        if sid then by_id[sid] = wname or true end
        if wname then by_name[wname] = sid end
    end
    return by_id, by_name
end

local function find_whitelist_sid_by_registry(entry, whitelist_by_id, registry)
    if not (entry and registry) then return nil end
    local entry_name = entry.name
    local entry_icon = entry.icon
    local has_name = entry_name ~= nil and not issecretvalue(entry_name)
    local has_icon = entry_icon ~= nil and not issecretvalue(entry_icon)
    if not has_name and not has_icon then return nil end

    local matched_sid
    for sid in pairs(whitelist_by_id) do
        local cached = registry[sid] or registry[tostring(sid)]
        if cached then
            local name_match = has_name and cached.name and cached.name == entry_name
            local icon_match = has_icon and cached.iconID and cached.iconID == entry_icon
            if name_match or icon_match then
                if matched_sid and matched_sid ~= sid then
                    return nil
                end
                matched_sid = sid
            end
        end
    end
    return matched_sid
end

local function has_whitelist_entries(whitelist)
    for sid in pairs(whitelist or {}) do
        if normalize_spell_id(sid) then return true end
    end
    return false
end

local function cache_aura_identity(sid, entry)
    if sid and M.CacheAuraInfo and entry then
        M.CacheAuraInfo(sid, entry.name, entry.icon, entry.filter)
    end
end

local function patch_entry_from_registry(entry, sid, registry)
    local cached = registry and sid and (registry[sid] or registry[tostring(sid)])
    if not cached then return entry end
    local needs_name = entry.name == nil or issecretvalue(entry.name)
    local needs_icon = entry.icon == nil or issecretvalue(entry.icon)
    if not ((needs_name and cached.name) or (needs_icon and cached.iconID)) then
        return entry
    end

    local patched = {}
    for k, v in pairs(entry) do patched[k] = v end
    if needs_name and cached.name then patched.name = cached.name end
    if needs_icon and cached.iconID then patched.icon = cached.iconID end
    patched.spell_id = sid
    return patched
end

local function lookup_player_aura_iid_by_spell(sid, want_helpful)
    if not sid then return nil end
    local aura
    if C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, result = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
        if ok then aura = result end
    end
    if not aura and C_UnitAuras.GetUnitAuraBySpellID then
        local ok, result = pcall(C_UnitAuras.GetUnitAuraBySpellID, "player", sid)
        if ok then aura = result end
    end
    if not aura then return nil end

    local is_helpful = aura.isHelpful
    if type(is_helpful) == "boolean" and not issecretvalue(is_helpful) and is_helpful ~= want_helpful then
        return nil
    end

    local iid = aura.auraInstanceID
    if iid and not issecretvalue(iid) then
        return iid, aura
    end
    return nil
end

function M.get_custom_scan_limits(db)
    local helpful, harmful = 0, 0
    local capture_runtime = M._custom_capture_runtime or {}
    for _, entry in ipairs((db and db.custom_frames) or {}) do
        local runtime = entry.id and capture_runtime[entry.id]
        local needs_full_scan = (runtime and runtime.capture_active)
            or (has_whitelist_entries(entry.whitelist) and (entry.show or entry.move))
        if needs_full_scan and entry.filter == "HARMFUL" then
            harmful = FULL_AURA_SCAN_LIMIT
        elseif needs_full_scan then
            helpful = FULL_AURA_SCAN_LIMIT
        end
    end
    return helpful, harmful
end

function M.filter_custom_aura_map(frame, custom_entry, shared_map)
    if not (frame and custom_entry and shared_map) then return end
    probe_cooldown_viewer_baseline(frame)

    local whitelist_by_id, whitelist_by_name = build_whitelist_lookups(custom_entry.whitelist)
    local want_helpful = (custom_entry.filter == "HELPFUL")
    local spell_cache = M.db and M.db.spell_name_cache or {}
    frame._custom_iid_to_sid = frame._custom_iid_to_sid or {}
    local iid_to_sid = frame._custom_iid_to_sid

    local seen_iids = {}
    local matched_sids = {}
    local same_filter_count = 0
    local no_sid_count = 0
    local readable_name_count = 0
    local readable_icon_count = 0
    local candidates = {}
    for iid, entry in pairs(shared_map) do
        if entry.is_helpful == want_helpful then
            same_filter_count = same_filter_count + 1
            local sid = normalize_spell_id(entry.spell_id)
            if not sid then no_sid_count = no_sid_count + 1 end
            if entry.name and not issecretvalue(entry.name) then readable_name_count = readable_name_count + 1 end
            if entry.icon and not issecretvalue(entry.icon) then readable_icon_count = readable_icon_count + 1 end
            if not sid and #candidates < 3 then
                candidates[#candidates + 1] = entry
            end
            if not sid and entry.name and not issecretvalue(entry.name) then
                sid = whitelist_by_name[entry.name]
            end
            if not sid then
                sid = find_whitelist_sid_by_registry(entry, whitelist_by_id, spell_cache)
            end
            if sid and whitelist_by_id[sid] then
                iid_to_sid[iid] = sid
                matched_sids[sid] = true
                cache_aura_identity(sid, entry)
                frame._aura_map[iid] = patch_entry_from_registry(entry, sid, spell_cache)
            elseif not sid then
                local remembered_sid = iid_to_sid[iid]
                if remembered_sid and whitelist_by_id[remembered_sid] then
                    matched_sids[remembered_sid] = true
                    frame._aura_map[iid] = patch_entry_from_registry(entry, remembered_sid, spell_cache)
                    seen_iids[iid] = true
                end
            end
            seen_iids[iid] = frame._aura_map[iid] ~= nil
        end
    end

    -- Brand-new auras applied in combat can have secret scan fields and no
    -- previous iid mapping. A direct lookup by the already-whitelisted spell ID
    -- can still provide the auraInstanceID, which lets us attach the scanned row.
    for sid in pairs(whitelist_by_id) do
        if not matched_sids[sid] then
            local iid, aura = lookup_player_aura_iid_by_spell(sid, want_helpful)
            local entry = iid and shared_map[iid]
            if entry and entry.is_helpful == want_helpful then
                iid_to_sid[iid] = sid
                matched_sids[sid] = true
                if aura and M.CacheAuraInfo then
                    M.CacheAuraInfo(sid, aura.name, aura.icon, entry.filter)
                end
                frame._aura_map[iid] = patch_entry_from_registry(entry, sid, spell_cache)
                seen_iids[iid] = true
            else
                local cached = spell_cache and (spell_cache[sid] or spell_cache[tostring(sid)])
                probe_cooldown_viewer(frame, sid)
                debug_custom_match(frame, sid,
                    "miss sid=" .. tostring(sid)
                    .. " cache=" .. (cached and "yes" or "no")
                    .. " lookup_iid=" .. tostring(iid)
                    .. " lookup_aura=" .. (aura and "yes" or "no")
                    .. " map_entry=" .. (entry and "yes" or "no")
                    .. " map_sid=" .. value_state(entry and entry.spell_id)
                    .. " map_name=" .. value_state(entry and entry.name)
                    .. " map_icon=" .. value_state(entry and entry.icon))
                debug_custom_match(frame, sid,
                    "scan sid=" .. tostring(sid)
                    .. " total=" .. tostring(same_filter_count)
                    .. " no_sid=" .. tostring(no_sid_count)
                    .. " readable_name=" .. tostring(readable_name_count)
                    .. " readable_icon=" .. tostring(readable_icon_count))
                for idx, candidate in ipairs(candidates) do
                    debug_custom_match(frame, sid,
                        "cand" .. tostring(idx)
                        .. " iid=" .. safe_value(candidate.instance_id)
                        .. " cat=" .. safe_value(candidate.category)
                        .. " sid=" .. value_state(candidate.spell_id)
                        .. " name=" .. value_state(candidate.name)
                        .. " icon=" .. value_state(candidate.icon)
                        .. " iconv=" .. safe_value(candidate.icon))
                end
            end
        end
    end

    for iid in pairs(iid_to_sid) do
        if not seen_iids[iid] then
            iid_to_sid[iid] = nil
        end
    end
end
