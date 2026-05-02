-- Spell resolver utilities for aura_frames: resolve spell name/icon by spell ID.
-- M.ResolveSpellID(sid, on_success) resolves immediately if data is loaded, otherwise
-- requests load and polls. M.TryGetSpellInfo(sid) is a synchronous-only attempt.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local issecretvalue = issecretvalue
local C_Spell       = C_Spell
local tonumber      = tonumber

local function normalize_spell_id(sid)
    if sid == nil or issecretvalue(sid) then return nil end
    return tonumber(sid) or sid
end

function M.CacheAuraInfo(sid, name, icon, filter)
    sid = normalize_spell_id(sid)
    if not (M.db and sid) then return end
    M.db.spell_name_cache = M.db.spell_name_cache or {}
    local cached = M.db.spell_name_cache[sid] or {}
    if name and not issecretvalue(name) then cached.name = name end
    if icon and not issecretvalue(icon) then cached.iconID = icon end
    if filter then cached.filter = filter end
    M.db.spell_name_cache[sid] = cached
end

function M.TryGetSpellInfo(sid)
    sid = tonumber(sid) or sid
    if not sid or sid == 0 then return nil end
    local info = C_Spell.GetSpellInfo(sid)
    if info and info.name and not issecretvalue(info.name) then return info.name, info.iconID end
    return nil
end

function M.ResolveSpellID(sid, on_success)
    sid = normalize_spell_id(sid)
    if not sid or sid == 0 then return end
    local name, icon = M.TryGetSpellInfo(sid)
    if name then
        M.CacheAuraInfo(sid, name, icon)
        if on_success then on_success(name, icon) end
        return
    end
    C_Spell.RequestLoadSpellData(sid)
    local attempts = 0
    local done = false
    C_Timer.NewTicker(0.5, function(t)
        if done then t:Cancel(); return end
        attempts = attempts + 1
        local n, ic = M.TryGetSpellInfo(sid)
        if n then
            done = true; t:Cancel()
            M.CacheAuraInfo(sid, n, ic)
            if on_success then on_success(n, ic) end
        elseif attempts >= 20 then
            done = true; t:Cancel()
        end
    end)
end

-- On load, batch-resolve any whitelist entries still showing placeholder names or missing icons.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, aname)
        if aname ~= addon_name then return end
        self:UnregisterEvent("ADDON_LOADED")
        C_Timer.After(0.12, function()
            if not (M.db and M.db.custom_frames) then return end
            for _, entry in ipairs(M.db.custom_frames) do
                if entry.whitelist then
                    local remap = {}
                    for sid, stored_name in pairs(entry.whitelist) do
                        local nsid = normalize_spell_id(sid)
                        if nsid ~= sid then
                            remap[#remap + 1] = { old = sid, new = nsid, name = stored_name }
                        end
                    end
                    for _, item in ipairs(remap) do
                        if entry.whitelist[item.new] == nil then
                            entry.whitelist[item.new] = item.name
                        end
                        entry.whitelist[item.old] = nil
                        if entry.whitelist_icons and entry.whitelist_icons[item.old] and not entry.whitelist_icons[item.new] then
                            entry.whitelist_icons[item.new] = entry.whitelist_icons[item.old]
                            entry.whitelist_icons[item.old] = nil
                        end
                    end
                    for sid, stored_name in pairs(entry.whitelist) do
                        local nsid = normalize_spell_id(sid)
                        if nsid then
                            local icon = entry.whitelist_icons and entry.whitelist_icons[nsid]
                            M.CacheAuraInfo(nsid, stored_name, icon, entry.filter)
                        end
                        local need_name = (not stored_name) or tostring(stored_name):match("^Spell %d+$")
                        local need_icon = nsid and not (entry.whitelist_icons and entry.whitelist_icons[nsid])
                        if nsid and (need_name or need_icon) then
                            M.ResolveSpellID(nsid, function(name, icon)
                                if name then
                                    entry.whitelist[nsid] = name
                                end
                                if icon then
                                    entry.whitelist_icons = entry.whitelist_icons or {}
                                    entry.whitelist_icons[nsid] = icon
                                end
                                M.CacheAuraInfo(nsid, name, icon, entry.filter)
                                local show_key = "show_" .. (entry.id or "")
                                local fr = M.frames and M.frames[show_key]
                                if fr then
                                    M.update_auras(fr, show_key, "move", "timer", "bg", "scale", "spacing",
                                        (entry.filter == "HARMFUL") and "HARMFUL" or "HELPFUL")
                                end
                            end)
                        end
                    end
                end
            end
        end)
    end)
end
