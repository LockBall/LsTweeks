-- Aura Frames shared colors/fonts and per-frame participation matrix.


local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local GROUP_WIDTH = 700
local GROUP_OFFSET_X = 20
local CONTROL_ROW_HEIGHT = 50
local MATRIX_OFFSET_Y = CONTROL_ROW_HEIGHT + 10
local COLUMN_COUNT = 4
local COLUMN_WIDTH = 120
local COLUMN_GAP = 140
local HEADER_BAR_WIDTH = ((COLUMN_COUNT - 1) * COLUMN_GAP) + COLUMN_WIDTH
local HEADER_BAR_HEIGHT = 24
local HEADER_BAR_Y_OFFSET = 15
-- Top edge of both color pickers in each row, measured from the panel top.
local COLOR_PICKER_ROW_1_Y = -20
local COLOR_PICKER_ROW_2_Y = -70
local COLOR_PICKER_ROW_Y = { COLOR_PICKER_ROW_1_Y, COLOR_PICKER_ROW_2_Y }


--#region SHARED OPTIONS STATE =================================================

local function get_color_sync_provider()
    local color_sync = addon.all_the_colors
    if not (color_sync and color_sync.ensure_consumer_db) then return nil end
    return color_sync
end

local function refresh_shared_options()
    local color_sync = get_color_sync_provider()
    if color_sync and color_sync.sync_controls then color_sync.sync_controls() end
    if M.on_shared_options_changed then M.on_shared_options_changed() end
end

local function get_participation_rows()
    local rows = {}
    for _, frame_def in ipairs(M.FRAME_DEFS or {}) do
        rows[#rows + 1] = {
            category = frame_def.key,
            label = frame_def.frame_label or frame_def.label or frame_def.key,
            order = frame_def.tree_order or 0,
        }
    end
    table.sort(rows, function(left, right)
        return left.order < right.order
    end)
    for index, entry in ipairs(M.db and M.db.custom_frames or {}) do
        rows[#rows + 1] = {
            category = entry.id,
            label = entry.name or entry.id,
            order = 1000 + index,
        }
    end
    return rows
end

local function clear_participation_control_keys()
    for key in pairs(M.controls or {}) do
        if type(key) == "string"
            and (
                key:match("^shared_options:[^:]+:")
                or key:match("^bar_color_sync:")
                or key:match("^text_color_sync:")
                or key:match("^text_font_sync:")
            )
        then
            M.controls[key] = nil
        end
    end
end

local function refresh_participation_rows()
    local slots = M.shared_options_row_slots
    local rows_parent = M.shared_options_rows_parent
    if not (slots and rows_parent) then return end

    clear_participation_control_keys()
    local rows = get_participation_rows()
    for index, slot in ipairs(slots) do
        local row = rows[index]
        slot.category = row and row.category or nil
        slot.display_label = row and row.label or nil
        if row then
            slot.label:SetText(row.label)
            slot.background_control:SetCheckedSilently(M.get_shared_background_enabled(row.category))
            slot.bar_color_control:SetCheckedSilently(M.get_bar_color_sync_enabled(row.category))
            slot.text_color_control:SetCheckedSilently(
                M.get_text_color_sync_enabled(row.category) and M.get_text_font_sync_enabled(row.category))
            M.controls["shared_options:bg:" .. row.category] = slot.background_control
            M.controls["bar_color_sync:" .. row.category] = slot.bar_color_control
            M.controls["text_color_sync:" .. row.category] = slot.text_color_control
            slot.frame:Show()
        else
            slot.frame:Hide()
        end
    end
    rows_parent:SetHeight(math.max(1, #rows * 30))
end

function M.sync_shared_options_controls()
    local color_sync = get_color_sync_provider()
    if not (color_sync and M.controls and M.db) then return end

    local buffs_global_active = color_sync.is_global_color_active
        and color_sync.is_global_color_active(M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.buffs)
    local debuffs_global_active = color_sync.is_global_color_active
        and color_sync.is_global_color_active(M.MODULE_KEY, M.COLOR_CONSUMER_GROUPS.debuffs)
    local global_active = buffs_global_active and debuffs_global_active
    local shared_enabled = M.db.shared_options_enabled == true
    local module_controls_enabled = not global_active
    local shared_controls_enabled = shared_enabled and module_controls_enabled
    for _, column in ipairs(M.SHARED_COLOR_COLUMNS or {}) do
        for _, picker_def in ipairs(column.pickers) do
            local picker = M.controls[picker_def.control_key]
            if picker and picker.SetValue then picker:SetValue(M.db[picker_def.db_key]) end
            if picker then picker:SetEnabled(shared_controls_enabled) end
        end
    end
    for _, column in ipairs(M.SHARED_FONT_COLUMNS or {}) do
        for _, picker_def in ipairs(column.pickers) do
            local picker = M.controls[picker_def.control_key]
            if picker and picker.SetValue then picker:SetValue(M.db[picker_def.db_key]) end
            if picker then picker:SetEnabled(true) end
        end
    end
    local enabled_control = M.controls.shared_options_enabled
    if enabled_control and enabled_control.SetCheckedSilently then
        enabled_control:SetCheckedSilently(M.db.shared_options_enabled == true)
    end
    local fade_control = M.controls.shared_options_disable_ooc_fade
    if fade_control and fade_control.SetCheckedSilently then
        fade_control:SetCheckedSilently(color_sync.get_disable_ooc_fade())
    end
    local test_aura_control = M.controls.shared_options_test_auras
    if test_aura_control and test_aura_control.SetState then
        test_aura_control:SetState(
            color_sync.get_test_auras_enabled(),
            color_sync.are_test_aura_previews_paused(),
            true
        )
    end

    if enabled_control then enabled_control:SetEnabled(module_controls_enabled) end
    if fade_control then fade_control:SetEnabled(true) end
    if M.shared_options_matrix_group then M.shared_options_matrix_group:SetAlpha(1) end

    for _, slot in ipairs(M.shared_options_row_slots or {}) do
        if slot.category then
            slot.background_control:SetCheckedSilently(M.get_shared_background_enabled(slot.category))
            slot.background_control:SetEnabled(shared_controls_enabled)
            slot.bar_color_control:SetCheckedSilently(M.get_bar_color_sync_enabled(slot.category))
            slot.bar_color_control:SetEnabled(shared_controls_enabled)
            slot.text_color_control:SetCheckedSilently(
                M.get_text_color_sync_enabled(slot.category) and M.get_text_font_sync_enabled(slot.category))
            slot.text_color_control:SetEnabled(shared_controls_enabled)
        end
    end
end

function M.rebuild_shared_options_group()
    refresh_participation_rows()
    M.sync_shared_options_controls()
end

--#endregion SHARED OPTIONS STATE ==============================================


--#region TAB BUILDER ==========================================================

local function create_header_title(panel, header_grid, text, column)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetText(text)
    title:SetHeight(HEADER_BAR_HEIGHT)
    title:SetJustifyV("MIDDLE")
    header_grid:place_at(title, 1, column, nil, { y_offset = HEADER_BAR_Y_OFFSET })
end

local function build_color_controls(parent, color_sync)
    local content_height = math.max(360, (parent:GetHeight() or 0) - 20)
    local content = CreateFrame("Frame", nil, parent)
    content:SetSize(GROUP_WIDTH, content_height)
    content:SetPoint("TOPLEFT", parent, "TOPLEFT", GROUP_OFFSET_X, -10)
    local grid = addon.CreateSettingsGrid(content, {
        column_count = COLUMN_COUNT,
        col_width = COLUMN_WIDTH,
        col_gap = COLUMN_GAP,
        col_offset = 0,
        col_align = { "left", "left", "left", "left" },
        row_start = 0,
        row_heights = { CONTROL_ROW_HEIGHT },
        content_rows = 1,
        separator_right_pad = 0,
        row_separators = { 1 },
    })
    local enabled_control = addon.CreateCheckbox(
        content,
        "Enable",
        M.db.shared_options_enabled == true,
        function(is_checked)
            M.db.shared_options_enabled = is_checked == true
            M.sync_shared_options_controls()
            refresh_shared_options()
        end
    )
    grid:place_at(enabled_control, 1, 1)
    M.controls.shared_options_enabled = enabled_control

    local fade_control = addon.CreateCheckbox(
        content,
        "Disable OOC Fade",
        color_sync.get_disable_ooc_fade(),
        function(is_checked)
            if color_sync.set_disable_ooc_fade(is_checked) then
                refresh_shared_options()
            end
        end
    )
    grid:place_at(fade_control, 1, 2)
    M.controls.shared_options_disable_ooc_fade = fade_control

    local test_aura_control, test_aura_button = addon.CreateTestAuraControl(
        content,
        color_sync.get_test_auras_enabled(),
        function(checked)
            if color_sync.set_test_auras_enabled(checked) then
                M.sync_shared_options_controls()
                refresh_shared_options()
            end
        end,
        function()
            if color_sync.toggle_test_aura_previews() then
                M.sync_shared_options_controls()
                refresh_shared_options()
            end
        end,
        { paused = color_sync.are_test_aura_previews_paused() }
    )
    grid:place_at(test_aura_control, 1, 3)
    M.controls.shared_options_test_auras = test_aura_control
    M.controls.shared_options_test_auras_play_pause = test_aura_button

    return content, content_height
end

local function create_participation_slot(parent, grid, index)
    local slot = {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(GROUP_WIDTH - 50, 30)
    grid:place_at(frame, index, 1)
    slot.frame = frame
    local slot_grid = addon.CreateSettingsGrid(frame, {
        column_count = COLUMN_COUNT,
        col_width = COLUMN_WIDTH,
        col_gap = COLUMN_GAP,
        col_offset = 5,
        col_align = { "left", "center", "center", "center" },
        row_start = 0,
        row_heights = { 30 },
        content_rows = 1,
    })

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetWidth(150)
    label:SetJustifyH("LEFT")
    slot_grid:place_at(label, 1, 1)
    slot.label = label

    local background_group = CreateFrame("Frame", nil, frame)
    background_group:SetSize(30, 30)
    slot_grid:place_at(background_group, 1, 2)
    local background_grid = addon.CreateSettingsGrid(background_group, {
        column_count = 1,
        col_width = 24,
        col_gap = 24,
        col_offset = 0,
        col_align = { "center" },
        row_start = 0,
        row_heights = { 30 },
        row_gap = 0,
        content_rows = 1,
    })

    local background_control = addon.CreateCheckbox(background_group, "", false, function(is_checked)
        if slot.category and M.set_shared_background_enabled(slot.category, is_checked) then
            refresh_shared_options()
        end
    end)
    background_grid:place_at(background_control, 1, 1)
    slot.background_control = background_control

    local bar_color_control = addon.CreateCheckbox(frame, "", false, function(is_checked)
        if slot.category and M.set_bar_color_sync_enabled(slot.category, is_checked) then
            refresh_shared_options()
        end
    end)
    slot_grid:place_at(bar_color_control, 1, 3)
    slot.bar_color_control = bar_color_control

    local text_color_control = addon.CreateCheckbox(frame, "", false, function(is_checked)
        if slot.category then
            local color_changed = M.set_text_color_sync_enabled(slot.category, is_checked)
            local font_changed = M.set_text_font_sync_enabled(slot.category, is_checked)
            if color_changed or font_changed then refresh_shared_options() end
        end
    end)
    slot_grid:place_at(text_color_control, 1, 4)
    slot.text_color_control = text_color_control

    return slot
end

local function build_shared_font_column(panel, header_grid, title_text, column, picker_defs)
    create_header_title(panel, header_grid, title_text, column)
    for index, picker_def in ipairs(picker_defs) do
        local prefix = picker_def.role == "timer" and "shared_timer_text_" or "shared_bar_text_"
        local function binding(key, fallback)
            return {
                get = function()
                    local value = M.db[key]
                    return value ~= nil and value or fallback
                end,
                set = function(value) M.db[key] = value end,
                get_default = function()
                    local value = M.defaults[key]
                    return value ~= nil and value or fallback
                end,
            }
        end
        local picker_control = addon.CreateFontPicker(panel, {
            label = picker_def.label,
            popup_label = picker_def.label .. " Options",
            width = COLUMN_WIDTH,
            role = picker_def.role,
            color = binding(prefix .. "color", { r = 1, g = 1, b = 1 }),
            font = binding(picker_def.db_key, M.DEFAULT_AURA_FONT_KEY),
            size = binding(prefix .. "font_size", picker_def.role == "timer" and M.DEFAULT_TIMER_NUMBER_FONT_SIZE or 10),
            bold = binding(prefix .. "font_bold", false),
            outline = binding(prefix .. "font_outline", picker_def.role == "timer"),
            on_preview = refresh_shared_options,
        })
        header_grid:place_at(picker_control, 1, column, nil, {
            width = COLUMN_WIDTH,
            align = "center",
            y_offset = COLOR_PICKER_ROW_Y[index],
        })
        M.controls[picker_def.control_key] = picker_control

    end
end

local function build_shared_color_column(panel, header_grid, title_text, column, picker_defs)
    create_header_title(panel, header_grid, title_text, column)

    for index, picker_def in ipairs(picker_defs) do
        local picker_control = addon.CreateColorPicker(
            panel,
            M.db,
            picker_def.db_key,
            picker_def.has_alpha,
            picker_def.label,
            M.defaults,
            function(reason)
                if reason ~= "open" then refresh_shared_options() end
            end
        )
        header_grid:place_at(picker_control, 1, column, nil, {
            align = "center",
            y_offset = COLOR_PICKER_ROW_Y[index],
        })
        M.controls[picker_def.control_key] = picker_control
    end
end

local function build_participation_matrix(content, content_height)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetSize(GROUP_WIDTH, content_height - MATRIX_OFFSET_Y)
    panel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -MATRIX_OFFSET_Y)
    local header_grid = addon.CreateSettingsGrid(panel, {
        column_count = COLUMN_COUNT,
        col_width = COLUMN_WIDTH,
        col_gap = COLUMN_GAP,
        col_offset = 0,
        col_align = { "left", "center", "center", "center" },
        row_start = 0,
        row_heights = { 125 },
        row_gap = 0,
        content_rows = 1,
        separator_right_pad = 0,
    })
    local header_separator = header_grid:add_row_separator(1)
    header_separator:SetColorTexture(0.75, 0.63, 0.12, 0.35)

    local header_bar = panel:CreateTexture(nil, "BACKGROUND")
    header_bar:SetSize(HEADER_BAR_WIDTH, HEADER_BAR_HEIGHT)
    header_bar:SetColorTexture(0.22, 0.22, 0.22, 0.8)
    header_grid:place_at(header_bar, 1, 1, nil, { y_offset = HEADER_BAR_Y_OFFSET })

    create_header_title(panel, header_grid, "Frame Name", 1)
    for _, column in ipairs(M.SHARED_COLOR_COLUMNS or {}) do
        if column.title ~= "Text Colors" then
            build_shared_color_column(panel, header_grid, column.title, column.column, column.pickers)
        end
    end
    for _, column in ipairs(M.SHARED_FONT_COLUMNS or {}) do
        build_shared_font_column(panel, header_grid, column.title, column.column, column.pickers)
    end
    local rows_parent = CreateFrame("Frame", nil, panel)
    rows_parent:SetSize(GROUP_WIDTH - 50, 1)
    rows_parent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -133)
    M.shared_options_rows_parent = rows_parent
    M.shared_options_row_slots = {}

    local slot_count = #(M.FRAME_DEFS or {}) + (M.MAX_CUSTOM_FRAMES or 0)
    local row_grid = addon.CreateSettingsGrid(rows_parent, {
        column_count = 1,
        col_width = GROUP_WIDTH - 50,
        col_gap = GROUP_WIDTH - 50,
        col_offset = 0,
        col_align = { "left" },
        row_start = 0,
        row_heights = { 30 },
        row_gap = 0,
        content_rows = slot_count,
    })
    for index = 1, slot_count do
        M.shared_options_row_slots[index] = create_participation_slot(rows_parent, row_grid, index)
    end
    refresh_participation_rows()
    return panel
end

function M.build_shared_options_tab(parent)
    local color_sync = get_color_sync_provider()
    if not (color_sync and color_sync.get_color_preset and M.db) then return end
    M.shared_background_color_parent = parent
    local content, content_height = build_color_controls(parent, color_sync)
    M.shared_background_color_group = content
    M.shared_options_matrix_group = build_participation_matrix(content, content_height)
    M.sync_shared_options_controls()
end

--#endregion TAB BUILDER =======================================================
