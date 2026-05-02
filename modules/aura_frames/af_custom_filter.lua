-- Custom whitelist aura-frame filtering.
-- Owns spell-ID whitelist lookups, aura registry fallback, and per-frame
-- auraInstanceID -> spellID memory for combat-restricted aura fields.
local addon_name, addon = ...

local C_UnitAuras   = C_UnitAuras
local issecretvalue = issecretvalue
local tonumber      = tonumber
local tostring      = tostring

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local FULL_AURA_SCAN_LIMIT = 255

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

    local whitelist_by_id, whitelist_by_name = build_whitelist_lookups(custom_entry.whitelist)
    local want_helpful = (custom_entry.filter == "HELPFUL")
    local spell_cache = M.db and M.db.spell_name_cache or {}
    frame._custom_iid_to_sid = frame._custom_iid_to_sid or {}
    local iid_to_sid = frame._custom_iid_to_sid

    local seen_iids = {}
    local matched_sids = {}
    for iid, entry in pairs(shared_map) do
        if entry.is_helpful == want_helpful then
            local sid = normalize_spell_id(entry.spell_id)
            if not sid and entry.name and not issecretvalue(entry.name) then
                sid = whitelist_by_name[entry.name]
            end
            if not sid and entry.name and not issecretvalue(entry.name) then
                for csid, cdata in pairs(spell_cache) do
                    if cdata.name == entry.name then sid = normalize_spell_id(csid); break end
                end
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
            end
        end
    end

    for iid in pairs(iid_to_sid) do
        if not seen_iids[iid] then
            iid_to_sid[iid] = nil
        end
    end
end
