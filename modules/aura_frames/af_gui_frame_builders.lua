-- Content panel builders for Aura Frames settings.
-- Builds the General tab, Spell ID tab, and preset Buff/CDM frame settings panels.

local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local function get_timer_font_options()
    local options = {}
    local defs = M.get_number_font_options()
    for _, def in ipairs(defs) do
        options[#options + 1] = {
            value = def.key,
            text = def.label,
            font_path = def.path,
            font_size = def.size,
            font_flags = def.flags,
        }
    end
    return options
end

local function create_bound_checkbox_control(parent, label, value_table, value_key, grid, row, column, control_key, on_change, default_update, after_checked, after_unchecked)
    local container, checkbox, _ = addon.CreateCheckbox(parent, label, value_table[value_key],
        function(is_checked)
            value_table[value_key] = is_checked
            if is_checked and after_checked then
                after_checked()
            end
            if not is_checked and after_unchecked then
                after_unchecked()
            end
            if on_change then
                on_change(is_checked)
            elseif default_update then
                default_update()
            end
        end
    )
    grid.place_at(container, row, column)
    if control_key then
        M.controls[control_key] = checkbox
    end
    return container, checkbox
end

function M.build_aura_id_tab(p)
    local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    lbl:SetText("Show spell ID in icon tooltips.")

    local spell_id_container, spell_id_btn, _ = addon.CreateCheckbox(p, "Show Spell ID in Tooltip", M.db.show_spell_id == true,
        function(is_checked)
            M.db.show_spell_id = is_checked
        end
    )
    spell_id_container:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    M.controls.show_spell_id_checkbox = spell_id_btn
end

function M.build_general_tab(p)
    -- Manual layout for General tab

    -- Blizzard Buff & Debuff Enable Frames Section
    local enable_panel = CreateFrame("Frame", nil, p, "BackdropTemplate")
    enable_panel:SetSize(150, 45)
    enable_panel:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
    M.apply_tooltip_panel_backdrop(enable_panel, 0.08, 0.08, 0.08, 0.85, 0.3, 0.3, 0.3, 1)

    local panel_title = enable_panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel_title:SetText("Enable Blizz Frame")
    panel_title:SetPoint("TOP", enable_panel, "TOP", 0, -5)

    -- Blizzard Buff Frame Checkbox (checked = enabled)
    local enable_blizz_buffs_container, enable_blizz_buffs_cb, _ = addon.CreateCheckbox(enable_panel, "Buff", M.db.enable_blizz_buffs,
        function(is_checked)
            M.db.enable_blizz_buffs = is_checked
            M.toggle_blizz_buffs(not is_checked)
        end
    )
    enable_blizz_buffs_container:SetPoint("CENTER", enable_panel, "CENTER", -40, -5)
    M.controls["enable_blizz_buffs"] = enable_blizz_buffs_cb

    -- Blizzard Debuff Frame Checkbox (checked = enabled)
    local enable_blizz_debuffs_container, enable_blizz_debuffs_cb, _ = addon.CreateCheckbox(
        enable_panel,
        "Debuff",
        M.db.enable_blizz_debuffs,
        function(is_checked)
            M.db.enable_blizz_debuffs = is_checked
            M.toggle_blizz_debuffs(not is_checked)
        end
    )
    enable_blizz_debuffs_container:SetPoint("CENTER", enable_panel, "CENTER", 35, -5)
    M.controls["enable_blizz_debuffs"] = enable_blizz_debuffs_cb

    -- Short Buff Threshold slider
    local threshold = addon.CreateSliderWithBox(addon_name.."Tslider", p, "Short Buff Threshold", 10, 300, 10, M.db, "short_threshold", M.defaults, function()
        for k, v in pairs(M.frames) do
            local params = v.update_params
            if params then
                M.update_auras(v, params.show_key, params.move_key, params.timer_key, params.bg_key,
                    params.scale_key, params.spacing_key, params.aura_filter)
            end
        end
    end)
    threshold:SetPoint("TOPLEFT", enable_panel, "BOTTOMLEFT", 0, -24)


    -- Show Bar Section Outlines Checkbox
    local outlines_container, outlines_btn, _ = addon.CreateCheckbox(p, "Show Bar Section Outlines", M.db.show_bar_section_outlines == true,
        function(is_checked)
            M.db.show_bar_section_outlines = is_checked
            if addon.aura_frames and addon.aura_frames.refresh_section_outlines then
                addon.aura_frames.refresh_section_outlines()
            end
        end
    )
    outlines_container:SetPoint("TOPLEFT", threshold, "BOTTOMLEFT", 0, -18)
    M.controls.show_bar_section_outlines_checkbox = outlines_btn

    -- reset panel
    local resetPanel = addon.CreateGlobalReset(p, M.db, M.defaults)
    resetPanel:SetPoint("TOPLEFT", outlines_container, "BOTTOMLEFT", 0, -16)
end

-- ============================================================================
function M.build_preset_frame_panel(p, data)
    local cat = data.show_key:sub(6)
    local aura_filter = data.is_debuff and "HARMFUL" or "HELPFUL"
    local test_key = "test_aura_"..cat

    local function update() -- refreshes current category frame preview
        M.mark_aura_scan_dirty()
        M.update_auras(M.frames[data.show_key], data.show_key, data.move_key, data.timer_key, data.bg_key, data.scale_key, data.spacing_key, aura_filter)
    end

    local grid = M.create_settings_grid(p)
    local place_at = grid.place_at
    local add_row_separator = grid.add_row_separator

    local function create_bound_checkbox(label, db_key, row, column, on_change, control_key, extra_on_uncheck, extra_on_check)
        return create_bound_checkbox_control(p, label, M.db, db_key, grid, row, column, control_key or db_key, on_change, update, extra_on_check, extra_on_uncheck)
    end

    local function create_bound_color_picker(db_key, has_alpha, label, row, column)
        local picker = addon.CreateColorPicker(p, M.db, db_key, has_alpha, label, M.defaults, update)
        place_at(picker, row, column, "picker")
        return picker
    end

    local function create_bound_slider(name_suffix, label, min_v, max_v, step, db_key, on_change)
        local slider = addon.CreateSliderWithBox(addon_name..cat..name_suffix, p, label, min_v, max_v, step, M.db, db_key, M.defaults, on_change or update)
        return slider
    end

    -- Width slider — defined early so it can be placed in Row 1.
    local width_slider = addon.CreateSliderWithBox(
        addon_name..cat.."WidthSlider",
        p,
        "Width",
        M.MIN_FRAME_WIDTH, M.MAX_FRAME_WIDTH, 1,
        M.db, "width_"..cat, M.defaults
    )
    width_slider.slider:HookScript("OnValueChanged", function(_, value)
        local f = M.frames[data.show_key]
        if not f then return end
        f:SetWidth(math.floor(value + 0.5))
        update()
    end)
    M.controls["width_slider_"..cat] = width_slider

    -- X/Y Position sliders — defined early so Row 1 and move_reset can reference them.
    local function update_frame_position(axis, value)
        local f = M.frames[data.show_key]
        if f and value ~= nil then
            M.set_saved_frame_position_axis(f, axis, value, data.scale_key)
        end
    end

    local x_slider = addon.CreateSliderWithBox(
        addon_name..cat.."XPosSlider",
        p,
        "X Position",
        -1000, 1000, 1,
        M.db.positions[cat], "x", M.defaults.positions[cat]
    )
    x_slider.slider:HookScript("OnValueChanged", function(_, value)
        update_frame_position("x", value)
    end)
    M.controls["x_pos_slider_"..cat] = x_slider

    local y_slider = addon.CreateSliderWithBox(
        addon_name..cat.."YPosSlider",
        p,
        "Y Position",
        -1000, 1000, 1,
        M.db.positions[cat], "y", M.defaults.positions[cat]
    )
    y_slider.slider:HookScript("OnValueChanged", function(_, value)
        update_frame_position("y", value)
    end)
    M.controls["y_pos_slider_"..cat] = y_slider

    -- Row 1

    local function check_enable_frame()
        if not M.db[data.show_key] then
            M.db[data.show_key] = true
            local enable_cb = M.controls[data.show_key]
            if enable_cb and enable_cb.SetChecked then enable_cb:SetChecked(true) end
        end
    end

    -- move mode
    local move_mode_container, move_cb = create_bound_checkbox("Move Mode", data.move_key, 1, 1, function(is_checked)
        if is_checked then
            -- Also check Enable Frame if not already checked
            local enable_cb = M.controls and M.controls[data.show_key]
            if enable_cb and enable_cb.SetChecked and not enable_cb:GetChecked() then
                enable_cb:SetChecked(true)
                M.db[data.show_key] = true
            end
        end
        update()
    end)

    local function uncheck_frame_dependents()
        if M.db[data.move_key] then
            M.db[data.move_key] = false
            if move_cb and move_cb.SetChecked then move_cb:SetChecked(false) end
        end
    end

    place_at(x_slider, 1, 2)
    place_at(y_slider, 1, 3)
    place_at(width_slider, 1, 4)

    -- Snap to Grid / Show Grid: global toggles stacked below Move Mode
    local snap_container, snap_btn, _ = addon.CreateCheckbox(p, "Snap to Grid", M.db.snap_to_grid == true,
        function(is_checked)
            M.db.snap_to_grid = is_checked
        end
    )
    snap_container:SetPoint("TOPLEFT", move_mode_container, "BOTTOMLEFT", 0, -4)
    M.controls.snap_to_grid_checkbox = snap_btn

    local show_grid_container, show_grid_btn, _ = addon.CreateCheckbox(p, "Show Grid", M.db.show_grid == true,
        function(is_checked)
            M.db.show_grid = is_checked
            M.set_grid_visible(is_checked)
        end
    )
    show_grid_container:SetPoint("TOPLEFT", snap_container, "BOTTOMLEFT", 0, -4)
    M.controls.show_grid_checkbox = show_grid_btn

    -- move Reset: resets placement/width only, leaving Move Mode unchanged.
    M.create_move_reset_button(p, show_grid_container, {
        width = grid.reset_btn_width,
        on_click = function()
            local f = M.frames[data.show_key]
            if not f then return end
            M.reset_frame_move_placement(f, {
                default_position = M.defaults.positions[cat],
                default_width = M.defaults["width_"..cat] or M.DEFAULT_FRAME_WIDTH,
                width_table = M.db,
                width_key = "width_"..cat,
                scale_key = data.scale_key,
                x_slider = x_slider,
                y_slider = y_slider,
                width_slider = width_slider,
                update = update,
            })
        end,
    })

    add_row_separator(1)

    -- Row 2
    local enable_frame_container = create_bound_checkbox("Enable Frame", data.show_key, 2, 1, nil, nil, uncheck_frame_dependents)

    -- Test Aura: stacked below Enable Frame in the same cell
    local test_aura_container = create_bound_checkbox("Test Aura", test_key, 2, 1, update, nil, nil, check_enable_frame)
    test_aura_container:ClearAllPoints()
    test_aura_container:SetPoint("TOPLEFT", enable_frame_container, "BOTTOMLEFT", 0, 0)

    -- Frame background
    create_bound_checkbox("Frame BG", data.bg_key, 2, 2)

    -- Frame BG color picker
    create_bound_color_picker("bg_color_"..cat, true, "Frame BG Color", 2, 3)

    local hide_blizz_cdm_label = ({
        essential = "Hide WoW Essential",
        utility = "Hide WoW Utility",
        tracked_buffs = "Hide WoW Tracked Buffs",
        tracked_bars = "Hide WoW Tracked Bars",
    })[cat]

    -- Cooldown Mode toggle (cooldown-style CDM categories): show cooldown remaining instead of aura duration.
    if cat == "essential" or cat == "utility" then
        local cooldown_mode_container = create_bound_checkbox("Cooldown Mode", "cooldown_mode_" .. cat, 2, 4, update)
        local hide_blizz_cdm_container = create_bound_checkbox(hide_blizz_cdm_label, "hide_blizz_cdm_" .. cat, 2, 4, function()
            M.update_blizz_cdm_visibility(cat)
            update()
        end)
        hide_blizz_cdm_container:ClearAllPoints()
        hide_blizz_cdm_container:SetPoint("TOPLEFT", cooldown_mode_container, "BOTTOMLEFT", 0, 0)
    elseif hide_blizz_cdm_label then
        create_bound_checkbox(hide_blizz_cdm_label, "hide_blizz_cdm_" .. cat, 2, 4, function()
            M.update_blizz_cdm_visibility(cat)
            update()
        end)
    end

    add_row_separator(2)

    -- Row 3: Bar Mode, color pickers
    local bar_mode_key = "bar_mode_"..cat
    local bar_mode_container = create_bound_checkbox("Bar Mode", bar_mode_key, 3, 1)

    local bar_color_picker = addon.CreateColorPicker(p, M.db, "color_"..cat, true, "Bar Color", M.defaults, update)
    bar_color_picker:SetPoint("TOPLEFT", bar_mode_container, "BOTTOMLEFT", 0, -4)
    M.controls["bar_color_picker_"..cat] = bar_color_picker

    create_bound_color_picker("bar_text_color_"..cat, false, "Bar Text Color", 3, 2)
    create_bound_color_picker("bar_bg_color_"..cat, true, "Bar BG Color", 3, 3)
    add_row_separator(3)

    -- Row 4: Timer Text, Font & Font Size
    if cat ~= "static" then
        local timer_text_container = create_bound_checkbox("Timer Text", data.timer_key, 4, 1)

        local timer_bold_container = create_bound_checkbox("Bold", "timer_number_font_bold_"..cat, 4, 1, function()
            M.apply_number_font_to_all()
            update()
        end)
        timer_bold_container:ClearAllPoints()
        timer_bold_container:SetPoint("TOPLEFT", timer_text_container, "BOTTOMLEFT", 0, -4)

        local timer_font = M.CreateListDropdown(addon_name..cat.."TimerFont", p, "Font", get_timer_font_options(),
            function()
                return M.db["timer_number_font_"..cat] or M.db.timer_number_font or M.DEFAULT_TIMER_NUMBER_FONT_KEY
            end,
            function(value)
                M.db["timer_number_font_"..cat] = value
                M.apply_number_font_to_all()
                update()
            end,
            120 -- reduced width
        )

        place_at(timer_font, 4, 2, nil, {width=120, y_offset=-15})
        M.controls["timer_number_font_dropdown_"..cat] = timer_font

        local font_size_slider = addon.CreateSliderWithBox(addon_name..cat.."TimerFontSizeSlider", p, "Font Size", 8, 14, 0.5, M.db, "timer_number_font_size_"..cat,
            M.defaults,
            function()
                M.apply_number_font_to_all()
                update()
            end
        )
        place_at(font_size_slider, 4, 3)
        M.controls["timer_number_font_size_slider_"..cat] = font_size_slider

        local timer_color_picker = addon.CreateColorPicker(p, M.db, "timer_color_"..cat, false, "Color", M.defaults, function()
            M.apply_number_font_to_all()
            update()
        end)
        timer_color_picker:SetPoint("TOPLEFT", timer_bold_container, "BOTTOMLEFT", 0, -4)
        M.controls["timer_color_picker_"..cat] = timer_color_picker
    end

    add_row_separator(4)

    -- Row 5: Scale, Spacing, Max Icons
    local scale_slider = create_bound_slider("Scale", "Scale", 0.5, 2.5, 0.01, data.scale_key, update)
    place_at(scale_slider, 5, 1)

    local spacing_slider = create_bound_slider("Spacing", "Spacing", 0, 20, 0.1, data.spacing_key)
    place_at(spacing_slider, 5, 2)

    local max_icons_slider = create_bound_slider("PoolSlider", "Max Icons", 5, M.MAX_ICONS_LIMIT, 1, "max_icons_"..cat, function()
        print("|cFFFFFF00LsTweaks:|r Pool size for "..cat.." changed. Please /reload to apply.")
    end)
    place_at(max_icons_slider, 5, 4)

    -- Growth Direction dropdown in row 3, col 4, vertically centered
    place_at(M.CreateDirectionDropdown(addon_name..cat.."Growth", p, "Growth Direction", "growth_"..cat, update), 3, 4, "dropdown", { y_offset = -15 })

    -- Sync X/Y sliders to the frame's current position (called after a drag).
    -- Defined here so it closes over x_slider/y_slider/cat.
    local function sync_xy_sliders_to_frame()
        local f = M.frames[data.show_key]
        if not (f and x_slider and y_slider and x_slider.slider and y_slider.slider) then return end
        local pos = M.db.positions and M.db.positions[cat]
        if pos and pos.x and pos.y then
            x_slider.slider:SetValue(pos.x)
            y_slider.slider:SetValue(pos.y)
        end
    end

    -- Hook both title bars so dragging from either handle syncs the sliders.
    local f = M.frames[data.show_key]
    if f then
        for _, tb in ipairs({ f.title_bar, f.bottom_title_bar }) do
            if tb then
                local old_drag_stop = tb:GetScript("OnDragStop")
                tb:SetScript("OnDragStop", function(...)
                    if old_drag_stop then old_drag_stop(...) end
                    sync_xy_sliders_to_frame()
                end)
            end
        end
    end
end



-- Custom filtered frame panel builders.
-- These back the Filters group in the Frames tree.

local function update_custom_frame(entry)
    if not (entry and entry.id and M.frames) then return end
    local show_key = "show_" .. entry.id
    local frame = M.frames[show_key]
    if not frame then return end
    local aura_filter = M.get_custom_aura_filter(entry)
    frame.update_params.aura_filter = aura_filter
    M.update_auras(frame, show_key, "move", "timer", "bg", "scale", "spacing", aura_filter)
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
        M.mark_aura_scan_dirty()
        update_custom_frame(entry)
    end

    local grid = M.create_settings_grid(p)
    local place_at = grid.place_at
    local add_row_separator = grid.add_row_separator

    local function bound_cb(label, key, row, column, on_change)
        return create_bound_checkbox_control(p, label, entry, key, grid, row, column, "custom_" .. id .. "_" .. key, on_change, update)
    end

    local function bound_picker(key, has_alpha, label, row, column)
        local picker = addon.CreateColorPicker(p, entry, key, has_alpha, label, M.CUSTOM_FRAME_TEMPLATE, update)
        place_at(picker, row, column, "picker")
        return picker
    end

    local pos = entry.position or { x = 0, y = 50 }
    entry.position = pos

    local function update_frame_position(axis, value)
        local f = M.frames[show_key]
        if f and value ~= nil then
            M.set_saved_frame_position_axis(f, axis, value, "scale")
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
    x_slider.slider:HookScript("OnValueChanged", function(_, value)
        update_frame_position("x", value)
    end)
    place_at(x_slider, 1, 2)

    local y_slider = addon.CreateSliderWithBox(addon_name..id.."YPos", p, "Y Position", -1000, 1000, 1, pos, "y", { y = 50 })
    y_slider.slider:HookScript("OnValueChanged", function(_, value)
        update_frame_position("y", value)
    end)
    place_at(y_slider, 1, 3)

    local width_slider = addon.CreateSliderWithBox(addon_name..id.."Width", p, "Width", M.MIN_FRAME_WIDTH, M.MAX_FRAME_WIDTH, 1, entry, "width", M.CUSTOM_FRAME_TEMPLATE)
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
            M.set_grid_visible(is_checked)
        end)
    show_grid_container:SetPoint("TOPLEFT", snap_container, "BOTTOMLEFT", 0, -4)

    M.create_move_reset_button(p, show_grid_container, {
        width = grid.reset_btn_width,
        on_click = function()
            local f = M.frames[show_key]
            if not f then return end
            M.reset_frame_move_placement(f, {
                default_position = M.CUSTOM_FRAME_TEMPLATE.position,
                default_width = M.CUSTOM_FRAME_TEMPLATE.width,
                width_table = entry,
                width_key = "width",
                scale_key = "scale",
                x_slider = x_slider,
                y_slider = y_slider,
                width_slider = width_slider,
                update = update,
            })
        end,
    })

    add_row_separator(1)

    local enable_container, enable_cb = bound_cb("Enable Frame", "show", 2, 1, function(is_checked)
        if not is_checked then
            entry.move = false
            if move_cb and move_cb.SetChecked then move_cb:SetChecked(false) end
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
        M.apply_number_font_to_all()
        update()
    end)
    timer_bold_container:ClearAllPoints()
    timer_bold_container:SetPoint("TOPLEFT", timer_text_container, "BOTTOMLEFT", 0, -4)

    local timer_font_dd = M.CreateListDropdown(addon_name..id.."TimerFont", p, "Timer Font", get_timer_font_options(),
        function() return entry.timer_number_font or M.DEFAULT_TIMER_NUMBER_FONT_KEY end,
        function(value)
            entry.timer_number_font = value
            M.apply_number_font_to_all()
            update()
        end, 120)
    place_at(timer_font_dd, 4, 2, nil, { width = 120, y_offset = -15 })

    local font_size_slider = addon.CreateSliderWithBox(addon_name..id.."TimerFontSize", p, "Timer Font Size",
        8, 14, 0.5, entry, "timer_number_font_size", M.CUSTOM_FRAME_TEMPLATE,
        function()
            M.apply_number_font_to_all()
            update()
        end)
    place_at(font_size_slider, 4, 3)

    local timer_color_picker = addon.CreateColorPicker(p, entry, "timer_color", false, "Timer Color", M.CUSTOM_FRAME_TEMPLATE, function()
        M.apply_number_font_to_all()
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
        5, M.MAX_ICONS_LIMIT, 1, entry, "max_icons", M.CUSTOM_FRAME_TEMPLATE,
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
        local def = M.get_custom_modifier_def(entry.aura_modifier)
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
            local def = M.get_custom_modifier_def(entry.aura_modifier)
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
