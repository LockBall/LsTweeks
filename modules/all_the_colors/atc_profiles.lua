-- Generic registered-consumer profile schema for Shared Colors.


local _, addon = ...

addon.all_the_colors = addon.all_the_colors or {}
local M = addon.all_the_colors


--#region PROFILE SCHEMA =======================================================

local PROFILE_KEYS = {
    "global_enabled",
    "global_enable_all_backgrounds",
    "global_enable_test_auras",
    "global_disable_ooc_fade",
    "global_color",
}
for _, color_def in ipairs(M.AURA_COLOR_DEFS) do
    PROFILE_KEYS[#PROFILE_KEYS + 1] = color_def.key
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do
        out[key] = copy(child)
    end
    return out
end

function M.export_profile_data()
    local data = {}
    local db = M.get_db()
    if not db then return data end
    for _, key in ipairs(PROFILE_KEYS) do
        data[key] = copy(db[key])
    end
    data.consumers = {}
    for _, consumer in ipairs(M.get_registered_consumers()) do
        local consumer_db = M.ensure_consumer_db(consumer.key)
        data.consumers[consumer.key] = {
            global_enabled = consumer_db and consumer_db.global_enabled == true,
            global_groups = consumer_db and copy(consumer_db.global_groups) or nil,
        }
    end
    return data
end

function M.apply_profile_data(data)
    if type(data) ~= "table" then
        return false, "Profile data is missing."
    end

    local db = M.get_db()
    local defaults = M.defaults.all_the_colors
    for _, key in ipairs(PROFILE_KEYS) do
        if data[key] ~= nil then
            db[key] = copy(data[key])
        else
            db[key] = copy(defaults[key])
        end
    end
    db.consumers = {}
    for _, consumer in ipairs(M.get_registered_consumers()) do
        local saved = type(data.consumers) == "table" and data.consumers[consumer.key]
        local global_enabled = consumer.default_global_enabled == true
        if type(saved) == "table" and saved.global_enabled ~= nil then
            global_enabled = saved.global_enabled == true
        end
        db.consumers[consumer.key] = {
            global_enabled = global_enabled,
            global_groups = type(saved) == "table" and copy(saved.global_groups) or nil,
        }
    end
    M.normalize_db()
    if M.on_reset_complete then
        M.on_reset_complete()
    else
        M.refresh_consumers()
    end
    return true, "Loaded profile."
end

M.profile_manager = addon.CreateProfileManager({
    label = "All the Colors",
    get_db = M.get_db,
    export_data = M.export_profile_data,
    apply_data = M.apply_profile_data,
})

--#endregion PROFILE SCHEMA ====================================================
