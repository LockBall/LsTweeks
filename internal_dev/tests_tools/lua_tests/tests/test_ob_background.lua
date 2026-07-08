-- Behavioral tests for Objectives background opacity restore paths.
-- Runs under desktop Lua 5.1 against the wow_stub environment, outside the WoW LuaLS profile.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/objectives")

local M = h.addon.objectives

local function fresh_db(overrides)
    local db = {
        customize_background = false,
        background_color_enabled = false,
        background_alpha = 0.5,
        background_color = { r = 0.25, g = 0.25, b = 0.25, a = 0.75 },
    }
    for k, v in pairs(overrides or {}) do db[k] = v end
    Ls_Tweeks_DB = { objectives = db, modules = { objectives = true } }
    return db
end

local function reset_runtime()
    h.stub.in_combat = false
    ObjectiveTrackerFrame.NineSlice.__calls = {}
    ObjectiveTrackerManager.__calls = {}
    ObjectiveTrackerManager.__opacity = 100
    ObjectiveTrackerFrame.HasSetting = nil
    EditModeManagerFrame = nil
    Enum = nil
end

local function edit_mode_calls()
    return EditModeManagerFrame and EditModeManagerFrame.calls or {}
end

h.test("module disable restores objective opacity through Edit Mode", function()
    reset_runtime()
    fresh_db({ customize_background = false })

    Enum = { EditModeObjectiveTrackerSetting = { Opacity = 99 } }
    ObjectiveTrackerFrame.HasSetting = function(_, setting) return setting == 99 end
    EditModeManagerFrame = {
        calls = {},
        OnSystemSettingChange = function(self, tracker, setting, percent)
            self.calls[#self.calls + 1] = { tracker = tracker, setting = setting, percent = percent }
        end,
    }

    M.apply_background()
    h.eq(ObjectiveTrackerManager:GetOpacity(), 0, "disabled WoW BG applies hidden live opacity")
    h.eq(edit_mode_calls()[1].percent, 0, "disabled WoW BG writes hidden Edit Mode opacity")

    h.addon.set_module_enabled("objectives", false)

    h.eq(ObjectiveTrackerManager:GetOpacity(), 100, "module disable restores full live opacity")
    h.eq(edit_mode_calls()[2].percent, 100, "module disable restores full Edit Mode opacity")
end)

h.run("ob_background")

--#endregion FILE CONTENTS ===================================================
