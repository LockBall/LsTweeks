-- Registry-driven General, Colors, and Profiles settings for Background Colors.


local addon_name, addon = ...

addon.background_color_sync = addon.background_color_sync or {}
local M = addon.background_color_sync
M.controls = M.controls or {}
M.color_groups = M.color_groups or {}


--#region LAYOUT ===============================================================

local DEFAULT_CONTENT_WIDTH = 787
local SCROLLBAR_WIDTH = 26
local GROUP_OFFSET_X = 20
local GROUP_RIGHT_MARGIN = 20
local GROUP_GAP_Y = 15
local GRID_COLUMN_WIDTH = 220
local GRID_COLUMN_GAP = 235
local TARGET_ROW_HEIGHT = 30

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

local function create_grid_label(parent, grid, text, row, column, font_object)
    local label = parent:CreateFontString(nil, "OVERLAY", font_object or "GameFontNormalSmall")
    label:SetText(text)
    grid:place_at(label, row, column)
    return label
end

--#endregion LAYOUT ============================================================


--#region CONTROL KEYS AND SYNCHRONIZATION =====================================

local function consumer_control_key(module_key, suffix)
    return "consumer:" .. module_key .. ":" .. suffix
end

local function target_control_key(module_key, target_key)
    return "target:" .. module_key .. ":" .. target_key
end

local function sync_color_controls(module_key)
    local db_table, color_key = M.get_color_binding(module_key)
    if not db_table then return end
    local prefix = module_key and consumer_control_key(module_key, "color") or "global_color"

    local picker = M.controls[prefix .. "_picker"]
    if picker and picker.SetValue then
        picker:SetValue(db_table[color_key])
    end
    local selector = M.controls[prefix .. "_preset"]
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
    sync_color_controls(nil)
    local global_picker = M.controls.global_color_picker
    local global_selector = M.controls.global_color_preset
    if global_picker then global_picker:SetEnabled(global_enabled) end
    if global_selector then global_selector:SetEnabled(global_enabled) end

    for _, consumer in ipairs(M.get_registered_consumers()) do
        local consumer_db = M.ensure_consumer_db(consumer.key)
        local enabled_key = consumer_control_key(consumer.key, "enabled")
        local enabled_control = M.controls[enabled_key]
        if enabled_control and enabled_control.SetCheckedSilently then
            enabled_control:SetCheckedSilently(consumer_db.enabled == true)
            enabled_control:SetEnabled(not global_enabled)
        end

        sync_color_controls(consumer.key)
        local color_enabled = not global_enabled and consumer_db.enabled == true
        local color_prefix = consumer_control_key(consumer.key, "color")
        local picker = M.controls[color_prefix .. "_picker"]
        local selector = M.controls[color_prefix .. "_preset"]
        if picker then picker:SetEnabled(color_enabled) end
        if selector then selector:SetEnabled(color_enabled) end

        for _, target in ipairs(M.get_registered_targets(consumer.key)) do
            local control = M.controls[target_control_key(consumer.key, target.key)]
            if control and control.SetCheckedSilently then
                control:SetCheckedSilently(consumer_db.targets[target.key] == true)
                control:SetEnabled(true)
            end
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
        grid:stack_below(control, placement.below, { y = placement.y or 0 })
    else
        grid:place_at(control, row, column)
    end
    M.controls[control_key] = control
    if tooltip and addon.AttachTooltip then
        addon.AttachTooltip(label ~= "" and label_region or control.checkbox, nil, tooltip)
    end
    return control
end

local function select_preset(module_key, preset_key)
    if not M.set_color_preset(module_key, preset_key) then return end
    sync_color_controls(module_key)
    M.refresh_consumers()
end

local function create_color_controls(parent, grid, module_key, label, row, opts)
    opts = opts or {}
    local db_table, color_key, defaults = M.get_color_binding(module_key)
    if not db_table then return end
    local prefix = module_key and consumer_control_key(module_key, "color") or "global_color"
    local selector = addon.CreateCyclingDropdown(
        addon_name .. prefix .. "Preset",
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
                select_preset(module_key, value)
            end,
        }
    )
    grid:place_at(selector, opts.selector_row or row, opts.selector_column or 1)
    M.controls[prefix .. "_preset"] = selector

    local picker = addon.CreateColorPicker(
        parent,
        db_table,
        color_key,
        true,
        opts.picker_label or (label .. " Color"),
        defaults,
        function(reason)
            if reason == "open" then return end
            sync_color_controls(module_key)
            M.refresh_consumers()
        end
    )
    grid:place_at(picker, opts.picker_row or row, opts.picker_column or 2, "picker")
    M.controls[prefix .. "_picker"] = picker
end

--#endregion CONTROL BUILDERS ==================================================


--#region REGISTERED TARGET ROWS ===============================================

local function get_target_rows(consumer)
    local rows_by_key = {}
    local rows = {}
    for _, target in ipairs(M.get_registered_targets(consumer.key)) do
        local row = rows_by_key[target.row_key]
        if not row then
            row = {
                key = target.row_key,
                label = target.row_label,
                order = target.order,
                targets = {},
            }
            rows_by_key[target.row_key] = row
            rows[#rows + 1] = row
        end
        row.targets[target.column] = target
        if (target.order or 100) < (row.order or 100) then
            row.order = target.order
        end
    end
    table.sort(rows, function(left, right)
        if (left.order or 100) == (right.order or 100) then
            return left.key < right.key
        end
        return (left.order or 100) < (right.order or 100)
    end)
    return rows
end

local function get_column_labels(consumer)
    local labels = {}
    for _, target in ipairs(M.get_registered_targets(consumer.key)) do
        labels[target.column] = labels[target.column] or target.column_label
    end
    return labels
end

local function build_consumer_group(parent, consumer, group_width, offset_y)
    local rows = get_target_rows(consumer)
    local row_heights = { 45, 50, 32 }
    for _ = 1, #rows do
        row_heights[#row_heights + 1] = TARGET_ROW_HEIGHT
    end
    local group_height = 180 + (#rows * TARGET_ROW_HEIGHT)
    local group = addon.CreateSettingsGroup(parent, consumer.label, group_width, group_height, GROUP_OFFSET_X, offset_y)
    local grid = create_group_grid(group, row_heights)
    local consumer_db = M.ensure_consumer_db(consumer.key)

    create_bound_checkbox(
        group,
        grid,
        consumer_control_key(consumer.key, "enabled"),
        "Use one color for this module",
        function() return consumer_db.enabled end,
        function(value) consumer_db.enabled = value end,
        1,
        1
    )
    create_color_controls(group, grid, consumer.key, "Module", 2)

    local column_labels = get_column_labels(consumer)
    for column = 2, 3 do
        if column_labels[column] then
            create_grid_label(group, grid, column_labels[column], 3, column, "GameFontNormal")
        end
    end

    for row_index, row in ipairs(rows) do
        local grid_row = row_index + 3
        create_grid_label(group, grid, row.label, grid_row, 1, "GameFontNormalSmall")
        for column = 2, 3 do
            local target = row.targets[column]
            if target then
                create_bound_checkbox(
                    group,
                    grid,
                    target_control_key(consumer.key, target.key),
                    "",
                    function() return consumer_db.targets[target.key] end,
                    function(value) consumer_db.targets[target.key] = value end,
                    grid_row,
                    column,
                    target.label
                )
            end
        end
    end

    M.color_groups[consumer.key] = group
    return group_height
end

--#endregion REGISTERED TARGET ROWS ============================================


--#region TAB BUILDERS =========================================================

function M.BuildGeneralTab(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", addon.UI_THEME.font_title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -20)
    title:SetText(M.CATEGORY_NAME)

    local reset = addon.CreateModuleReset(parent, M.get_db(), M.defaults.background_color_sync, {
        preserve_label = "Keep Profiles",
        preserve_default = true,
        preserve_keys = { "profiles", "last_profile_name" },
        after_reset = M.on_reset_complete,
    })
    reset:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
end

function M.BuildColorsTab(parent)
    M.controls = {}
    M.color_groups = {}

    local scroll_frame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll_frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scroll_frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 0)

    local scroll_child = CreateFrame("Frame", nil, scroll_frame)
    local child_width = get_content_width() - SCROLLBAR_WIDTH
    scroll_child:SetWidth(child_width)
    scroll_frame:SetScrollChild(scroll_child)
    M.color_scroll_frame = scroll_frame
    M.color_scroll_child = scroll_child

    local group_width = child_width - GROUP_OFFSET_X - GROUP_RIGHT_MARGIN
    local offset_y = -10
    local global_height = 110
    local global_group = addon.CreateSettingsGroup(
        scroll_child,
        "Global",
        group_width,
        global_height,
        GROUP_OFFSET_X,
        offset_y
    )
    local global_grid = create_group_grid(global_group, { 80 })
    local db = M.get_db()
    local global_enable = create_bound_checkbox(
        global_group,
        global_grid,
        "global_enabled",
        "Enable Global Color",
        function() return db.global_enabled end,
        function(value) db.global_enabled = value end,
        1,
        1,
        "Use one color across all modules"
    )
    create_color_controls(global_group, global_grid, nil, "Global", 1, {
        selector_column = 2,
        selector_label = "Preset Colors",
        selector_fit_to_options = true,
        picker_row = 1,
        picker_column = 3,
        picker_label = "Custom Color",
    })
    create_bound_checkbox(
        global_group,
        global_grid,
        "global_enable_all_backgrounds",
        "Enable All Backgrounds",
        function() return db.global_enable_all_backgrounds end,
        function(value) db.global_enable_all_backgrounds = value end,
        1,
        1,
        nil,
        { below = global_enable, y = -4 }
    )
    M.color_groups.global = global_group
    offset_y = offset_y - global_height - GROUP_GAP_Y

    for _, consumer in ipairs(M.get_registered_consumers()) do
        local group_height = build_consumer_group(scroll_child, consumer, group_width, offset_y)
        offset_y = offset_y - group_height - GROUP_GAP_Y
    end
    scroll_child:SetHeight(math.max(1, math.abs(offset_y) + 10))
    M.sync_controls()
end

function M.BuildProfilesTab(parent)
    M.refresh_profiles_tab = addon.BuildProfilesTab(parent, M.profile_manager, {
        label = M.CATEGORY_NAME,
        note = "Profiles save global policy plus every registered module color and target selection.",
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
        { label = "Colors", builder = M.BuildColorsTab },
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

    M.rebuild_colors_tab = function()
        build_panel(2)
        panels[2]:SetShown(selected_index == 2)
    end
    PanelTemplates_SetNumTabs(parent, #definitions)
    select_tab(selected_index)
    PanelTemplates_UpdateTabs(parent)
end

function M.on_registry_changed()
    if M.rebuild_colors_tab then
        M.rebuild_colors_tab()
    end
end

--#endregion SETTINGS CONSTRUCTION =============================================
