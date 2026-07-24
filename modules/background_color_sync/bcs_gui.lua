-- Registry-driven General and Profiles settings for Background Colors.


local addon_name, addon = ...

addon.background_color_sync = addon.background_color_sync or {}
local M = addon.background_color_sync
M.controls = M.controls or {}
M.color_groups = M.color_groups or {}


--#region LAYOUT ===============================================================

local DEFAULT_CONTENT_WIDTH = 787
local GROUP_OFFSET_X = 20
local GROUP_RIGHT_MARGIN = 20
local GRID_COLUMN_WIDTH = 220
local GRID_COLUMN_GAP = 235

local function get_content_width()
    if addon.main_frame and addon.main_frame.GetContentAreaSize then
        local width = addon.main_frame:GetContentAreaSize()
        if width and width > 0 then
            return width
        end
    end
    return DEFAULT_CONTENT_WIDTH
end

local function create_group_grid(group, row_heights)
    return addon.CreateSettingsGrid(group, {
        column_count = 3,
        col_offset = 16,
        row_start = -42,
        col_width = GRID_COLUMN_WIDTH,
        col_gap = GRID_COLUMN_GAP,
        row_gap = 0,
        row_heights = row_heights,
        col_align = { "left", "left", "left" },
        offsets = { default = 0, picker = 4 },
    })
end

--#endregion LAYOUT ============================================================


--#region CONTROL KEYS AND SYNCHRONIZATION =====================================

local function global_consumer_control_key(module_key)
    return "global_consumer:" .. module_key
end

local function sync_global_color_controls()
    local db_table, color_key = M.get_color_binding()
    if not db_table then return end

    local picker = M.controls.global_color_picker
    if picker and picker.SetValue then
        picker:SetValue(db_table[color_key])
    end
    local selector = M.controls.global_color_preset
    if selector and selector.SetValue then
        selector:SetValue(M.get_color_preset(db_table[color_key]))
    end
end

function M.sync_controls()
    local db = M.get_db()
    if not db then return end

    local global_enabled = db.global_enabled == true
    local global_control = M.controls.global_enabled
    if global_control and global_control.SetCheckedSilently then
        global_control:SetCheckedSilently(global_enabled)
    end
    local visibility_control = M.controls.global_enable_all_backgrounds
    if visibility_control and visibility_control.SetCheckedSilently then
        visibility_control:SetCheckedSilently(db.global_enable_all_backgrounds == true)
        visibility_control:SetEnabled(true)
    end
    local fade_control = M.controls.global_disable_ooc_fade
    if fade_control and fade_control.SetCheckedSilently then
        fade_control:SetCheckedSilently(M.get_disable_ooc_fade())
        fade_control:SetEnabled(true)
    end
    sync_global_color_controls()
    local global_picker = M.controls.global_color_picker
    local global_selector = M.controls.global_color_preset
    if global_picker then global_picker:SetEnabled(global_enabled) end
    if global_selector then global_selector:SetEnabled(global_enabled) end

    for _, consumer in ipairs(M.get_registered_consumers()) do
        local consumer_db = M.ensure_consumer_db(consumer.key)
        local global_consumer_control = M.controls[global_consumer_control_key(consumer.key)]
        if global_consumer_control and global_consumer_control.SetCheckedSilently then
            global_consumer_control:SetCheckedSilently(consumer_db.global_enabled == true)
            global_consumer_control:SetEnabled(global_enabled)
        end
    end
end

--#endregion CONTROL KEYS AND SYNCHRONIZATION ==================================


--#region CONTROL BUILDERS =====================================================

local function create_bound_checkbox(
    parent,
    grid,
    control_key,
    label,
    get_value,
    set_value,
    row,
    column,
    tooltip,
    placement
)
    local control, _, label_region = addon.CreateCheckbox(parent, label, get_value() == true, function(value)
        set_value(value == true)
        M.sync_controls()
        M.refresh_consumers()
    end)
    if placement and placement.below then
        grid:stack_below(control, placement.below, {
            x = placement.x or 0,
            y = placement.y or 0,
        })
    else
        grid:place_at(control, row, column)
    end
    M.controls[control_key] = control
    if tooltip and addon.AttachTooltip then
        addon.AttachTooltip(label ~= "" and label_region or control.checkbox, nil, tooltip)
    end
    return control
end

local function select_preset(preset_key)
    if not M.set_color_preset(nil, preset_key) then return end
    sync_global_color_controls()
    M.refresh_consumers()
end

local function create_global_color_controls(parent, grid, label, row, opts)
    opts = opts or {}
    local db_table, color_key, defaults = M.get_color_binding()
    if not db_table then return end
    local selector = addon.CreateCyclingDropdown(
        addon_name .. "global_colorPreset",
        parent,
        opts.selector_label or (label .. " Preset"),
        M.PRESET_OPTIONS,
        {
            width = opts.selector_width or 160,
            fit_to_options = opts.selector_fit_to_options,
            get_value = function()
                return M.get_color_preset(db_table[color_key])
            end,
            get_unknown_text = function()
                return "Custom"
            end,
            on_select = function(value)
                select_preset(value)
            end,
        }
    )
    grid:place_at(selector, opts.selector_row or row, opts.selector_column or 1)
    M.controls.global_color_preset = selector

    local picker = addon.CreateColorPicker(
        parent,
        db_table,
        color_key,
        true,
        opts.picker_label or (label .. " Color"),
        defaults,
        function(reason)
            if reason == "open" then return end
            sync_global_color_controls()
            M.refresh_consumers()
        end
    )
    grid:place_at(picker, opts.picker_row or row, opts.picker_column or 2, "picker")
    M.controls.global_color_picker = picker
end

--#endregion CONTROL BUILDERS ==================================================

--#region GLOBAL CONSUMERS =====================================================

local function get_global_toggle_consumers()
    local consumers = {}
    for _, consumer in ipairs(M.get_registered_consumers()) do
        if consumer.global_toggle == true then
            consumers[#consumers + 1] = consumer
        end
    end
    table.sort(consumers, function(left, right)
        local left_order = left.global_order or left.order or 100
        local right_order = right.global_order or right.order or 100
        if left_order == right_order then
            return (left._registered_index or 0) < (right._registered_index or 0)
        end
        return left_order < right_order
    end)
    return consumers
end

--#endregion GLOBAL CONSUMERS ==================================================


--#region TAB BUILDERS =========================================================

local function build_global_group(parent)
    M.controls = {}
    M.color_groups = {}

    local group_width = get_content_width() - GROUP_OFFSET_X - GROUP_RIGHT_MARGIN
    local global_consumers = get_global_toggle_consumers()
    local global_height = 136 + (#global_consumers * 26)
    local global_group = addon.CreateSettingsGroup(
        parent,
        "Global",
        group_width,
        global_height,
        0,
        0
    )
    local global_grid = create_group_grid(global_group, { 26, 26, 80 })
    local db = M.get_db()
    create_bound_checkbox(
        global_group,
        global_grid,
        "global_enable_all_backgrounds",
        "Enable All Backgrounds",
        function() return db.global_enable_all_backgrounds end,
        function(value) db.global_enable_all_backgrounds = value end,
        1,
        1
    )
    create_bound_checkbox(
        global_group,
        global_grid,
        "global_disable_ooc_fade",
        "Disable OOC Fade",
        M.get_disable_ooc_fade,
        M.set_disable_ooc_fade,
        2,
        1,
        "Prevents registered backgrounds from fading out of combat."
    )
    local global_color_row = 3
    local global_enable = create_bound_checkbox(
        global_group,
        global_grid,
        "global_enabled",
        "Enable Global Color",
        function() return db.global_enabled end,
        function(value) db.global_enabled = value end,
        global_color_row,
        1,
        "Use one color across all modules"
    )
    create_global_color_controls(global_group, global_grid, "Global", 1, {
        selector_row = global_color_row,
        selector_column = 2,
        selector_label = "Preset Colors",
        selector_fit_to_options = true,
        picker_row = global_color_row,
        picker_column = 3,
        picker_label = "Custom Color",
    })
    local previous_global_control = global_enable
    for index, consumer in ipairs(global_consumers) do
        local consumer_db = M.ensure_consumer_db(consumer.key)
        previous_global_control = create_bound_checkbox(
            global_group,
            global_grid,
            global_consumer_control_key(consumer.key),
            consumer.label,
            function() return consumer_db.global_enabled end,
            function(value) consumer_db.global_enabled = value end,
            1,
            1,
            "Include " .. consumer.label .. " in the global color override.",
            { below = previous_global_control, x = index == 1 and 18 or 0, y = -2 }
        )
    end
    M.color_groups.global = global_group
    M.sync_controls()
    return global_group, global_height, group_width
end

function M.BuildGeneralTab(parent)
    local global_group, global_height, group_width = build_global_group(parent)

    local reset = addon.CreateModuleReset(parent, M.get_db(), M.defaults.background_color_sync, {
        preserve_label = "Keep Profiles",
        preserve_default = true,
        preserve_keys = { "profiles", "last_profile_name" },
        after_reset = M.on_reset_complete,
    })

    local section_grid = addon.CreateSettingsGrid(parent, {
        column_count = 1,
        col_width = group_width,
        col_gap = group_width,
        col_offset = GROUP_OFFSET_X,
        col_align = { "left" },
        row_start = -10,
        row_heights = { global_height + 15, 150 },
        row_gap = 0,
        content_rows = 2,
    })
    section_grid:place_at(global_group, 1, 1)
    section_grid:place_at(reset, 2, 1)
end

function M.BuildProfilesTab(parent)
    M.refresh_profiles_tab = addon.BuildProfilesTab(parent, M.profile_manager, {
        label = M.CATEGORY_NAME,
        note = "Profiles save global policy plus whole-module participation.",
    })
end

--#endregion TAB BUILDERS ======================================================


--#region SETTINGS CONSTRUCTION ================================================

function M.BuildSettings(parent)
    local db = M.get_db()
    local tabs = {}
    local panels = {}
    local definitions = {
        { label = "General", builder = M.BuildGeneralTab },
        { label = "Profiles", builder = M.BuildProfilesTab },
    }
    local selected_index = math.max(1, math.min(#definitions, tonumber(db.last_tab_index) or 1))

    local function build_panel(index)
        local old_panel = panels[index]
        if old_panel then old_panel:Hide() end
        local panel = CreateFrame("Frame", nil, parent)
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -48)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        panels[index] = panel
        definitions[index].builder(panel)
        return panel
    end

    local function select_tab(index)
        selected_index = definitions[index] and index or 1
        db.last_tab_index = selected_index
        for panel_index, panel in ipairs(panels) do
            panel:SetShown(panel_index == selected_index)
            if panel_index == selected_index then
                PanelTemplates_SelectTab(tabs[panel_index])
            else
                PanelTemplates_DeselectTab(tabs[panel_index])
            end
        end
    end

    for index, definition in ipairs(definitions) do
        local tab = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate")
        tab:SetID(index)
        tab:SetText(definition.label)
        tab:SetPoint(
            index == 1 and "TOPLEFT" or "LEFT",
            index == 1 and parent or tabs[index - 1],
            index == 1 and "TOPLEFT" or "RIGHT",
            index == 1 and 20 or 5,
            -12
        )
        PanelTemplates_TabResize(tab, 0)
        tabs[index] = tab
        build_panel(index)
        tab:SetScript("OnClick", function(self)
            select_tab(self:GetID())
        end)
    end

    M.rebuild_general_tab = function()
        build_panel(1)
        panels[1]:SetShown(selected_index == 1)
    end
    PanelTemplates_SetNumTabs(parent, #definitions)
    select_tab(selected_index)
    PanelTemplates_UpdateTabs(parent)
end

function M.on_registry_changed()
    if M.rebuild_general_tab then
        M.rebuild_general_tab()
    end
end

--#endregion SETTINGS CONSTRUCTION =============================================
