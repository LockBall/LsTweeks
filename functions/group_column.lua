-- Grouped selector column factory based on the Aura Frames settings tree structure.
-- Provides thin bordered group boxes, centered group titles, selected-group borders, selectable rows, delete rows, and group actions.


local addon_name, addon = ...

--#region GROUP COLUMN CONSTANTS =============================================

local DEFAULTS = {
    width = 140,
    height = 100,
    pad = 10,
    row_height = 15,
    group_box_inset = 8,
    group_inner_pad = 6,
    group_element_gap = 1,
    group_title_height = 12,
    group_gap = 10,
    selected_color = { 1, 0.82, 0, 1 },
    normal_color = { 1, 1, 1, 1 },
    hover_color = { 1, 1, 0.6, 1 },
    selected_fill = { 0.75, 0.75, 0.75, 0.18 },
    panel_bg = { 0.08, 0.08, 0.08, 0.9 },
    panel_border = { 0.4, 0.4, 0.4, 0.8 },
    inactive_border = { 0.5, 0.5, 0.5, 0.45 },
    active_border = { 1, 0.82, 0, 0.75 },
}

--#endregion GROUP COLUMN CONSTANTS ==========================================


--#region GROUP COLUMN HELPERS ===============================================

local function color_values(value, fallback)
    value = value or fallback
    return value[1], value[2], value[3], value[4]
end

local function apply_thin_border_backdrop(frame, bg_color, border_color)
    frame:SetBackdrop({
        bgFile = bg_color and "Interface\\Buttons\\WHITE8x8" or nil,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 8,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    if bg_color then
        frame:SetBackdropColor(color_values(bg_color, DEFAULTS.panel_bg))
    end
    if border_color then
        frame:SetBackdropBorderColor(color_values(border_color, DEFAULTS.panel_border))
    end
end

local function set_text_color(font_string, color)
    font_string:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function apply_label_outline(font_string)
    local font_path, font_size = font_string:GetFont()
    font_string:SetFont(font_path or STANDARD_TEXT_FONT, font_size or 11, "OUTLINE")
end

--#endregion GROUP COLUMN HELPERS ============================================


--#region GROUP COLUMN FACTORY ===============================================

function addon.CreateGroupColumn(parent, opts)
    opts = opts or {}
    local width = opts.width or DEFAULTS.width
    local row_height = opts.row_height or DEFAULTS.row_height
    local pad = opts.pad or DEFAULTS.pad
    local group_box_inset = opts.group_box_inset or (pad - 2)
    local group_inner_pad = opts.group_inner_pad or DEFAULTS.group_inner_pad
    local group_element_gap = opts.group_element_gap or DEFAULTS.group_element_gap
    local group_title_height = opts.group_title_height or DEFAULTS.group_title_height
    local group_gap = opts.group_gap or DEFAULTS.group_gap
    local selected_color = opts.selected_color or DEFAULTS.selected_color
    local normal_color = opts.normal_color or DEFAULTS.normal_color
    local hover_color = opts.hover_color or DEFAULTS.hover_color

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, opts.height or DEFAULTS.height)
    apply_thin_border_backdrop(
        frame,
        opts.panel_bg or DEFAULTS.panel_bg,
        opts.panel_border or DEFAULTS.panel_border
    )

    local entries = {}
    local rows = {}
    local group_boxes = {}
    local group_titles = {}
    local group_actions = {}
    local selected_key = opts.selected_key

    local selected_row
    local selected_highlight = frame:CreateTexture(nil, "BACKGROUND")
    selected_highlight:SetColorTexture(color_values(opts.selected_fill, DEFAULTS.selected_fill))
    selected_highlight:Hide()

    local function set_active_group(group_key)
        for key, box in pairs(group_boxes) do
            if key == group_key then
                box:SetBackdropBorderColor(color_values(opts.active_border, DEFAULTS.active_border))
            else
                box:SetBackdropBorderColor(color_values(opts.inactive_border, DEFAULTS.inactive_border))
            end
        end
    end

    local function find_entry(key)
        for _, entry in ipairs(entries) do
            if not entry.header and entry.key == key then return entry end
        end
        return nil
    end

    local function refresh_selection()
        local selected_entry = find_entry(selected_key)
        selected_row = nil
        for _, row in ipairs(rows) do
            if row.entry_key then
                local selected = row.entry_key == selected_key
                set_text_color(row.text, selected and selected_color or normal_color)
                if selected then
                    selected_row = row
                end
            end
        end
        if selected_row then
            selected_highlight:ClearAllPoints()
            selected_highlight:SetPoint("TOPLEFT", selected_row, "TOPLEFT", 0, 0)
            selected_highlight:SetPoint("BOTTOMRIGHT", selected_row, "BOTTOMRIGHT", 0, 0)
            selected_highlight:Show()
        else
            selected_highlight:Hide()
        end
        set_active_group(selected_entry and selected_entry.group)
    end

    local function hide_rows()
        for _, row in ipairs(rows) do
            row:Hide()
        end
        rows = {}
    end

    local function hide_group_chrome()
        for _, box in pairs(group_boxes) do
            box:Hide()
        end
        for _, title in pairs(group_titles) do
            title:Hide()
        end
        for _, action in pairs(group_actions) do
            if action.button then action.button:Hide() end
        end
    end

    local function acquire_group_box(group_key)
        local box = group_boxes[group_key]
        if box then return box end
        box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        box:SetFrameLevel(frame:GetFrameLevel() + 1)
        box:EnableMouse(false)
        apply_thin_border_backdrop(box, nil, opts.inactive_border or DEFAULTS.inactive_border)
        group_boxes[group_key] = box
        return box
    end

    local function acquire_group_title(group_key)
        local title = group_titles[group_key]
        if title then return title end
        title = frame:CreateFontString(nil, "OVERLAY", opts.group_title_font or "GameFontNormalSmall")
        title:SetJustifyH("CENTER")
        title:SetSize(width - ((group_box_inset + group_inner_pad) * 2), group_title_height)
        group_titles[group_key] = title
        return title
    end

    local function build_groups()
        local groups = {}
        local current_group
        for _, entry in ipairs(entries) do
            if entry.header then
                current_group = {
                    key = entry.group or ("group_" .. (#groups + 1)),
                    title = entry.label,
                    entries = {},
                }
                groups[#groups + 1] = current_group
            elseif current_group then
                current_group.entries[#current_group.entries + 1] = entry
            else
                current_group = {
                    key = entry.group or "_default",
                    title = entry.group_title or "",
                    entries = { entry },
                }
                groups[#groups + 1] = current_group
            end
        end
        return groups
    end

    local function create_row(entry, y)
        local row = CreateFrame("Button", nil, frame)
        local row_x = opts.row_x or pad
        local row_width = opts.row_width or (width - (pad * 2))
        row:SetSize(row_width, row_height)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", row_x, y)
        row:SetFrameLevel(frame:GetFrameLevel() + 3)
        row.entry_key = entry.key

        row.text = row:CreateFontString(nil, "OVERLAY", opts.row_font or "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", opts.row_text_x or 4, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", entry.deletable and -24 or -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetText(entry.label or "")
        set_text_color(row.text, normal_color)
        apply_label_outline(row.text)

        row:SetScript("OnClick", function()
            frame:Select(entry.key)
        end)
        row:SetScript("OnEnter", function()
            if row.entry_key ~= selected_key then
                set_text_color(row.text, hover_color)
            end
            if row.delete_button then row.delete_button:SetAlpha(1) end
        end)
        row:SetScript("OnLeave", function()
            if row.entry_key ~= selected_key then
                set_text_color(row.text, normal_color)
            end
            if row.delete_button then row.delete_button:SetAlpha(0) end
        end)

        if entry.deletable and type(opts.on_delete) == "function" then
            local delete_button = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            delete_button:SetSize(16, 16)
            delete_button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            delete_button:SetAlpha(0)
            delete_button:SetScript("OnEnter", function()
                delete_button:SetAlpha(1)
            end)
            delete_button:SetScript("OnLeave", function()
                delete_button:SetAlpha(0)
            end)
            delete_button:SetScript("OnClick", function()
                opts.on_delete(entry)
            end)
            row.delete_button = delete_button
        end

        rows[#rows + 1] = row
        return row
    end

    local function render()
        hide_rows()
        hide_group_chrome()

        local y = -pad
        for _, group in ipairs(build_groups()) do
            local group_key = group.key
            local group_top_y = y
            local box = acquire_group_box(group_key)
            local title = acquire_group_title(group_key)

            y = y - group_inner_pad
            title:ClearAllPoints()
            title:SetPoint("TOP", frame, "TOPLEFT", width / 2, y)
            title:SetText(group.title or "")
            title:Show()

            y = y - (group_title_height + group_element_gap)

            local action = group_actions[group_key]
            if action and action.position ~= "bottom" then
                action.button:ClearAllPoints()
                action.button:SetPoint("TOPLEFT", frame, "TOPLEFT", action.x or pad, y)
                action.button:Show()
                y = y - ((action.height or row_height) + group_element_gap)
            end

            for _, entry in ipairs(group.entries) do
                create_row(entry, y)
                y = y - (row_height + group_element_gap)
            end

            if action and action.position == "bottom" then
                action.button:ClearAllPoints()
                action.button:SetPoint("TOPLEFT", frame, "TOPLEFT", action.x or pad, y)
                action.button:Show()
                y = y - ((action.height or row_height) + group_element_gap)
            end

            local group_bottom_y = y
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", frame, "TOPLEFT", group_box_inset, group_top_y)
            box:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", width - group_box_inset, group_bottom_y - group_inner_pad)
            box:Show()

            y = group_bottom_y - (group_gap + group_inner_pad)
        end

        refresh_selection()
    end

    function frame:SetEntries(new_entries)
        entries = new_entries or {}
        render()
    end

    function frame:GetEntries()
        return entries
    end

    function frame:GetSelectedKey()
        return selected_key
    end

    function frame:GetSelectedEntry()
        return find_entry(selected_key)
    end

    function frame:Select(key, suppress_callback)
        local entry = find_entry(key)
        if not entry then return false end
        selected_key = key
        refresh_selection()
        if not suppress_callback and type(opts.on_select) == "function" then
            opts.on_select(entry)
        end
        return true
    end

    function frame:SetGroupAction(group_key, label, on_click, action_opts)
        action_opts = action_opts or {}
        local action = group_actions[group_key]
        if not action then
            action = {}
            action.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            action.button:SetFrameLevel(frame:GetFrameLevel() + 3)
            if addon.ApplyStandardButtonStyle then
                addon.ApplyStandardButtonStyle(action.button)
            end
            group_actions[group_key] = action
        end
        action.width = action_opts.width or (width - (pad * 2))
        action.height = action_opts.height or row_height
        action.x = action_opts.x or pad
        action.position = action_opts.position or "top"
        action.button:SetSize(action.width, action.height)
        action.button:SetText(label or "")
        action.button:SetScript("OnClick", on_click)
        if #entries > 0 then
            render()
        end
        return action.button
    end

    function frame:SetFooterButton(label, on_click, footer_opts)
        return frame:SetGroupAction((footer_opts and footer_opts.group_key) or "_footer", label, on_click, footer_opts)
    end

    return frame
end

--#endregion GROUP COLUMN FACTORY ============================================
