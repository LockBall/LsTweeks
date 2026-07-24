-- Aura Frames background color settings and per-frame participation matrix.


local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local GROUP_WIDTH = 700
local GROUP_OFFSET_X = 20
local CONTROL_ROW_HEIGHT = 65
local MATRIX_OFFSET_Y = CONTROL_ROW_HEIGHT + 10
local COLUMN_COUNT = 4
local COLUMN_WIDTH = 140
local COLUMN_GAP = 165
local HEADER_BAR_WIDTH = ((COLUMN_COUNT - 1) * COLUMN_GAP) + COLUMN_WIDTH
local HEADER_BAR_HEIGHT = 24
local HEADER_TITLE_Y_OFFSET = -6


--#region SHARED COLOR STATE ===================================================

local function get_background_color_sync()
    local color_sync = addon.background_color_sync
    if not (color_sync and color_sync.ensure_consumer_db) then return nil end
    return color_sync
end

local function refresh_background_color_sync()
    local color_sync = get_background_color_sync()
    if not color_sync then return end
    if color_sync.sync_controls then color_sync.sync_controls() end
    if color_sync.refresh_consumers then color_sync.refresh_consumers() end
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
                key:match("^background_color_sync:[^:]+:")
                or key:match("^shared_test_aura:")
            )
        then
            M.controls[key] = nil
        end
    end
end

local function refresh_participation_rows()
    local slots = M.background_color_row_slots
    local rows_parent = M.background_color_rows_parent
    if not (slots and rows_parent) then return end

    clear_participation_control_keys()
    local rows = get_participation_rows()
    for index, slot in ipairs(slots) do
        local row = rows[index]
        slot.category = row and row.category or nil
        slot.display_label = row and row.label or nil
        if row then
            slot.label:SetText(row.label)
            slot.frame_control:SetCheckedSilently(M.get_background_color_sync_enabled(row.category, "frame"))
            slot.bar_control:SetCheckedSilently(M.get_background_color_sync_enabled(row.category, "bar"))
            M.controls["background_color_sync:" .. M.get_background_color_target_key(row.category, "frame")] =
                slot.frame_control
            M.controls["background_color_sync:" .. M.get_background_color_target_key(row.category, "bar")] =
                slot.bar_control
            M.controls["shared_test_aura:" .. row.category] = slot.test_control
            M.controls["shared_test_aura:" .. row.category .. ":pause"] = slot.test_button
            slot.frame:Show()
        else
            slot.frame:Hide()
        end
    end
    rows_parent:SetHeight(math.max(1, #rows * 30))
    if M.sync_test_aura_controls then M.sync_test_aura_controls() end
end

local function get_frame_test_control_keys(category)
    if M.FRAME_DEFS_BY_KEY and M.FRAME_DEFS_BY_KEY[category] then
        local test_key = "test_aura_" .. category
        return test_key, test_key .. "_pause", "show_" .. category
    end
    local prefix = "custom_" .. tostring(category) .. "_"
    return prefix .. "test_aura", prefix .. "test_aura_pause", prefix .. "show"
end

function M.sync_test_aura_controls(category)
    for _, slot in ipairs(M.background_color_row_slots or {}) do
        if slot.category and (category == nil or slot.category == category) then
            local value_table, test_key, show_storage_key, show_key = M.get_test_aura_binding(slot.category)
            local enabled = value_table and value_table[test_key] == true
            slot.test_control:SetCheckedSilently(enabled)
            slot.test_button:SetEnabled(enabled)
            slot.test_button:SetPaused(M.is_test_preview_paused(show_key))

            local frame_test_key, frame_pause_key, frame_show_key = get_frame_test_control_keys(slot.category)
            local frame_test_control = M.controls[frame_test_key]
            if frame_test_control and frame_test_control.SetCheckedSilently then
                frame_test_control:SetCheckedSilently(enabled)
            end
            local frame_pause_control = M.controls[frame_pause_key]
            if frame_pause_control then
                frame_pause_control:SetEnabled(enabled)
                frame_pause_control:SetPaused(M.is_test_preview_paused(show_key))
            end
            if enabled then
                local frame_show_control = M.controls[frame_show_key]
                if frame_show_control and frame_show_control.SetCheckedSilently then
                    frame_show_control:SetCheckedSilently(value_table[show_storage_key] == true)
                end
            end
        end
    end
end

function M.sync_background_color_controls()
    local color_sync = get_background_color_sync()
    if not (color_sync and M.controls and M.db) then return end

    local frame_preset = M.controls.background_color_sync_frame_preset
    if frame_preset and frame_preset.SetValue and color_sync.get_color_preset then
        frame_preset:SetValue(color_sync.get_color_preset(M.db.shared_frame_background_color))
    end
    local frame_picker = M.controls.background_color_sync_frame_picker
    if frame_picker and frame_picker.SetValue then frame_picker:SetValue(M.db.shared_frame_background_color) end
    local bar_preset = M.controls.background_color_sync_bar_preset
    if bar_preset and bar_preset.SetValue and color_sync.get_color_preset then
        bar_preset:SetValue(color_sync.get_color_preset(M.db.shared_bar_background_color))
    end
    local bar_picker = M.controls.background_color_sync_bar_picker
    if bar_picker and bar_picker.SetValue then bar_picker:SetValue(M.db.shared_bar_background_color) end
    local enabled_control = M.controls.background_color_sync_enabled
    if enabled_control and enabled_control.SetCheckedSilently then
        enabled_control:SetCheckedSilently(M.db.shared_background_color_enabled == true)
    end
    local fade_control = M.controls.background_color_sync_disable_ooc_fade
    if fade_control and fade_control.SetCheckedSilently then
        fade_control:SetCheckedSilently(color_sync.get_disable_ooc_fade())
    end

    local global_active = color_sync.is_global_color_active
        and color_sync.is_global_color_active(M.MODULE_KEY)
    local shared_enabled = M.db.shared_background_color_enabled == true
    local module_controls_enabled = not global_active
    local shared_controls_enabled = shared_enabled and module_controls_enabled
    if enabled_control then enabled_control:SetEnabled(module_controls_enabled) end
    if frame_preset then frame_preset:SetEnabled(shared_controls_enabled) end
    if frame_picker then frame_picker:SetEnabled(shared_controls_enabled) end
    if bar_preset then bar_preset:SetEnabled(shared_controls_enabled) end
    if bar_picker then bar_picker:SetEnabled(shared_controls_enabled) end
    if fade_control then fade_control:SetEnabled(true) end
    if M.background_color_matrix_group then M.background_color_matrix_group:SetAlpha(1) end

    for _, slot in ipairs(M.background_color_row_slots or {}) do
        if slot.category then
            slot.frame_control:SetCheckedSilently(M.get_background_color_sync_enabled(slot.category, "frame"))
            slot.bar_control:SetCheckedSilently(M.get_background_color_sync_enabled(slot.category, "bar"))
            slot.frame_control:SetEnabled(shared_controls_enabled)
            slot.bar_control:SetEnabled(shared_controls_enabled)
        end
    end
end

function M.rebuild_shared_background_color_group()
    refresh_participation_rows()
    M.sync_background_color_controls()
end

--#endregion SHARED COLOR STATE ================================================


--#region TAB BUILDER ==========================================================

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
        M.db.shared_background_color_enabled == true,
        function(is_checked)
            M.db.shared_background_color_enabled = is_checked == true
            M.sync_background_color_controls()
            refresh_background_color_sync()
        end
    )
    grid:place_at(enabled_control, 1, 1)
    M.controls.background_color_sync_enabled = enabled_control

    local fade_control = addon.CreateCheckbox(
        content,
        "Disable OOC Fade",
        color_sync.get_disable_ooc_fade(),
        function(is_checked)
            if color_sync.set_disable_ooc_fade(is_checked) then
                refresh_background_color_sync()
            end
        end
    )
    grid:place_at(fade_control, 1, 2)
    M.controls.background_color_sync_disable_ooc_fade = fade_control

    return content, content_height
end

local function attach_slot_tooltip(slot, control, target_type)
    control.checkbox:SetScript("OnEnter", function(self)
        if not slot.display_label then return end
        local target_label = target_type == "frame" and "frame background" or "bar background"
        addon.ShowOwnedTooltip(self, "Apply the shared " .. target_label .. " color to "
            .. slot.display_label .. ".", nil)
    end)
    control.checkbox:SetScript("OnLeave", function()
        addon.HideOwnedTooltip()
    end)
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

    local frame_control = addon.CreateCheckbox(frame, "", false, function(is_checked)
        if slot.category and M.set_background_color_sync_enabled(slot.category, "frame", is_checked) then
            refresh_background_color_sync()
        end
    end)
    slot_grid:place_at(frame_control, 1, 2)
    slot.frame_control = frame_control

    local bar_control = addon.CreateCheckbox(frame, "", false, function(is_checked)
        if slot.category and M.set_background_color_sync_enabled(slot.category, "bar", is_checked) then
            refresh_background_color_sync()
        end
    end)
    slot_grid:place_at(bar_control, 1, 3)
    slot.bar_control = bar_control

    local test_group = CreateFrame("Frame", nil, frame)
    test_group:SetSize(68, 30)
    slot_grid:place_at(test_group, 1, 4)
    local test_grid = addon.CreateSettingsGrid(test_group, {
        column_count = 2,
        col_width = 24,
        col_gap = 36,
        col_offset = 0,
        col_align = { "center", "center" },
        row_start = 0,
        row_heights = { 30 },
        row_gap = 0,
        content_rows = 1,
    })
    local test_control = addon.CreateCheckbox(test_group, "", false, function(is_checked)
        if slot.category then M.set_test_aura_enabled(slot.category, is_checked) end
    end)
    test_grid:place_at(test_control, 1, 1)
    slot.test_control = test_control

    local test_button = addon.CreatePlayPauseButton(test_group, function()
        if slot.category then M.toggle_test_aura_preview(slot.category) end
    end, { width = 28, height = 28 })
    test_grid:place_at(test_button, 1, 2)
    slot.test_button = test_button

    attach_slot_tooltip(slot, frame_control, "frame")
    attach_slot_tooltip(slot, bar_control, "bar")
    return slot
end

local function build_shared_color_column(panel, header_grid, color_sync, title_text, target_type, column, db_key)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetText(title_text)
    header_grid:place_at(title, 1, column, nil, { y_offset = HEADER_TITLE_Y_OFFSET })

    local preset_control = addon.CreateCyclingDropdown(
        addon_name .. (target_type == "frame" and "AuraSharedFrameBackgroundPreset"
            or "AuraSharedBarBackgroundPreset"),
        panel,
        "Preset",
        color_sync.PRESET_OPTIONS,
        {
            fit_to_options = true,
            get_value = function()
                return color_sync.get_color_preset(M.db[db_key])
            end,
            get_unknown_text = function() return "Custom" end,
            on_select = function(value)
                local preset = color_sync.COLOR_PRESETS[value]
                if not preset then return end
                local current = M.db[db_key] or M.defaults[db_key]
                M.db[db_key] = {
                    r = preset.r,
                    g = preset.g,
                    b = preset.b,
                    a = current.a,
                }
                refresh_background_color_sync()
            end,
        }
    )
    header_grid:place_at(preset_control, 1, column, nil, { y_offset = -28 })
    M.controls["background_color_sync_" .. target_type .. "_preset"] = preset_control

    local picker_control = addon.CreateColorPicker(
        panel,
        M.db,
        db_key,
        true,
        "Custom",
        M.defaults,
        function(reason)
            if reason ~= "open" then refresh_background_color_sync() end
        end
    )
    header_grid:place_at(picker_control, 1, column, "picker", { y_offset = -72 })
    M.controls["background_color_sync_" .. target_type .. "_picker"] = picker_control
end

local function build_participation_matrix(content, content_height, color_sync)
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
    header_grid:place_at(header_bar, 1, 1)

    local name_header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name_header:SetText("Frame Name")
    header_grid:place_at(name_header, 1, 1, nil, { y_offset = HEADER_TITLE_Y_OFFSET })
    build_shared_color_column(
        panel,
        header_grid,
        color_sync,
        "Frame BG Color",
        "frame",
        2,
        "shared_frame_background_color"
    )
    build_shared_color_column(
        panel,
        header_grid,
        color_sync,
        "Bar BG Color",
        "bar",
        3,
        "shared_bar_background_color"
    )
    local test_header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    test_header:SetText("Test Aura")
    header_grid:place_at(test_header, 1, 4, nil, { y_offset = HEADER_TITLE_Y_OFFSET })

    local rows_parent = CreateFrame("Frame", nil, panel)
    rows_parent:SetSize(GROUP_WIDTH - 50, 1)
    rows_parent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -133)
    M.background_color_rows_parent = rows_parent
    M.background_color_row_slots = {}

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
        M.background_color_row_slots[index] = create_participation_slot(rows_parent, row_grid, index)
    end
    refresh_participation_rows()
    return panel
end

function M.build_shared_bg_colors_tab(parent)
    local color_sync = get_background_color_sync()
    if not (color_sync and color_sync.get_color_preset and M.db) then return end
    M.shared_background_color_parent = parent
    local content, content_height = build_color_controls(parent, color_sync)
    M.shared_background_color_group = content
    M.background_color_matrix_group = build_participation_matrix(content, content_height, color_sync)
    M.sync_background_color_controls()
end

--#endregion TAB BUILDER =======================================================
