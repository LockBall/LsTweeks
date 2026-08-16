-- Aura Frames native visibility tests: reversible Aura-frame parent suppression and CDM alpha hiding.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

h.load_addon("modules/aura_frames")

local M = h.addon.aura_frames

local function install_live_cooldown_viewer_enums()
    Enum = {
        CooldownViewerVisibleSetting = { Always = 0, InCombat = 1, Hidden = 2 },
        EditModeCooldownViewerSetting = { VisibleSetting = 6 },
    }
end

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

h.test("public CDM transport does not drive Blizzard Edit Mode visibility", function()
    install_live_cooldown_viewer_enums()
    local viewer = create_viewer("EssentialCooldownViewer", Enum.CooldownViewerVisibleSetting.Hidden)
    M.db = { hide_blizz_cdm_essential = false }

    M.update_blizz_cdm_visibility("essential")
    h.eq(viewer.visibleSetting, Enum.CooldownViewerVisibleSetting.Hidden,
        "addon leaves Blizzard visibility unchanged")
    h.is_nil(viewer.__setting, "addon never invokes the Edit Mode setting method")
end)

h.test("CDM alpha hide is independent and restores without viewer scripts", function()
    local viewer = create_viewer("UtilityCooldownViewer", 2)
    M.db = { hide_blizz_cdm_utility = true }

    M.update_blizz_cdm_visibility("utility")
    h.eq(viewer:GetAlpha(), 0, "hide preference suppresses the native viewer visually")
    h.eq(viewer:IsMouseEnabled(), false, "hidden native viewer does not intercept the mouse")
    h.eq(#(viewer:GetCalls("HookScript") or {}), 0, "addon installs no viewer script hooks")

    M.restore_blizz_cdm_viewer_settings()
    h.eq(viewer:GetAlpha(), 1, "module disable restores native viewer alpha")
    h.eq(viewer:IsMouseEnabled(), true, "module disable restores native viewer mouse state")
end)

h.run("af_native_visibility")

--#endregion FILE CONTENTS ===================================================
