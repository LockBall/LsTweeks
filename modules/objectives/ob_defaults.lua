-- Default DB values for the Objectives module.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

local M = addon.objectives or {}
addon.objectives = M

M.MODULE_KEY = "objectives"

function M.get_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.objectives = Ls_Tweeks_DB.objectives or {}
    return Ls_Tweeks_DB.objectives
end

function M.is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(M.MODULE_KEY)
end

M.defaults = {
    objectives = {
        collapse_all = false,
        collapse_campaign = false,
        collapse_quests = false,
        collapse_achievements = false,
        show_quest_log_count = false,
        show_quest_log_count_on_hover = false,
        show_tracked_achievement_count = false,
        show_tracked_achievement_count_on_hover = false,
    },
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.ob = M.defaults

return M

--#endregion FILE CONTENTS ===================================================
