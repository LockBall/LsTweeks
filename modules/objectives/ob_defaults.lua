-- Default DB values for the Objectives module.
local addon_name, addon = ...

local M = addon.objectives or {}
addon.objectives = M

M.MODULE_KEY = "objectives"

M.defaults = {
    objectives = {
        collapse_all = false,
        collapse_campaign = false,
        collapse_quests = false,
        collapse_achievements = false,
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.ob = M.defaults

return M
