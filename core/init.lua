-- Addon entry point: initializes the shared addon table, defines UI_THEME constants,
-- sets up SavedVariables (Ls_Tweeks_DB), and registers the /lst slash command.
-- Loads first; every other file reads addon.UI_THEME and writes into Ls_Tweeks_DB through the patterns established here.

local addon_name, addon = ...
addon.name = addon_name

-- Shared UI font tokens used across all modules.
-- Rivet panel layout constants (padding, sizing, positioning) live in addon.RIVETED_PANEL_STYLE in panel_riveted.lua.
addon.UI_THEME = {
    font_title    = "GameFontHighlight",
    font_subtitle = "GameFontHighlightSmall",
    font_body     = "GameFontNormal",
}

-- Shared timing buckets. Runtime code should choose a named bucket/profile
-- instead of scattering raw debounce or refresh intervals.
addon.UPDATE_INTERVALS = {
    next_frame = 0,
    tenth_sec = 0.1,
    fifth_sec = 0.2,
    half_sec = 0.5,
    six_tenths_sec = 0.6,
    one_point_two_sec = 1.2,
    two_point_five_sec = 2.5,
    five_sec = 5.0,
}

-- Behavior-specific timing aliases. Keep these as the adjustment points for
-- profiling and responsiveness tests instead of changing generic buckets.

-- CPU profile hotness: high; drives deferred Aura Frames refresh/update work.
addon.UPDATE_INTERVALS.aura_event_bucket = addon.UPDATE_INTERVALS.fifth_sec

-- CPU profile hotness: high; strongest direct ticker candidate from the profile.
addon.UPDATE_INTERVALS.aura_visible_icon_tick = addon.UPDATE_INTERVALS.tenth_sec

-- CPU profile hotness: low; hover-only maintenance path.
addon.UPDATE_INTERVALS.aura_hover_check = addon.UPDATE_INTERVALS.fifth_sec

-- CPU profile hotness: low; active only during Player Frame fade.
addon.UPDATE_INTERVALS.player_frame_fade_tick = addon.UPDATE_INTERVALS.fifth_sec

-- CPU profile hotness: moderate; visible in broad profile but already 0.2s.
addon.UPDATE_INTERVALS.skyriding_vigor_tick = addon.UPDATE_INTERVALS.fifth_sec


function addon.get_version()
    if not addon.version and C_AddOns and C_AddOns.GetAddOnMetadata then
        addon.version = C_AddOns.GetAddOnMetadata(addon_name, "Version")
    end
    return addon.version or "unknown"
end

-- DATABASE INITIALIZATION
local function init_db()
    -- Ensure the global DB exists with the Tweeks spelling
    _G.Ls_Tweeks_DB = _G.Ls_Tweeks_DB or {}
    
    -- Core Minimap defaults
    if not Ls_Tweeks_DB.minimap then
        Ls_Tweeks_DB.minimap = { hide = false }
    end

    -- Ensure the aura_frames sub-table exists for the module to use
    if not Ls_Tweeks_DB.aura_frames then
        Ls_Tweeks_DB.aura_frames = {}
    end
end

-- MAIN INITIALIZATION SEQUENCE
local function on_event(self, event, name)
    if name ~= addon_name then return end

    -- Store version from TOC
    addon.get_version()

    -- Setup Global DB
    init_db()

    -- Initialize the core UI frame
    if addon.init_main_frame then
        addon.init_main_frame()
    end

    -- Initialize the LDB/Minimap button
    if addon.init_minimap_button then
        addon.init_minimap_button()
    end
    
    -- Note: Aura Frames will initialize themselves in af_main.lua
    -- using the Ls_Tweeks_DB.aura_frames table we ensured exists above.
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", on_event)

-- AUTO-OPEN on reload/login if the setting is enabled
local f2 = CreateFrame("Frame")
f2:RegisterEvent("PLAYER_ENTERING_WORLD")
f2:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    if (isInitialLogin or isReloadingUi) and Ls_Tweeks_DB and Ls_Tweeks_DB.open_on_reload then
        if addon.main_frame then
            addon.main_frame:Show()
        end
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- SLASH COMMANDS
-- Primary command: /lst (short for L's Tweeks)
SLASH_LSTWEEKS1 = "/lst"
SlashCmdList["LSTWEEKS"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    if addon.main_frame then
        if addon.main_frame:IsShown() then
            addon.main_frame:Hide()
        else
            addon.main_frame:Show()
        end
    end
end
