-- Spell resolver utilities for aura_frames: resolve spell name/icon by spell ID.
-- M.ResolveSpellID(sid, on_success) resolves immediately if data is loaded, otherwise
-- requests load and polls. M.TryGetSpellInfo(sid) is a synchronous-only attempt.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local issecretvalue = issecretvalue
local C_Spell       = C_Spell
local tonumber      = tonumber

function M.TryGetSpellInfo(sid)
    sid = tonumber(sid) or sid
    if not sid or sid == 0 then return nil end
    local info = C_Spell.GetSpellInfo(sid)
    if info and info.name and not issecretvalue(info.name) then return info.name, info.iconID end
    return nil
end

local function cache_spell(sid, name, icon)
    sid = tonumber(sid) or sid
    if not (M.db and sid and name) then return end
    M.db.spell_name_cache = M.db.spell_name_cache or {}
    M.db.spell_name_cache[sid] = { name = name, iconID = icon }
end

function M.ResolveSpellID(sid, on_success)
    sid = tonumber(sid) or sid
    if not sid or sid == 0 then return end
    local name, icon = M.TryGetSpellInfo(sid)
    if name then
        cache_spell(sid, name, icon)
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
            cache_spell(sid, n, ic)
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
                    for sid, stored_name in pairs(entry.whitelist) do
                        local nsid = tonumber(sid) or sid
                        if nsid ~= sid then
                            if entry.whitelist[nsid] == nil then
                                entry.whitelist[nsid] = stored_name
                            end
                            entry.whitelist[sid] = nil
                            if entry.whitelist_icons and entry.whitelist_icons[sid] and not entry.whitelist_icons[nsid] then
                                entry.whitelist_icons[nsid] = entry.whitelist_icons[sid]
                                entry.whitelist_icons[sid] = nil
                            end
                        end
                        local need_name = (not stored_name) or tostring(stored_name):match("^Spell %d+$")
                        local need_icon = not (entry.whitelist_icons and (entry.whitelist_icons[nsid] or entry.whitelist_icons[sid]))
                        if need_name or need_icon then
                            M.ResolveSpellID(nsid, function(name, icon)
                                if name then
                                    entry.whitelist[nsid] = name
                                end
                                if icon then
                                    entry.whitelist_icons = entry.whitelist_icons or {}
                                    entry.whitelist_icons[nsid] = icon
                                end
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
