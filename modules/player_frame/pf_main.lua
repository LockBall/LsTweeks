-- Player frame tweaks, currently focused on hiding Blizzard portrait combat text.
-- Registers the "Player Frame" settings category and applies changes immediately.
local addon_name, addon = ...
addon.player_frame = addon.player_frame or {
    controls = {},
    frames = {}
}

local M = addon.player_frame

local math_min = math.min
local math_max = math.max

local FADE_DEFAULTS = {
    fade_alpha = 0.5,
    fade_delay = 2.0,
    fade_length = 5.0,
    health_visible_threshold = 80,
    health_release_speed = 75,
}

M.FADE_DEFAULTS = FADE_DEFAULTS

local defaults = {
    player_frame = {
        hide_portrait_combat_text = false,
        fade_out_of_combat = false,
        fade_alpha = FADE_DEFAULTS.fade_alpha,
        fade_delay = FADE_DEFAULTS.fade_delay,
        fade_length = FADE_DEFAULTS.fade_length,
        health_visible_threshold = FADE_DEFAULTS.health_visible_threshold,
        health_release_speed = FADE_DEFAULTS.health_release_speed,
    },
}

local UI_CONFIG = {
    checkbox_offset_x = 20,
    checkbox_offset_y = -20,
    row_gap_y = 18,
    slider_gap_x = 18,
    slider_offset_y = -8,
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

local hitIndicatorFrame = nil
local hookApplied = false
local hidePortraitText = false
local fadeEventsRegistered = false
local loader = nil

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

local function get_player_frame_db()
    if not Ls_Tweeks_DB then return nil end
    Ls_Tweeks_DB.player_frame = Ls_Tweeks_DB.player_frame or {}
    return Ls_Tweeks_DB.player_frame
end

local function get_hit_indicator()
    if hitIndicatorFrame then return hitIndicatorFrame end

    if PlayerFrame and PlayerFrame.PlayerFrameContent then
        local content = PlayerFrame.PlayerFrameContent
        local main = content.PlayerFrameContentMain
        if main and main.HitIndicator then
            hitIndicatorFrame = main.HitIndicator
            return hitIndicatorFrame
        end
    end

    return nil
end

local function setup_on_show_hook(frame)
    if hookApplied or not frame then return end

    frame:HookScript("OnShow", function(self)
        self:SetAlpha(hidePortraitText and 0 or 1)
    end)
    hookApplied = true
end

function M.get_clamped_fade_value(db, key, min_value, max_value)
    local value = tonumber(db and db[key]) or FADE_DEFAULTS[key]
    return math_max(min_value, math_min(max_value, value))
end

local function sync_fade_events(db)
    if not loader then return end

    local should_register = db and db.fade_out_of_combat
    if should_register == fadeEventsRegistered then return end

    if should_register then
        loader:RegisterEvent("PLAYER_REGEN_DISABLED")
        loader:RegisterEvent("PLAYER_REGEN_ENABLED")
        loader:RegisterUnitEvent("UNIT_HEALTH", "player")
        loader:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    else
        loader:UnregisterEvent("PLAYER_REGEN_DISABLED")
        loader:UnregisterEvent("PLAYER_REGEN_ENABLED")
        loader:UnregisterEvent("UNIT_HEALTH")
        loader:UnregisterEvent("UNIT_MAXHEALTH")
    end

    fadeEventsRegistered = should_register and true or false
end

local function set_portrait_combat_text_hidden(disable)
    local h = get_hit_indicator()
    if not h then return end

    hidePortraitText = disable == true

    if hidePortraitText then
        h:SetAlpha(0)
        setup_on_show_hook(h)
    else
        h:SetAlpha(1)
    end
end

local function set_player_frame_setting(key, value)
    local db = get_player_frame_db()
    if not db then return end
    db[key] = value
    if key == "fade_out_of_combat" then
        sync_fade_events(db)
    end
    if key == "health_visible_threshold" then
        M.fade.on_threshold_changed(db)
    end
    M.update_player_frame()
end

local function on_fade_slider_changed(key)
    if key == "health_visible_threshold" then
        M.fade.on_threshold_changed(get_player_frame_db())
    end
    M.update_player_frame()
end

local function attach_help_tooltip(target, title, body)
    if not target then return end

    target:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:SetText(title, 1, 0.82, 0)
        else
            GameTooltip:ClearLines()
        end
        GameTooltip:AddLine(body or "", 0.95, 0.95, 0.95, true)
        GameTooltip:Show()
    end)

    target:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function M.update_player_frame()
    if addon.is_module_enabled and not addon.is_module_enabled("player_frame") then return end
    local db = get_player_frame_db()
    if not db then return end
    sync_fade_events(db)
    set_portrait_combat_text_hidden(db.hide_portrait_combat_text)
    M.fade.apply(db)
end

function M.on_reset_complete()
    if not Ls_Tweeks_DB then return end
    addon.apply_defaults(defaults, Ls_Tweeks_DB)
    local db = get_player_frame_db()
    if not db then return end

    M.update_player_frame()
    local cb = M.controls.hide_portrait_combat_text_checkbox
    if cb and cb.SetChecked then
        cb:SetChecked(db.hide_portrait_combat_text or false)
    end
    local fade_cb = M.controls.fade_out_of_combat_checkbox
    if fade_cb and fade_cb.SetChecked then
        fade_cb:SetChecked(db.fade_out_of_combat or false)
    end
    for _, def in ipairs(FADE_SLIDER_DEFS) do
        local slider = M.controls[def.control_key]
        if slider and slider.slider then
            slider.slider:SetValue(M.get_clamped_fade_value(db, def.key, def.min, def.max))
        end
    end
end

function M.set_module_enabled(enabled)
    if enabled then
        M.update_player_frame()
        return
    end

    sync_fade_events(nil)
    set_portrait_combat_text_hidden(false)
    if M.fade and M.fade.stop_transition then
        M.fade.stop_transition()
    end
    if PlayerFrame then
        PlayerFrame:SetAlpha(1)
    end
end

loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

local function init_complete(self)
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end

        Ls_Tweeks_DB = Ls_Tweeks_DB or {}
        addon.apply_defaults(defaults, Ls_Tweeks_DB)

        if addon.register_category then
            addon.register_category(STRINGS.category_name, function(parent)
                local cfg = UI_CONFIG
                local db = get_player_frame_db()
                local row1 = CreateFrame("Frame", nil, parent)
                row1:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.checkbox_offset_x, cfg.checkbox_offset_y)
                row1:SetSize(1, 1)

                local row2 = CreateFrame("Frame", nil, parent)
                row2:SetSize(1, 1)

                local cb_container, cb, cb_label = addon.CreateCheckbox(
                    row1,
                    STRINGS.checkbox_label,
                    db and db.hide_portrait_combat_text,
                    function(is_checked)
                        set_player_frame_setting("hide_portrait_combat_text", is_checked)
                    end
                )
                M.controls.hide_portrait_combat_text_checkbox = cb
                cb_container:SetPoint("TOPLEFT", row1, "TOPLEFT", 0, 0)

                attach_help_tooltip(cb_label, nil, STRINGS.combat_text_help)

                row2:SetPoint("TOPLEFT", cb_container, "BOTTOMLEFT", 0, -cfg.row_gap_y)

                local fade_container, fade_cb, fade_label = addon.CreateCheckbox(
                    row2,
                    STRINGS.fade_checkbox_label,
                    db and db.fade_out_of_combat,
                    function(is_checked)
                        set_player_frame_setting("fade_out_of_combat", is_checked)
                    end
                )
                M.controls.fade_out_of_combat_checkbox = fade_cb
                fade_container:SetPoint("TOPLEFT", row2, "TOPLEFT", 0, 0)

                attach_help_tooltip(fade_label, nil, STRINGS.fade_help)

                local previous_slider = nil
                for index, def in ipairs(FADE_SLIDER_DEFS) do
                    local slider_key = def.key
                    local slider = addon.CreateSliderWithBox(
                        addon_name .. "PlayerFrame" .. def.name_suffix,
                        row2,
                        STRINGS[def.label_key],
                        def.min,
                        def.max,
                        def.step,
                        db,
                        def.key,
                        FADE_DEFAULTS,
                        function()
                            on_fade_slider_changed(slider_key)
                        end
                    )
                    M.controls[def.control_key] = slider
                    if def.help_key then
                        attach_help_tooltip(slider, nil, STRINGS[def.help_key])
                    end

                    if index == 1 then
                        slider:SetPoint("TOPLEFT", fade_container, "BOTTOMLEFT", 0, cfg.slider_offset_y)
                    else
                        slider:SetPoint("TOPLEFT", previous_slider, "TOPRIGHT", cfg.slider_gap_x, 0)
                    end
                    previous_slider = slider
                end
            end, { module_key = "player_frame" })
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not addon.is_module_enabled or addon.is_module_enabled("player_frame") then
            M.update_player_frame()
        end
        init_complete(self)
    elseif event == "PLAYER_REGEN_DISABLED" then
        M.fade.on_enter_combat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        M.fade.on_leave_combat(get_player_frame_db())
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        M.fade.queue_health_update(get_player_frame_db)
    end
end)
