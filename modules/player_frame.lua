-- Player frame tweaks, currently focused on hiding Blizzard portrait combat text.
-- Registers the "Player Frame" settings category and applies changes immediately.
local addon_name, addon = ...

addon.player_frame = addon.player_frame or {
    controls = {},
    frames = {}
}

local M = addon.player_frame

local defaults = {
    player_frame = {
        hide_portrait_combat_text = false,
        fade_out_of_combat = false,
        fade_alpha = 0.5,
        fade_delay = 2.0,
        fade_length = 4.0,
    },
}

local UI_CONFIG = {
    checkbox_offset_x = 20,
    checkbox_offset_y = -20,
    row_gap_y = 18,
    control_gap_x = 18,
    control_offset_y = -6,
    slider_gap_x = 18,
    slider_offset_y = -8,
    panel_width = 475,
}

local STRINGS = {
    category_name = "Player Frame",
    checkbox_label = "Disable Combat Text",
    fade_checkbox_label = "OOC Fade",
    fade_slider_label = "Fade Alpha",
    fade_delay_slider_label = "Fade Delay",
    fade_length_slider_label = "Fade Length",
    combat_text_help =
        "Hides the default damage and healing numbers on the Player Frame 'portrait'."
        .. "\nTestable while fighting training dummies in rested areas.",
    fade_help =
        "Fades out the Player Frame when Out Of Combat (OOC).",
}

local hitIndicatorFrame = nil
local hookApplied = false
local playerFrameHookApplied = false
local hidePortraitText = false
local fadeDelayEndTime = 0
local fadeDelayTimer = nil
local fadeUpdateFrame = nil
local fadeActive = false

local FADE_SLIDER_DEFS = {
    {
        key = "fade_alpha",
        control_key = "fade_alpha_slider",
        name_suffix = "FadeAlpha",
        label_key = "fade_slider_label",
        min = 0.1,
        max = 1.0,
        step = 0.05,
    },
    {
        key = "fade_delay",
        control_key = "fade_delay_slider",
        name_suffix = "FadeDelay",
        label_key = "fade_delay_slider_label",
        min = 0,
        max = 5,
        step = 0.25,
    },
    {
        key = "fade_length",
        control_key = "fade_length_slider",
        name_suffix = "FadeLength",
        label_key = "fade_length_slider_label",
        min = 0,
        max = 10,
        step = 0.25,
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

local function setup_player_frame_on_show_hook(frame)
    if playerFrameHookApplied or not frame then return end

    frame:HookScript("OnShow", function()
        M.update_player_frame()
    end)
    playerFrameHookApplied = true
end

local function is_player_in_combat()
    return (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function get_clamped_fade_value(db, key, min_value, max_value)
    local value = tonumber(db and db[key]) or defaults.player_frame[key]
    return math.max(min_value, math.min(max_value, value))
end

local function get_fade_slider_def(key)
    for _, def in ipairs(FADE_SLIDER_DEFS) do
        if def.key == key then return def end
    end
    return nil
end

local function stop_fade_transition()
    fadeDelayEndTime = 0
    if fadeDelayTimer then
        fadeDelayTimer:Cancel()
        fadeDelayTimer = nil
    end
    fadeActive = false
    if fadeUpdateFrame then
        fadeUpdateFrame:SetScript("OnUpdate", nil)
    end
end

local function get_fade_delay(db)
    local def = get_fade_slider_def("fade_delay")
    return get_clamped_fade_value(db, "fade_delay", def.min, def.max)
end

local function get_fade_length(db)
    local def = get_fade_slider_def("fade_length")
    return get_clamped_fade_value(db, "fade_length", def.min, def.max)
end

local function get_fade_alpha(db)
    local def = get_fade_slider_def("fade_alpha")
    return get_clamped_fade_value(db, "fade_alpha", def.min, def.max)
end

local function get_fade_update_frame()
    if fadeUpdateFrame then return fadeUpdateFrame end
    fadeUpdateFrame = CreateFrame("Frame")
    return fadeUpdateFrame
end

local function begin_fade_delay(db)
    stop_fade_transition()
    if not (db and db.fade_out_of_combat) then return end

    local delay = get_fade_delay(db)
    if delay <= 0 then return end

    fadeDelayEndTime = GetTime() + delay
    if C_Timer and C_Timer.NewTimer then
        fadeDelayTimer = C_Timer.NewTimer(delay, function()
            fadeDelayTimer = nil
            fadeDelayEndTime = 0
            M.update_player_frame()
        end)
    end
end

local function apply_ooc_fade_alpha(db, animate)
    local alpha = get_fade_alpha(db)
    local length = get_fade_length(db)

    if not animate or length <= 0 or PlayerFrame:GetAlpha() == alpha then
        stop_fade_transition()
        PlayerFrame:SetAlpha(alpha)
        return
    end

    local current_alpha = PlayerFrame:GetAlpha()
    local start_time = GetTime()
    local update_frame = get_fade_update_frame()

    fadeActive = true
    update_frame:SetScript("OnUpdate", function(self)
        if not fadeActive or not PlayerFrame then
            self:SetScript("OnUpdate", nil)
            return
        end

        if is_player_in_combat() then
            stop_fade_transition()
            PlayerFrame:SetAlpha(1)
            return
        end

        local progress = math.min(1, (GetTime() - start_time) / length)
        PlayerFrame:SetAlpha(current_alpha + ((alpha - current_alpha) * progress))
        if progress >= 1 then
            fadeActive = false
            self:SetScript("OnUpdate", nil)
            PlayerFrame:SetAlpha(alpha)
        end
    end)
end

local function apply_player_frame_fade(db)
    if not PlayerFrame then return end

    setup_player_frame_on_show_hook(PlayerFrame)
    if is_player_in_combat() or not (db and db.fade_out_of_combat) then
        stop_fade_transition()
        PlayerFrame:SetAlpha(1)
        return
    end

    if GetTime() < fadeDelayEndTime then
        PlayerFrame:SetAlpha(1)
        return
    end

    apply_ooc_fade_alpha(db, true)
end

local function set_portrait_combat_text_hidden(disable)
    local h = get_hit_indicator()
    if not h then return end

    hidePortraitText = disable and true or false

    if hidePortraitText then
        h:SetAlpha(0)
        setup_on_show_hook(h)
    else
        h:SetAlpha(1)
    end
end

function M.update_player_frame()
    local db = get_player_frame_db()
    if not db then return end
    set_portrait_combat_text_hidden(db.hide_portrait_combat_text)
    apply_player_frame_fade(db)
end

function M.on_reset_complete()
    if not Ls_Tweeks_DB then return end
    addon.apply_defaults(defaults, Ls_Tweeks_DB)
    M.update_player_frame()
    local cb = M.controls.hide_portrait_combat_text_checkbox
    if cb and cb.SetChecked then
        local db = get_player_frame_db()
        cb:SetChecked(db and db.hide_portrait_combat_text or false)
    end
    local fade_cb = M.controls.fade_out_of_combat_checkbox
    if fade_cb and fade_cb.SetChecked then
        local db = get_player_frame_db()
        fade_cb:SetChecked(db and db.fade_out_of_combat or false)
    end
    local db = get_player_frame_db()
    for _, def in ipairs(FADE_SLIDER_DEFS) do
        local slider = M.controls[def.control_key]
        if slider and slider.slider then
            slider.slider:SetValue((db and db[def.key]) or defaults.player_frame[def.key])
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")

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
                local panel_style = addon.RIVETED_PANEL_STYLE
                local db = get_player_frame_db()
                local row1 = CreateFrame("Frame", nil, parent)
                row1:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.checkbox_offset_x, cfg.checkbox_offset_y)
                row1:SetSize(1, 1)

                local row2 = CreateFrame("Frame", nil, parent)
                row2:SetSize(1, 1)

                local panelWidth = cfg.panel_width
                local panelMinHeight = panel_style.panel_min_height
                local textPad = panel_style.padding

                local combatNotePanel, combatNoteText = addon.CreateRivetedPanel(
                    row1,
                    panelWidth,
                    panelMinHeight,
                    row1,
                    "TOPLEFT",
                    0,
                    0
                )

                if not combatNotePanel or not combatNoteText then return end
                combatNotePanel:ClearAllPoints()
                combatNotePanel:SetPoint("TOPLEFT", row1, "TOPLEFT", 0, 0)

                combatNoteText:ClearAllPoints()
                combatNoteText:SetJustifyH("LEFT")
                combatNoteText:SetJustifyV("TOP")
                combatNoteText:SetWordWrap(true)
                combatNoteText:SetText(STRINGS.combat_text_help)

                combatNoteText:SetPoint("TOPLEFT", combatNotePanel, "TOPLEFT", textPad, -textPad)
                combatNoteText:SetPoint("RIGHT", combatNotePanel, "RIGHT", -textPad, 0)

                local combatTextHeight = combatNoteText:GetHeight()
                combatNotePanel:SetHeight(math.max(panelMinHeight, combatTextHeight + (textPad * 2)))

                local cb_container, cb = addon.CreateCheckbox(
                    row1,
                    STRINGS.checkbox_label,
                    db and db.hide_portrait_combat_text,
                    function(is_checked)
                        local current_db = get_player_frame_db()
                        if not current_db then return end
                        current_db.hide_portrait_combat_text = is_checked
                        M.update_player_frame()
                    end
                )
                M.controls.hide_portrait_combat_text_checkbox = cb
                cb_container:SetPoint("TOPLEFT", combatNotePanel, "TOPRIGHT", cfg.control_gap_x, cfg.control_offset_y)

                row2:SetPoint("TOPLEFT", combatNotePanel, "BOTTOMLEFT", 0, -cfg.row_gap_y)

                local fadeNotePanel, fadeNoteText = addon.CreateRivetedPanel(
                    row2,
                    panelWidth,
                    panelMinHeight,
                    row2,
                    "TOPLEFT",
                    0,
                    0
                )

                if not fadeNotePanel or not fadeNoteText then return end
                fadeNotePanel:ClearAllPoints()
                fadeNotePanel:SetPoint("TOPLEFT", row2, "TOPLEFT", 0, 0)

                fadeNoteText:ClearAllPoints()
                fadeNoteText:SetJustifyH("LEFT")
                fadeNoteText:SetJustifyV("TOP")
                fadeNoteText:SetWordWrap(true)
                fadeNoteText:SetText(STRINGS.fade_help)

                fadeNoteText:SetPoint("TOPLEFT", fadeNotePanel, "TOPLEFT", textPad, -textPad)
                fadeNoteText:SetPoint("RIGHT", fadeNotePanel, "RIGHT", -textPad, 0)

                local fadeTextHeight = fadeNoteText:GetHeight()
                fadeNotePanel:SetHeight(math.max(panelMinHeight, fadeTextHeight + (textPad * 2)))

                local fade_container, fade_cb = addon.CreateCheckbox(
                    row2,
                    STRINGS.fade_checkbox_label,
                    db and db.fade_out_of_combat,
                    function(is_checked)
                        local current_db = get_player_frame_db()
                        if not current_db then return end
                        current_db.fade_out_of_combat = is_checked
                        M.update_player_frame()
                    end
                )
                M.controls.fade_out_of_combat_checkbox = fade_cb
                fade_container:SetPoint("TOPLEFT", fadeNotePanel, "TOPRIGHT", cfg.control_gap_x, cfg.control_offset_y)

                local previous_slider = nil
                for index, def in ipairs(FADE_SLIDER_DEFS) do
                    local slider = addon.CreateSliderWithBox(
                        addon_name .. "PlayerFrame" .. def.name_suffix,
                        row2,
                        STRINGS[def.label_key],
                        def.min,
                        def.max,
                        def.step,
                        db,
                        def.key,
                        defaults.player_frame,
                        M.update_player_frame
                    )
                    M.controls[def.control_key] = slider

                    if index == 1 then
                        slider:SetPoint("TOPLEFT", fadeNotePanel, "BOTTOMLEFT", 0, cfg.slider_offset_y)
                    else
                        slider:SetPoint("TOPLEFT", previous_slider, "TOPRIGHT", cfg.slider_gap_x, 0)
                    end
                    previous_slider = slider
                end
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        M.update_player_frame()
        init_complete(self)
    elseif event == "PLAYER_REGEN_DISABLED" then
        stop_fade_transition()
        M.update_player_frame()
    elseif event == "PLAYER_REGEN_ENABLED" then
        begin_fade_delay(get_player_frame_db())
        M.update_player_frame()
    end
end)
