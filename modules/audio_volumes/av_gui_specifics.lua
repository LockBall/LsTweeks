-- Specifics tab UI for the Audio Volumes module.
local _, addon = ...

addon.audio_volumes = addon.audio_volumes or {}
local M = addon.audio_volumes
local STRINGS = M.GUI_STRINGS
local UI = M.GUI_LAYOUT

local function create_specifics_help_panel(parent, anchor, anchor_point, offset_x, offset_y, width)
    local panel, text = addon.CreateRivetedPanel(
        parent,
        width or UI.panel_width,
        addon.RIVETED_PANEL_STYLE.panel_min_height,
        anchor,
        anchor_point,
        offset_x,
        offset_y
    )
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetText(STRINGS.help_text)
    local panel_padding = addon.RIVETED_PANEL_STYLE.padding
    panel:SetHeight(math.max(addon.RIVETED_PANEL_STYLE.panel_min_height, text:GetHeight() + (panel_padding * 2)))
    return panel
end
--#region SPECIFICS TAB =========================================================

function M.BuildSpecificsTab(parent)
    local db = M.get_db()
    local targets = M.get_ordered_sound_targets()
    local selected_key = (db.last_sound_key and M.SOUND_TARGETS[db.last_sound_key]) and db.last_sound_key or (targets[1] and targets[1].key)
    local target_rows = {}
    local slider_panels = {}

    local slider_x = UI.pad_x + UI.fishing_slider_width + UI.fishing_slider_gap
    local specifics_detail_width = (UI.fishing_slider_width * 4) + (UI.fishing_slider_gap * 3)
    local help_panel = create_specifics_help_panel(
        parent,
        parent,
        "TOPLEFT",
        slider_x,
        UI.pad_y - UI.slider_panel_height - 16,
        specifics_detail_width
    )

    local target_list_panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    target_list_panel:SetSize(UI.list_width, 260)
    target_list_panel:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.pad_y)
    M.ApplyGUIBoxBackdrop(target_list_panel)

    local function select_sound(target_key)
        if not (target_key and M.SOUND_TARGETS[target_key]) then
            return
        end
        selected_key = target_key
        db.last_sound_key = target_key
        for _, target_row in ipairs(target_rows) do
            local selected = target_row.target_key == selected_key
            target_row.bg:SetShown(selected)
            target_row.text:SetTextColor(selected and 1 or 0.86, selected and 0.82 or 0.86, selected and 0 or 0.86)
        end
        for _, sound_slider_panel in pairs(slider_panels) do
            sound_slider_panel:Hide()
        end
        local target = M.SOUND_TARGETS[selected_key]
        if target then
            if not slider_panels[selected_key] then
                slider_panels[selected_key] = M.BuildSoundTargetSliderPanel(parent, selected_key, target)
                slider_panels[selected_key]:ClearAllPoints()
                slider_panels[selected_key]:SetPoint("TOPLEFT", parent, "TOPLEFT", slider_x, UI.pad_y)
            end
            slider_panels[selected_key]:Show()
        end
    end

    for i, entry in ipairs(targets) do
        local target_row = CreateFrame("Button", nil, target_list_panel)
        target_row:SetSize(UI.list_width - 18, UI.list_row_height)
        target_row:SetPoint("TOPLEFT", target_list_panel, "TOPLEFT", 9, -(10 + ((i - 1) * UI.list_row_height)))
        target_row.target_key = entry.key

        target_row.bg = target_row:CreateTexture(nil, "BACKGROUND")
        target_row.bg:SetAllPoints()
        target_row.bg:SetColorTexture(0.75, 0.63, 0.12, 0.28)
        target_row.bg:Hide()

        local target_row_hover = target_row:CreateTexture(nil, "HIGHLIGHT")
        target_row_hover:SetAllPoints()
        target_row_hover:SetColorTexture(1, 1, 1, 0.08)

        target_row.text = target_row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        target_row.text:SetPoint("LEFT", target_row, "LEFT", 8, 0)
        target_row.text:SetPoint("RIGHT", target_row, "RIGHT", -8, 0)
        target_row.text:SetJustifyH("LEFT")
        target_row.text:SetText(entry.label)
        target_row:SetScript("OnClick", function()
            select_sound(entry.key)
        end)

        target_rows[#target_rows + 1] = target_row
    end

    if selected_key then
        select_sound(selected_key)
    end
end

--#endregion SPECIFICS TAB ======================================================
