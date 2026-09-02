-- Managed CDM Test Aura placement regression tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("CDM Aura mode positions its Test Aura opposite native growth", function()
    Enum.CooldownViewerCategory = {
        Essential = 0,
        Utility = 1,
        TrackedBuff = 2,
        TrackedBar = 3,
    }
    C_CooldownViewer = {
        GetCooldownViewerCategorySet = function() return {} end,
        GetCooldownViewerCooldownInfo = function() return nil end,
    }
    local M = fixture.boot_managed_presets()
    local frame = M.frames and M.frames.show_tracked_buffs
    h.ok(frame and frame._managed_cdm_backend, "Tracked Buffs owns a managed CDM backend")

    M.db.show_tracked_buffs = true
    M.db.cooldown_mode_tracked_buffs = false
    M.db.bar_mode_tracked_buffs = false
    M.db.growth_icon_tracked_buffs = "RIGHT"
    M.db.bg_tracked_buffs = true
    M.invalidate_frame_runtime_config(frame)
    h.ok(M.set_test_aura_enabled("tracked_buffs", true), "Tracked Buffs Test Aura can be enabled")

    local anchor = frame._managed_test_preview_background_anchor
    h.ok(anchor, "CDM Aura mode owns a separate Test Aura cell")
    local point, relative_to, relative_point = anchor:GetPoint(1)
    h.eq(point, "TOPRIGHT", "Right-growing native content puts the Test Aura to its left")
    h.eq(relative_to, frame, "CDM Test Aura cell remains attached to the addon shell")
    h.eq(relative_point, "TOPLEFT", "CDM Test Aura cell sits opposite native growth")
    local _, icon_relative_to = frame.icons[1]:GetPoint(1)
    h.eq(icon_relative_to, anchor, "CDM Test Aura icon uses the separate preview cell")
    h.ok(frame._managed_test_preview_background.texture:IsShown(),
        "CDM Test Aura uses its separate Frame BG cell")

    M.db.show_tracked_buffs = false
    M.refresh_test_aura_category("tracked_buffs")
    h.ok(not frame._managed_test_preview_background.texture:IsShown(),
        "disabling the CDM frame hides its Test Aura Frame BG cell")
    M.set_test_aura_enabled("tracked_buffs", false)
end)

h.run("af_managed_cdm_preview")

--#endregion FILE CONTENTS ===================================================
