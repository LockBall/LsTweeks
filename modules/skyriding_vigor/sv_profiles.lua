-- Skyriding Vigor profile schema.
local _, addon = ...
local M = addon.skyriding_vigor

--#region PROFILES =============================================================

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do
        out[key] = copy(child)
    end
    return out
end

function M.export_skyriding_vigor_profile_data()
    local db = M.get_root_db()
    local data = copy(db)
    data.profiles, data.last_profile_name, data.last_tab_index = nil, nil, nil
    return data
end

function M.apply_skyriding_vigor_profile_data(data)
    if not data then return false, "Profile data is missing." end
    local db = M.get_root_db()
    local profiles, name, tab = db.profiles, db.last_profile_name, db.last_tab_index
    for key in pairs(db) do
        db[key] = nil
    end
    for key, value in pairs(data) do
        db[key] = copy(value)
    end
    db.profiles, db.last_profile_name, db.last_tab_index = profiles, name, tab
    M.on_reset_complete()
    return true, "Loaded profile."
end

M.profile_manager = addon.CreateProfileManager({
    label = "Skyriding Vigor",
    get_db = function()
        return M.get_root_db and M.get_root_db()
    end,
    export_data = M.export_skyriding_vigor_profile_data,
    apply_data = M.apply_skyriding_vigor_profile_data,
})

--#endregion PROFILES ==========================================================
