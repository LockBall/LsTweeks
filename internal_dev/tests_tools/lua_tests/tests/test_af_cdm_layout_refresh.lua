-- Aura Frames CDM layout-save refresh regression tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local h = require("harness")

local saved_layout_data
C_CooldownViewer = {
    SetLayoutData = function(data)
        saved_layout_data = data
    end,
}

h.load_addon()

h.test("WoW CDM layout saves refresh addon category frames", function()
    h.boot()
    local M = h.addon.aura_frames
    local refresh_profiles = {}
    M.queue_wow_cooldown_refresh = function(profile)
        refresh_profiles[#refresh_profiles + 1] = profile
    end

    h.ok(M._cdm_layout_refresh_hooked,
        "Aura Frames installs the CDM layout-save refresh hook at runtime start")
    C_CooldownViewer.SetLayoutData("moved-freedom-to-essential")

    h.eq(saved_layout_data, "moved-freedom-to-essential",
        "CDM layout-save hook preserves the original public API call")
    h.eq(#refresh_profiles, 1, "one layout save queues one addon refresh")
    h.eq(refresh_profiles[1], "settings",
        "layout saves use the settling-aware CDM settings refresh profile")

    M.install_cdm_layout_refresh_hook()
    C_CooldownViewer.SetLayoutData("second-save")
    h.eq(#refresh_profiles, 2, "reinstalling the hook does not duplicate refresh callbacks")
end)

h.test("CDM cooldown cells use the native dark cooldown swipe", function()
    local M = h.addon.aura_frames
    local utility_frame = M.frames and M.frames.show_utility
    local cooldown = utility_frame and utility_frame.icons
        and utility_frame.icons[1] and utility_frame.icons[1].cooldown
    h.ok(cooldown, "Utility cooldown cell owns a cooldown widget")
    local swipe_color = cooldown:GetLastCall("SetSwipeColor")
    h.ok(swipe_color, "cooldown widget explicitly sets its swipe color")
    h.eq(swipe_color[1], 0, "cooldown swipe uses Blizzard black red channel")
    h.eq(swipe_color[2], 0, "cooldown swipe uses Blizzard black green channel")
    h.eq(swipe_color[3], 0, "cooldown swipe uses Blizzard black blue channel")
    h.eq(swipe_color[4], 0.7, "cooldown swipe uses Blizzard cooldown opacity")
end)

h.run("af_cdm_layout_refresh")

--#endregion FILE CONTENTS ===================================================
