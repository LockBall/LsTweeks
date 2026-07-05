-- Player Frame settings panel.


--#region FILE CONTENTS ======================================================

local addon_name, addon = ...

local M = addon.player_frame or {}
addon.player_frame = M

M.controls = M.controls or {}

local math_abs = math.abs

local UI_CONFIG = {
    checkbox_offset_x = 20,
    checkbox_offset_y = -20,
    checkbox_height = 24,
    row_gap_y = 18,
    slider_gap_x = 18,
    slider_width = 130,
    slider_offset_y = -8,
    fade_row_padding_top = 8,
    fade_row_padding_bottom = 8,
}

local ROWS = {
    combat_text = 1,
    fade_controls = 2,
}

local STRINGS = {
    category_name = "Player Frame",
    checkbox_label = "Disable Combat Text",
    fade_checkbox_label = "OOC Fade",
    fade_slider_label = "Fade Alpha",
    fade_delay_slider_label = "Fade Delay",
    fade_length_slider_label = "Fade Length",
    health_visible_slider_label = "Low Health %",
    health_release_speed_slider_label = "Health Fade Speed",
    combat_text_help =
        "Hides the default damage and healing numbers on the Player Frame 'portrait'."
        .. "\nTestable while fighting training dummies in rested areas.",
    fade_help =
        "Fades out the Player Frame when Out Of Combat (OOC).",
    fade_alpha_help =
        "Visibility, 1 is max.",
    fade_delay_help =
        "Time in seconds before fade out begins.",
    fade_length_help =
        "Time in seconds to fade out.",
    health_visible_help =
        "Player Frame fully visible if health is below this. 0 disables.",
    health_release_speed_help =
        "How quickly visibility drops above Low Health %.",
}

local FADE_SLIDER_DEFS = {
    {
        key = "fade_alpha",
        control_key = "fade_alpha_slider",
        name_suffix = "FadeAlpha",
        label_key = "fade_slider_label",
        help_key = "fade_alpha_help",
        min = 0.1,
        max = 1.0,
        step = 0.05,
    },
    {
        key = "fade_delay",
        control_key = "fade_delay_slider",
        name_suffix = "FadeDelay",
        label_key = "fade_delay_slider_label",
        help_key = "fade_delay_help",
        min = 0,
        max = 5,
        step = 0.25,
    },
    {
        key = "fade_length",
        control_key = "fade_length_slider",
        name_suffix = "FadeLength",
        label_key = "fade_length_slider_label",
        help_key = "fade_length_help",
        min = 0,
        max = 10,
        step = 0.25,
    },
    {
        key = "health_visible_threshold",
        control_key = "health_visible_threshold_slider",
        name_suffix = "HealthVisibleThreshold",
        label_key = "health_visible_slider_label",
        help_key = "health_visible_help",
        min = 0,
        max = 100,
        step = 1,
    },
    {
        key = "health_release_speed",
        control_key = "health_release_speed_slider",
        name_suffix = "HealthReleaseSpeed",
        label_key = "health_release_speed_slider_label",
        help_key = "health_release_speed_help",
        min = 0,
        max = 100,
        step = 5,
    },
}

M.CATEGORY_NAME = STRINGS.category_name

function M.build_options_panel(parent)
    local cfg = UI_CONFIG
    local db = M.get_db and M.get_db()
    local grid = addon.CreateSettingsGrid(parent, {
        column_count = #FADE_SLIDER_DEFS,
        col_gap = cfg.slider_width + cfg.slider_gap_x,
        col_width = cfg.slider_width,
        col_offset = cfg.checkbox_offset_x,
        row_start = cfg.checkbox_offset_y,
        row_gap = 0,
        row_heights = {
            cfg.checkbox_height + cfg.row_gap_y,
            cfg.fade_row_padding_top + cfg.checkbox_height + math_abs(cfg.slider_offset_y) + 95 + cfg.fade_row_padding_bottom,
        },
        col_align = { "left", "left", "left", "left", "left" },
        offsets = { default = 0 },
        row_separators = { ROWS.combat_text, ROWS.fade_controls },
    })

    local cb_container, _, cb_label = addon.CreateCheckbox(
        parent,
        STRINGS.checkbox_label,
        db and db.hide_portrait_combat_text,
        function(is_checked)
            M.set_player_frame_setting("hide_portrait_combat_text", is_checked)
        end
    )
    M.controls.hide_portrait_combat_text_checkbox = cb_container
    grid:place_at(cb_container, ROWS.combat_text, 1)

    addon.AttachTooltip(cb_label, nil, STRINGS.combat_text_help)

    local fade_container, _, fade_label = addon.CreateCheckbox(
        parent,
        STRINGS.fade_checkbox_label,
        db and db.fade_out_of_combat,
        function(is_checked)
            M.set_player_frame_setting("fade_out_of_combat", is_checked)
        end
    )
    M.controls.fade_out_of_combat_checkbox = fade_container
    grid:place_at(fade_container, ROWS.fade_controls, 1, nil, {
        y_offset = -cfg.fade_row_padding_top,
    })

    addon.AttachTooltip(fade_label, nil, STRINGS.fade_help)

    for index, def in ipairs(FADE_SLIDER_DEFS) do
        local slider_key = def.key
        local slider = addon.CreateSliderWithBox(
            addon_name .. "PlayerFrame" .. def.name_suffix,
            parent,
            STRINGS[def.label_key],
            def.min,
            def.max,
            def.step,
            db,
            def.key,
            M.FADE_DEFAULTS,
            function()
                M.on_fade_slider_changed(slider_key)
            end,
            {
                tooltip = STRINGS[def.help_key],
            }
        )
        M.controls[def.control_key] = slider

        grid:place_at(slider, ROWS.fade_controls, index, nil, {
            y_offset = -(cfg.fade_row_padding_top + cfg.checkbox_height + math_abs(cfg.slider_offset_y)),
        })
    end
end

function M.sync_options_controls(db)
    local cb = M.controls.hide_portrait_combat_text_checkbox
    if cb and cb.SetCheckedSilently then
        cb:SetCheckedSilently(db.hide_portrait_combat_text or false)
    end
    local fade_cb = M.controls.fade_out_of_combat_checkbox
    if fade_cb and fade_cb.SetCheckedSilently then
        fade_cb:SetCheckedSilently(db.fade_out_of_combat or false)
    end
    for _, def in ipairs(FADE_SLIDER_DEFS) do
        local slider = M.controls[def.control_key]
        if slider and slider.SetValueSilently then
            slider:SetValueSilently(M.get_clamped_fade_value(db, def.key, def.min, def.max))
        end
    end
end

return M

--#endregion FILE CONTENTS ===================================================
