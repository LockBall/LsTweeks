-- Minimap button via LibDataBroker and LibDBIcon.
-- Left-click toggles the LsTweeks settings window; visibility is controlled by the minimap.hide DB key.


--#region FILE CONTENTS ======================================================


local addon_name, addon = ...

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

-- Configuration Constants
local CONFIG = {
    name = "Ls_Tweeks_Minimap",
   -- icon = "Interface\\AddOns\\LsTweeks\\media\\icon_256",
   -- Inv_misc_enggizmos_swissarmy
   -- Inv_misc_wrench_01
    icon = "Interface\\Icons\\Trade_engineering",
    title = "L's Tweeks",
    tooltip_left_click = "Left-click: Open main window",
    tooltip_right_click = "Right-click: Quick Picks",
}

-- Private Helper: Toggle main frame visibility
local function toggle_main_frame()
    if addon.main_frame then
        if addon.main_frame:IsShown() then
            addon.main_frame:Hide()
        else
            addon.main_frame:Show()
        end
    elseif addon.init_main_frame then
        addon.init_main_frame()
        if addon.main_frame then addon.main_frame:Show() end
    end
end

local function get_audio_volumes_module()
    return addon.sound_levels
end

local function is_quick_pick_enabled(quick_pick_key)
    local M = get_audio_volumes_module()
    local profile_db = M and M.get_situation_profile_db and M.get_situation_profile_db(quick_pick_key)
    return profile_db and profile_db.enabled == true
end

local function apply_quick_pick(quick_pick_key)
    local M = get_audio_volumes_module()
    if not (M and M.set_quick_pick_from_menu) then return end
    M.set_quick_pick_from_menu(quick_pick_key, not is_quick_pick_enabled(quick_pick_key))
end

local function create_disabled_menu_button(root_description, text)
    local button = root_description:CreateButton(text)
    if button and button.SetEnabled then
        button:SetEnabled(false)
    end
end

local function show_menu(owner, module_enabled, get_entries)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        print("LsTweeks: MenuUtil.CreateContextMenu is unavailable; Quick Picks menu cannot open.")
        return
    end

    MenuUtil.CreateContextMenu(owner, function(_, root_description)
        root_description:CreateTitle("Quick Picks")
        if not module_enabled then
            create_disabled_menu_button(root_description, "Audio Volumes is disabled")
            return
        end
        local entries = get_entries and get_entries() or {}
        if #entries == 0 then
            create_disabled_menu_button(root_description, "No Quick Picks")
            return
        end
        for _, entry in ipairs(entries) do
            local quick_pick_key = entry.key
            local quick_pick_label = entry.label
            root_description:CreateCheckbox(
                quick_pick_label,
                function()
                    return is_quick_pick_enabled(quick_pick_key)
                end,
                function()
                    apply_quick_pick(quick_pick_key)
                    if MenuResponse and MenuResponse.Refresh then
                        return MenuResponse.Refresh
                    end
                end
            )
        end
    end)
end

local function build_quick_pick_menu(owner)
    local M = get_audio_volumes_module()
    local module_enabled = not (addon.is_module_enabled and M and M.MODULE_KEY)
        or addon.is_module_enabled(M.MODULE_KEY)
    show_menu(owner, module_enabled, function()
        return M and M.get_quick_pick_menu_entries and M.get_quick_pick_menu_entries() or {}
    end)
end

-- ============================================================================
-- LDB DATA OBJECT
-- LibDataBroker: Provides a data source for minimap buttons via LibDBIcon.
-- OnClick handles opening the settings window from the minimap icon.
-- OnTooltipShow provides contextual help when hovering over the button.
addon.data_object = LDB:NewDataObject(CONFIG.name, {
    type = "launcher",
    icon = CONFIG.icon,

    OnClick = function(owner, button)
        if button == "LeftButton" then
            toggle_main_frame()
        elseif button == "RightButton" then
            build_quick_pick_menu(owner)
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine(CONFIG.title)
        tooltip:AddLine(CONFIG.tooltip_left_click, 1, 1, 1)
        tooltip:AddLine(CONFIG.tooltip_right_click, 1, 1, 1)
    end,
})

-- ============================================================================
-- PUBLIC API
function addon.toggle_minimap_button(show)
    Ls_Tweeks_DB.minimap = Ls_Tweeks_DB.minimap or {}
    Ls_Tweeks_DB.minimap.hide = not show

    if show then
        LDBIcon:Show(CONFIG.name)
    else
        LDBIcon:Hide(CONFIG.name)
    end
end

-- ============================================================================
-- INITIALIZER
-- ============================================================================
function addon.init_minimap_button()
    Ls_Tweeks_DB = Ls_Tweeks_DB or {}
    Ls_Tweeks_DB.minimap = Ls_Tweeks_DB.minimap or {}

    -- Register with LibDBIcon (uses saved state in Ls_Tweeks_DB.minimap)
    LDBIcon:Register(CONFIG.name, addon.data_object, Ls_Tweeks_DB.minimap)

    -- Apply saved visibility state
    if Ls_Tweeks_DB.minimap.hide then
        LDBIcon:Hide(CONFIG.name)
    else
        LDBIcon:Show(CONFIG.name)
    end
end

--#endregion FILE CONTENTS ===================================================
