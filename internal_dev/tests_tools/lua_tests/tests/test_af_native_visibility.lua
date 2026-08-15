-- Aura Frames native visibility tests: reversible Aura-frame parent suppression and CDM settings.
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

h.test("Blizzard aura frames use and restore a hidden addon-owned parent", function()
    BuffFrame = CreateFrame("Frame", "BuffFrame", UIParent)
    local container = CreateFrame("Frame", nil, BuffFrame)
    local aura_button = CreateFrame("Button", nil, container)
    aura_button.__native_mouse_enabled = true
    aura_button.IsMouseEnabled = function(self)
        return self.__native_mouse_enabled
    end
    aura_button.EnableMouse = function(self, enabled)
        self.__native_mouse_enabled = enabled == true
    end

    M.set_blizz_buffs_enabled(false)
    h.ok(BuffFrame:GetParent() ~= UIParent,
        "disabled Blizzard BuffFrame moves under an addon-owned parent")
    h.eq(BuffFrame:GetParent():IsShown(), false,
        "the addon-owned parent is hidden")
    h.eq(BuffFrame:IsShown(), true,
        "suppression does not mutate Blizzard frame shown state")
    h.eq(aura_button.__native_mouse_enabled, true,
        "parent suppression does not mutate Blizzard aura-button mouse state")

    M.set_blizz_buffs_enabled(true)
    h.eq(BuffFrame:GetParent(), UIParent,
        "enabling Blizzard buffs restores the original parent")
    h.eq(BuffFrame:IsShown(), true,
        "restoration leaves Blizzard shown state under Blizzard control")
end)

h.test("Blizzard aura frame parent restoration waits for combat to end", function()
    BuffFrame = CreateFrame("Frame", "BuffFrameCombatRestore", UIParent)

    M.set_blizz_buffs_enabled(false)
    h.stub.in_combat = true
    M.set_blizz_buffs_enabled(true)
    h.ok(BuffFrame:GetParent() ~= UIParent,
        "combat keeps the suppressing parent until regen")

    h.stub.in_combat = false
    h.fire_event("PLAYER_REGEN_ENABLED")
    h.eq(BuffFrame:GetParent(), UIParent,
        "regen restores the original parent")
end)

h.test("Blizzard aura frame restoration respects an external parent change", function()
    BuffFrame = CreateFrame("Frame", "BuffFrameExternalChange", UIParent)
    local external_parent = CreateFrame("Frame", nil, UIParent)

    M.set_blizz_buffs_enabled(false)
    BuffFrame:SetParent(external_parent)
    M.set_blizz_buffs_enabled(true)

    h.eq(BuffFrame:GetParent(), external_parent,
        "module does not overwrite a later external parent change")
end)

h.test("General-tab Blizzard visibility changes apply after combat", function()
    M.db = { enable_blizz_buffs = false, enable_blizz_debuffs = true }
    M._module_runtime_enabled = true
    BuffFrame = CreateFrame("Frame", "BuffFrameCombatSetting", UIParent)
    DebuffFrame = CreateFrame("Frame", "DebuffFrameCombatSetting", UIParent)

    h.stub.in_combat = true
    M.set_blizz_buffs_enabled(false)
    h.eq(BuffFrame:GetParent(), UIParent,
        "combat defers the parent change")

    h.stub.in_combat = false
    h.fire_event("PLAYER_REGEN_ENABLED")
    h.ok(BuffFrame:GetParent() ~= UIParent,
        "regen applies the saved General-tab selection")

    M._module_runtime_enabled = false
    M.restore_blizz_aura_frame_settings()
end)

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
