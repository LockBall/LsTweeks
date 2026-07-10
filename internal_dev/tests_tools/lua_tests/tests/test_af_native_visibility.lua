-- Aura Frames native visibility tests: preserves Blizzard CDM visibility settings.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/aura_frames")

local M = h.addon.aura_frames

local function create_viewer(name, visible_setting)
    local viewer = CreateFrame("Frame", name, UIParent)
    viewer.visibleSetting = visible_setting
    viewer.UpdateSystemSettingValue = function(self, setting, value)
        self.__setting = setting
        self.visibleSetting = value
    end
    viewer.UpdateShownState = function(self)
        self.__shown_state_updates = (self.__shown_state_updates or 0) + 1
    end
    return viewer
end

h.test("CDM visibility restores the prior Blizzard setting on module disable", function()
    Enum = {
        CooldownViewerVisibleSetting = { Always = 2, Never = 1 },
        EditModeCooldownViewerSetting = { VisibleSetting = 9 },
    }
    local viewer = create_viewer("EssentialCooldownViewer", Enum.CooldownViewerVisibleSetting.Never)

    M.ensure_blizz_cdm_viewer_always_visible("essential")
    h.eq(viewer.visibleSetting, Enum.CooldownViewerVisibleSetting.Always, "module forces Always while active")

    M.restore_blizz_cdm_viewer_settings()

    h.eq(viewer.visibleSetting, Enum.CooldownViewerVisibleSetting.Never, "module disable restores prior visibility")
    h.eq(viewer.__setting, Enum.EditModeCooldownViewerSetting.VisibleSetting, "restore uses Edit Mode setting")
end)

h.test("CDM visibility restoration waits for combat to end", function()
    Enum = {
        CooldownViewerVisibleSetting = { Always = 2, Never = 1 },
        EditModeCooldownViewerSetting = { VisibleSetting = 9 },
    }
    local viewer = create_viewer("UtilityCooldownViewer", Enum.CooldownViewerVisibleSetting.Never)

    M.ensure_blizz_cdm_viewer_always_visible("utility")
    h.stub.in_combat = true
    M.restore_blizz_cdm_viewer_settings()
    h.eq(viewer.visibleSetting, Enum.CooldownViewerVisibleSetting.Always, "combat keeps required setting until regen")

    h.stub.in_combat = false
    h.fire_event("PLAYER_REGEN_ENABLED")
    h.eq(viewer.visibleSetting, Enum.CooldownViewerVisibleSetting.Never, "regen restores prior visibility")
end)

h.test("CDM visibility restoration respects an external setting change", function()
    Enum = {
        CooldownViewerVisibleSetting = { Always = 2, Never = 1, OnlyInCombat = 3 },
        EditModeCooldownViewerSetting = { VisibleSetting = 9 },
    }
    local viewer = create_viewer("BuffIconCooldownViewer", Enum.CooldownViewerVisibleSetting.OnlyInCombat)

    M.ensure_blizz_cdm_viewer_always_visible("tracked_buffs")
    viewer.visibleSetting = Enum.CooldownViewerVisibleSetting.Never
    M.restore_blizz_cdm_viewer_settings()

    h.eq(viewer.visibleSetting, Enum.CooldownViewerVisibleSetting.Never, "module does not overwrite later external setting")
end)

h.run("af_native_visibility")

--#endregion FILE CONTENTS ===================================================
