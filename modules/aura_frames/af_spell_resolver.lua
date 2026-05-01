-- Spell resolver utilities for aura_frames: resolve spell name/icon by spell ID.
-- M.ResolveSpellID(sid, on_success) resolves immediately if data is loaded, otherwise
-- requests load and polls. M.TryGetSpellInfo(sid) is a synchronous-only attempt.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local issecretvalue = issecretvalue
local C_Spell       = C_Spell

function M.TryGetSpellInfo(sid)
    if not sid or sid == 0 then return nil end
    local info = C_Spell.GetSpellInfo(sid)
    if info and info.name and not issecretvalue(info.name) then return info.name, info.iconID end
    return nil
end

function M.ResolveSpellID(sid, on_success)
    if not sid or sid == 0 then return end
    local name, icon = M.TryGetSpellInfo(sid)
    if name then
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
                        local need_name = (not stored_name) or tostring(stored_name):match("^Spell %d+$")
                        local need_icon = not (entry.whitelist_icons and entry.whitelist_icons[sid])
                        if need_name or need_icon then
                            M.ResolveSpellID(sid, function(name, icon)
                                if name then entry.whitelist[sid] = name end
                                if icon then
                                    entry.whitelist_icons = entry.whitelist_icons or {}
                                    entry.whitelist_icons[sid] = icon
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
