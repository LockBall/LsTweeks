-- Default DB values for the Objectives module.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

local M = addon.objectives or {}
addon.objectives = M

M.MODULE_KEY = "objectives"

local SLIDER_WITH_BOX_SIZE = addon.SLIDER_WITH_BOX_SIZE

function M.get_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.objectives = Ls_Tweeks_DB.objectives or {}
    return Ls_Tweeks_DB.objectives
end

function M.is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(M.MODULE_KEY)
end

function M.get_objective_tracker()
    local tracker = ObjectiveTrackerFrame
    if tracker and tracker.NineSlice then
        return tracker
    end
    return nil
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
        customize_background = false,
        background_color_enabled = false,
        background_color = { r = 0.25, g = 0.25, b = 0.25, a = 0.75 },
        background_alpha = 0.5,
        objective_tracker_move_mode = false,
        objective_tracker_snap_to_grid = false,
        objective_tracker_offset_x = 0,
        objective_tracker_offset_y = 0,
        last_tab_index = 1,
        last_profile_name = nil,
        profiles = {},
    },
}

M.SETTINGS_LAYOUT = {
    group_offset_x = 20,
    group_padding_x = 12,
    grid_offset_x = 12,
    grid_offset_y = -37,
    grid_column_gap_x = 18,
    slider_col_width = SLIDER_WITH_BOX_SIZE.width,
    slider_row_height = SLIDER_WITH_BOX_SIZE.height + 5,
    groups = {
        position = {
            offset_y = -20,
            width = 1,
            height = 150,
        },
        background = {
            offset_y = -180,
            width = 673,
            height = 150,
        },
        auto_collapse = {
            offset_y = -340,
            width = 1,
            height = 158,
            grid_col_width = 220,
            grid_col_gap = 220,
            child_gap_y = -8,
            child_indent_x = 18,
        },
        section_count = {
            offset_y = -514,
            width = 1,
            height = 112,
            grid_col_width = 130,
            sub_checkbox_gap_y = -2,
            sub_checkbox_indent_x = 18,
        },
    },
}

local color_sync = addon.background_color_sync
if color_sync and color_sync.register_consumer then
    color_sync.register_consumer(M.MODULE_KEY, {
        label = "Objectives",
        order = 200,
        global_toggle = true,
        global_order = 100,
        default_global_enabled = true,
        global_only = true,
        default_color = M.defaults.objectives.background_color,
        refresh = function()
            if M.on_background_color_sync_changed then
                M.on_background_color_sync_changed()
            end
        end,
    })
    color_sync.register_target(M.MODULE_KEY, "custom_background", {
        label = "Custom Background",
        row_key = "custom_background",
        row_label = "Custom Background",
        column = 2,
        column_label = "Background",
        order = 1,
        default_enabled = true,
        supports_visibility = true,
    })
end

return M

--#endregion FILE CONTENTS ===================================================
