-- Settings panels for custom filtered aura frames.
-- Provides M.build_custom_settings_panel(p, entry) for presentation controls and
-- M.build_custom_child_panel(p, entry) for the HELPFUL/HARMFUL + modifier filters.

local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local function update_custom_frame(entry)
    if not (entry and entry.id and M.frames) then return end
    local show_key = "show_" .. entry.id
    local frame = M.frames[show_key]
    if not frame then return end
    local filter = M.get_custom_aura_filter and M.get_custom_aura_filter(entry) or entry.aura_base_filter or "HELPFUL"
    frame.update_params.filter = filter
    M.update_auras(frame, show_key, "move", "timer", "bg", "scale", "spacing", filter)
end

local function update_custom_frame_title(entry)
    if not (entry and entry.id and M.frames) then return end
    local frame = M.frames["show_" .. entry.id]
    if not frame then return end
    if frame.title_bar and frame.title_bar.label_text then
        frame.title_bar.label_text:SetText(entry.name or entry.id)
    end
    if frame.bottom_title_bar and frame.bottom_title_bar.label_text then
        frame.bottom_title_bar.label_text:SetText(entry.name or entry.id)
    end
end

function M.build_custom_settings_panel(p, entry)
    local id = entry.id
    local show_key = "show_" .. id

    local function update()
        update_custom_frame(entry)
    end

    local col_gap    = 150
    local col_width  = 190
    local col_offset = -20
    local row_gap    = 20
    local grid = {
        [1] = col_offset,
        [2] = col_gap + col_offset,
        [3] = col_gap * 2 + col_offset,
        [4] = col_gap * 3 + col_offset,
        col_width   = col_width,
        col_align   = { "center", "center", "center", "center" },
        row_start   = 10,
        row_gap     = row_gap,
        row_heights = { 130, 60, 90, 120, 110 },
        reset_btn_width = 110,
        offsets     = { default = 0, dropdown = 8, picker = 4 },
    }

    local function place_at(control, row, column, slot, opts)
        if not control then return end
        opts = opts or {}
        local align = opts.align or grid.col_align[column] or "left"
        local x = grid[column]
        local y = grid.row_start
        for i = 1, (row - 1) do
            y = y - (grid.row_heights[i] or grid.row_heights[#grid.row_heights])
        end
        if opts.valign == "bottom" then
            y = y - (grid.row_heights[row] or grid.row_heights[#grid.row_heights])
        end
        local y_offset = grid.offsets[slot or "default"] or 0
        if opts.y_offset then y_offset = y_offset + opts.y_offset end
        local width = opts.width or (control.GetWidth and control:GetWidth() or 0)
        if align == "center" then
            x = x + math.floor((grid.col_width - width) / 2)
        elseif align == "right" then
            x = x + grid.col_width - width
        end
        control:SetPoint("TOPLEFT", p, "TOPLEFT", x, y + y_offset)
    end

    local function add_row_separator(row)
        local line = p:CreateTexture(nil, "BACKGROUND")
        line:SetColorTexture(1, 1, 1, 0.08)
        line:SetHeight(2)
        local y = grid.row_start
        for i = 1, row do y = y - (grid.row_heights[i] or grid.row_heights[#grid.row_heights]) end
        line:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y + math.floor(grid.row_gap / 2))
        line:SetWidth(grid[4] + grid.col_width - 12)
    end

    local function bound_cb(label, key, row, column, on_change)
        local container, cb = addon.CreateCheckbox(p, label, entry[key],
            function(is_checked)
                entry[key] = is_checked
                if on_change then on_change(is_checked) else update() end
            end
        )
        place_at(container, row, column)
        M.controls["custom_" .. id .. "_" .. key] = cb
        return container, cb
    end

    local function bound_picker(key, has_alpha, label, row, column)
        local picker = addon.CreateColorPicker(p, entry, key, has_alpha, label, M.CUSTOM_FRAME_TEMPLATE, update)
        place_at(picker, row, column, "picker")
        return picker
    end

    local pos = entry.position or { x = 0, y = 50 }
    entry.position = pos

    local function update_frame_position()
        local f = M.frames[show_key]
        if f and pos then
            if M.apply_frame_position then
                M.apply_frame_position(f, pos)
            else
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", UIParent, "CENTER", pos.x or 0, pos.y or 0)
            end
        end
    end

    local move_container, move_cb = bound_cb("Move Mode", "move", 1, 1, function(is_checked)
        if is_checked then
            local en_cb = M.controls["custom_" .. id .. "_show"]
            if en_cb and en_cb.SetChecked and not en_cb:GetChecked() then
                en_cb:SetChecked(true)
                entry.show = true
            end
        end
        update()
    end)

    local x_slider = addon.CreateSliderWithBox(addon_name..id.."XPos", p, "X Position", -1000, 1000, 1, pos, "x", { x = 0 })
    x_slider.slider:HookScript("OnValueChanged", update_frame_position)
    place_at(x_slider, 1, 2)

    local y_slider = addon.CreateSliderWithBox(addon_name..id.."YPos", p, "Y Position", -1000, 1000, 1, pos, "y", { y = 50 })
    y_slider.slider:HookScript("OnValueChanged", update_frame_position)
    place_at(y_slider, 1, 3)

    local width_slider = addon.CreateSliderWithBox(addon_name..id.."Width", p, "Width", 180, 800, 1, entry, "width", M.CUSTOM_FRAME_TEMPLATE)
    width_slider.slider:HookScript("OnValueChanged", function(_, value)
        local f = M.frames[show_key]
        if f then
            f:SetWidth(math.floor(value + 0.5))
            update()
        end
    end)
    M.controls["custom_" .. id .. "_width"] = width_slider
    place_at(width_slider, 1, 4)

    local snap_container = addon.CreateCheckbox(p, "Snap to Grid", M.db.snap_to_grid == true,
        function(is_checked) M.db.snap_to_grid = is_checked end)
    snap_container:SetPoint("TOPLEFT", move_container, "BOTTOMLEFT", 0, -4)

    local show_grid_container = addon.CreateCheckbox(p, "Show Grid", M.db.show_grid == true,
        function(is_checked)
            M.db.show_grid = is_checked
            if M.set_grid_visible then M.set_grid_visible(is_checked) end
        end)
    show_grid_container:SetPoint("TOPLEFT", snap_container, "BOTTOMLEFT", 0, -4)

    local move_reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    move_reset:SetSize(grid.reset_btn_width, 22)
    move_reset:SetPoint("TOPLEFT", show_grid_container, "BOTTOMLEFT", 0, -6)
    move_reset:SetText("Move Reset")
    move_reset:SetScript("OnClick", function()
        local tmpl = M.CUSTOM_FRAME_TEMPLATE
        pos.x = tmpl.position.x
        pos.y = tmpl.position.y
        entry.move = tmpl.move
        entry.width = tmpl.width
        move_cb:SetChecked(false)
        local f = M.frames[show_key]
        if f then
            if M.apply_frame_position then
                M.apply_frame_position(f, pos)
            else
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", UIParent, "CENTER", pos.x, pos.y)
            end
            f:SetWidth(entry.width)
            update()
        end
        if x_slider and x_slider.slider then x_slider.slider:SetValue(pos.x) end
        if y_slider and y_slider.slider then y_slider.slider:SetValue(pos.y) end
        if width_slider and width_slider.slider then width_slider.slider:SetValue(entry.width) end
    end)

    add_row_separator(1)

    local enable_container, enable_cb = bound_cb("Enable Frame", "show", 2, 1, function(is_checked)
        if not is_checked then
            entry.test_aura = false
            local ta_cb = M.controls["custom_" .. id .. "_test_aura"]
            if ta_cb and ta_cb.SetChecked then ta_cb:SetChecked(false) end
        end
        update()
    end)

    local test_aura_container = bound_cb("Test Aura", "test_aura", 2, 1, function(is_checked)
        if is_checked then
            entry.show = true
            if enable_cb and enable_cb.SetChecked then enable_cb:SetChecked(true) end
        end
        update()
    end)
    test_aura_container:ClearAllPoints()
    test_aura_container:SetPoint("TOPLEFT", enable_container, "BOTTOMLEFT", 0, 0)

    bound_cb("Frame BG", "bg", 2, 2)
    bound_picker("bg_color", true, "Frame BG Color", 2, 3)

    local name_container = CreateFrame("Frame", nil, p)
    name_container:SetSize(130, 24)
    local name_label = name_container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name_label:SetPoint("BOTTOM", name_container, "TOP", 0, 2)
    name_label:SetText("Frame Name")
    local name_box = CreateFrame("EditBox", nil, name_container, "InputBoxTemplate")
    name_box:SetSize(130, 22)
    name_box:SetPoint("TOP", name_container, "TOP", 0, 0)
    name_box:SetAutoFocus(false)
    name_box:SetMaxLetters(32)
    name_box:SetText(entry.name or id)
    local function commit_name()
        local new_name = (name_box:GetText() or ""):match("^%s*(.-)%s*$")
        if not new_name or new_name == "" then
            name_box:SetText(entry.name or id)
            name_box:ClearFocus()
            return
        end
        if new_name ~= entry.name then
            entry.name = new_name
            update_custom_frame_title(entry)
            if M.on_custom_frame_renamed then M.on_custom_frame_renamed(id, new_name) end
        end
        name_box:ClearFocus()
    end
    name_box:SetScript("OnEnterPressed", commit_name)
    name_box:SetScript("OnEditFocusLost", commit_name)
    place_at(name_container, 2, 4, nil, { width = 130 })
    add_row_separator(2)

    local bar_mode_container = bound_cb("Bar Mode", "bar_mode", 3, 1)
    local bar_color_picker = addon.CreateColorPicker(p, entry, "color", true, "Bar Color", M.CUSTOM_FRAME_TEMPLATE, update)
    bar_color_picker:SetPoint("TOPLEFT", bar_mode_container, "BOTTOMLEFT", 0, -4)
    M.controls["custom_" .. id .. "_bar_color"] = bar_color_picker
    bound_picker("bar_text_color", false, "Bar Text Color", 3, 2)
    bound_picker("bar_bg_color", true, "Bar BG Color", 3, 3)

    local dir_options = {}
    for _, dir in ipairs({ "RIGHT", "LEFT", "DOWN", "UP" }) do
        dir_options[#dir_options + 1] = { value = dir, text = dir }
    end
    local growth_dd = addon.CreateDropdown(addon_name..id.."Growth", p, "Growth Direction", dir_options, {
        width = 106,
        get_value = function() return entry.growth or "DOWN" end,
        on_select = function(value) entry.growth = value; update() end,
    })
    place_at(growth_dd, 3, 4, "dropdown", { y_offset = -math.floor((grid.row_heights[3] - 24) / 2) })
    add_row_separator(3)

    local timer_text_container = bound_cb("Timer Text", "timer", 4, 1)
    local timer_bold_container = bound_cb("Timer Bold", "timer_number_font_bold", 4, 1, function()
        if M.apply_number_font_to_all then M.apply_number_font_to_all() end
        update()
    end)
    timer_bold_container:ClearAllPoints()
    timer_bold_container:SetPoint("TOPLEFT", timer_text_container, "BOTTOMLEFT", 0, -4)

    local font_options = {}
    for _, def in ipairs(M.get_number_font_options and M.get_number_font_options() or {}) do
        font_options[#font_options + 1] = {
            value = def.key, text = def.label,
            font_path = def.path, font_size = def.size, font_flags = def.flags,
        }
    end
    local timer_font_dd = M.CreateListDropdown(addon_name..id.."TimerFont", p, "Timer Font", font_options,
        function() return entry.timer_number_font or "source_code_pro" end,
        function(value)
            entry.timer_number_font = value
            if M.apply_number_font_to_all then M.apply_number_font_to_all() end
            update()
        end, 120)
    place_at(timer_font_dd, 4, 2, nil, { width = 120, y_offset = -15 })

    local font_size_slider = addon.CreateSliderWithBox(addon_name..id.."TimerFontSize", p, "Timer Font Size",
        8, 14, 0.5, entry, "timer_number_font_size", M.CUSTOM_FRAME_TEMPLATE,
        function()
            if M.apply_number_font_to_all then M.apply_number_font_to_all() end
            update()
        end)
    place_at(font_size_slider, 4, 3)

    local timer_color_picker = addon.CreateColorPicker(p, entry, "timer_color", false, "Timer Color", M.CUSTOM_FRAME_TEMPLATE, function()
        if M.apply_number_font_to_all then M.apply_number_font_to_all() end
        update()
    end)
    timer_color_picker:SetPoint("TOPLEFT", timer_bold_container, "BOTTOMLEFT", 0, -4)
    add_row_separator(4)

    local scale_slider = addon.CreateSliderWithBox(addon_name..id.."Scale", p, "Scale",
        0.5, 2.5, 0.01, entry, "scale", M.CUSTOM_FRAME_TEMPLATE, update)
    place_at(scale_slider, 5, 1)

    local spacing_slider = addon.CreateSliderWithBox(addon_name..id.."Spacing", p, "Spacing",
        0, 20, 0.1, entry, "spacing", M.CUSTOM_FRAME_TEMPLATE, update)
    place_at(spacing_slider, 5, 2)

    local max_icons_slider = addon.CreateSliderWithBox(addon_name..id.."MaxIcons", p, "Max Icons",
        5, 40, 1, entry, "max_icons", M.CUSTOM_FRAME_TEMPLATE,
        function()
            print("|cFFFFFF00LsTweaks:|r Pool size for " .. (entry.name or id) .. " changed. Please /reload to apply.")
        end)
    place_at(max_icons_slider, 5, 4)
end

function M.build_custom_child_panel(p, entry)
    local id = entry and entry.id
    if not id then return end

    local header = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -18)
    header:SetText((entry.name or id) .. " Filters")

    local base_dd
    local modifier_dd

    local function set_base(value)
        entry.aura_base_filter = (value == "HARMFUL") and "HARMFUL" or "HELPFUL"
        if base_dd and base_dd.SetValue then base_dd:SetValue(entry.aura_base_filter) end
    end

    local function set_modifier(value)
        entry.aura_modifier = value or "NONE"
        local def = M.get_custom_modifier_def and M.get_custom_modifier_def(entry.aura_modifier)
        if def and def.force_base then set_base(def.force_base) end
        if modifier_dd and modifier_dd.SetValue then modifier_dd:SetValue(entry.aura_modifier) end
    end

    entry.aura_base_filter = (entry.aura_base_filter == "HARMFUL") and "HARMFUL" or "HELPFUL"
    entry.aura_modifier = entry.aura_modifier or "NONE"
    set_modifier(entry.aura_modifier)

    base_dd = addon.CreateDropdown(addon_name..id.."AuraBase", p, "Base", M.CUSTOM_AURA_BASE_FILTERS, {
        width = 118,
        get_value = function() return entry.aura_base_filter or "HELPFUL" end,
        on_select = function(value)
            set_base(value)
            local def = M.get_custom_modifier_def and M.get_custom_modifier_def(entry.aura_modifier)
            if def and def.force_base and def.force_base ~= entry.aura_base_filter then
                set_base(def.force_base)
            end
            update_custom_frame(entry)
        end,
    })
    base_dd:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -32)

    local pipe = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pipe:SetPoint("LEFT", base_dd, "RIGHT", 10, 0)
    pipe:SetText("|")

    modifier_dd = addon.CreateDropdown(addon_name..id.."AuraModifier", p, "Modifier", M.CUSTOM_AURA_MODIFIERS, {
        width = 185,
        get_value = function() return entry.aura_modifier or "NONE" end,
        on_select = function(value)
            set_modifier(value)
            update_custom_frame(entry)
        end,
    })
    modifier_dd:SetPoint("LEFT", pipe, "RIGHT", 10, 0)
end
