-- Sound Levels settings and runtime.
-- Provides preset-based per-sound control by muting known Blizzard FileDataIDs and
-- playing addon-owned replacement sound files when configured.
local addon_name, addon = ...

addon.sound_levels = addon.sound_levels or {
    controls = {},
    frames = {},
}

local M = addon.sound_levels
M.controls = M.controls or {}
M.frames = M.frames or {}

local STRINGS = {
    category_name = "Sound Levels",
    title = "Sound Levels",
    play_on_adjust_label = "Play Sound on Adjust",
    status_waiting = "Waiting for Blizzard FileDataID and replacement sound files.",
    help_text =
        "This module uses premade files at specific volumes because WoW does not support per-sound volume controls."
        .. "\n\nOriginal is the unmodified WoW volume."
        .. "\n\n Shush, Shusher and Shushest are increasingly quiet, in that order."
        .. "\n\nThey suppress the original file and play replacement files from modules\\sound_levels\\sounds."
        ,
}

local UI = {
    pad_x = 20,
    pad_y = -18,
    row_gap = -34,
    tab_width = 92,
    tab_height = 24,
    tab_gap = 8,
    content_top = -58,
    panel_width = 590,
    list_width = 190,
    list_row_height = 26,
    detail_x = 230,
    sound_panel_y = -18,
    detail_width = 450,
    detail_height = 230,
    level_slider_width = 260,
}

local function get_db()
    Ls_Tweeks_DB = Ls_Tweeks_DB or {}
    local defaults = addon.module_defaults and addon.module_defaults.sound_levels
    if defaults then
        addon.apply_defaults(defaults, Ls_Tweeks_DB)
    end
    Ls_Tweeks_DB.sound_levels = Ls_Tweeks_DB.sound_levels or {}
    Ls_Tweeks_DB.sound_levels.targets = Ls_Tweeks_DB.sound_levels.targets or {}
    return Ls_Tweeks_DB.sound_levels
end

local function get_target_db(target_key)
    local db = get_db()
    db.targets[target_key] = db.targets[target_key] or {}
    local defaults = M.defaults
        and M.defaults.sound_levels
        and M.defaults.sound_levels.targets
        and M.defaults.sound_levels.targets[target_key]
    if defaults then
        addon.apply_defaults(defaults, db.targets[target_key])
    end
    return db.targets[target_key]
end

local function is_known_preset(value)
    for _, option in ipairs(M.PRESET_OPTIONS or {}) do
        if option.value == value then
            return true
        end
    end
    return false
end

local function get_preset_by_value(value)
    for _, option in ipairs(M.PRESET_OPTIONS or {}) do
        if option.value == value then
            return option
        end
    end
    return M.PRESET_OPTIONS and M.PRESET_OPTIONS[1]
end

local function get_preset_by_slider_value(value)
    local rounded = math.floor((tonumber(value) or 1) + 0.5)
    for _, option in ipairs(M.PRESET_OPTIONS or {}) do
        if option.slider_value == rounded then
            return option
        end
    end
    return M.PRESET_OPTIONS and M.PRESET_OPTIONS[1]
end

local function should_mute_original(target_db)
    local preset = target_db and target_db.preset or "original"
    return preset ~= "original"
end

local function should_play_replacement(target_db)
    local preset = target_db and target_db.preset or "original"
    return preset ~= "original"
end

local function play_preview_soundkit(target)
    local soundkit_key = target and target.preview_soundkit
    local soundkit_id = nil
    if type(soundkit_key) == "number" then
        soundkit_id = soundkit_key
    elseif type(soundkit_key) == "string" and SOUNDKIT then
        soundkit_id = SOUNDKIT[soundkit_key]
    end
    if not soundkit_id then return false end

    M.stop_preview_sound()
    local will_play, sound_handle
    if C_Sound and C_Sound.PlaySound then
        will_play, sound_handle = C_Sound.PlaySound(soundkit_id)
    elseif PlaySound then
        will_play, sound_handle = PlaySound(soundkit_id)
    end
    M._preview_sound_handle = sound_handle
    return will_play ~= false
end

local function mute_file(file_id)
    if C_Sound and C_Sound.MuteSoundFile then
        C_Sound.MuteSoundFile(file_id)
    elseif MuteSoundFile then
        MuteSoundFile(file_id)
    end
end

local function unmute_file(file_id)
    if C_Sound and C_Sound.UnmuteSoundFile then
        C_Sound.UnmuteSoundFile(file_id)
    elseif UnmuteSoundFile then
        UnmuteSoundFile(file_id)
    end
end

function M.apply_sound_levels()
    get_db()
    for target_key, target in pairs(M.SOUND_TARGETS or {}) do
        local target_db = get_target_db(target_key)
        local mute = should_mute_original(target_db)
        for _, file_id in ipairs(target.original_file_ids or {}) do
            if mute then
                mute_file(file_id)
            else
                unmute_file(file_id)
            end
        end
    end
end

function M.play_replacement(target_key)
    get_db()

    local target = M.SOUND_TARGETS and M.SOUND_TARGETS[target_key]
    if not target then return false end

    local target_db = get_target_db(target_key)
    if (target_db.preset or "original") == "original" then
        return play_preview_soundkit(target)
    end

    if not should_play_replacement(target_db) then return false end

    local preset = target_db.preset
    local path = target.replacement_paths and target.replacement_paths[preset]
    if not path then return play_preview_soundkit(target) end

    M.stop_preview_sound()
    local did_play, sound_handle
    if C_Sound and C_Sound.PlaySoundFile then
        did_play, sound_handle = C_Sound.PlaySoundFile(path, "Master")
    elseif PlaySoundFile then
        did_play, sound_handle = PlaySoundFile(path, "Master")
    end
    M._preview_sound_handle = sound_handle
    if did_play == false then return play_preview_soundkit(target) end
    return true
end

function M.stop_preview_sound()
    local handle = M._preview_sound_handle
    M._preview_sound_handle = nil
    if not handle then return end
    if C_Sound and C_Sound.StopSound then
        C_Sound.StopSound(handle)
    elseif StopSound then
        StopSound(handle)
    end
end

local function queue_adjust_preview(target_key)
    if M._adjust_preview_timer then
        M._adjust_preview_timer:Cancel()
        M._adjust_preview_timer = nil
    end
    M.stop_preview_sound()
    M._adjust_preview_timer = C_Timer.NewTimer(0.12, function()
        M._adjust_preview_timer = nil
        M.play_replacement(target_key)
    end)
end

local function handle_event(_, event)
    for target_key, target in pairs(M.SOUND_TARGETS or {}) do
        for _, target_event in ipairs(target.events or {}) do
            if target_event == event then
                M.play_replacement(target_key)
                return
            end
        end
    end
end

local function sync_registered_events()
    if not M.event_frame then
        M.event_frame = CreateFrame("Frame")
        M.event_frame:SetScript("OnEvent", handle_event)
    end

    M.event_frame:UnregisterAllEvents()
    get_db()

    local registered = {}
    for _, target in pairs(M.SOUND_TARGETS or {}) do
        for _, event_name in ipairs(target.events or {}) do
            if not registered[event_name] then
                M.event_frame:RegisterEvent(event_name)
                registered[event_name] = true
            end
        end
    end
end

local function apply_box_backdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.28)
    frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
end

local function get_ordered_sound_targets()
    local targets = {}
    for target_key, target in pairs(M.SOUND_TARGETS or {}) do
        targets[#targets + 1] = {
            key = target_key,
            target = target,
            order = target.order or 100,
            label = target.label or target_key,
        }
    end
    table.sort(targets, function(a, b)
        if a.order == b.order then
            return a.label < b.label
        end
        return a.order < b.order
    end)
    return targets
end

local function build_sound_detail_panel(parent, target_key, target)
    local target_db = get_target_db(target_key)

    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(UI.detail_width, UI.detail_height)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.detail_x, UI.sound_panel_y)
    apply_box_backdrop(box)

    local desc = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -16)
    desc:SetWidth(UI.detail_width - 32)
    desc:SetJustifyH("LEFT")
    desc:SetText(target.description or "")
    if (target.description or "") == "" then
        desc:SetText(" ")
    end

    local level_label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    level_label:SetPoint("TOP", desc, "BOTTOM", 0, -26)
    level_label:SetText("Level")

    local current_preset = get_preset_by_value(target_db.preset)
    local slider = CreateFrame("Slider", addon_name .. target_key .. "SoundLevelSlider", box, "MinimalSliderTemplate")
    slider:SetSize(UI.level_slider_width, 18)
    slider:SetPoint("TOP", level_label, "BOTTOM", 0, -22)
    slider:SetMinMaxValues(1, 4)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(current_preset and current_preset.slider_value or 1)

    for _, option in ipairs(M.PRESET_OPTIONS or {}) do
        local tick = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        local x = ((option.slider_value or 1) - 1) * (UI.level_slider_width / 3)
        tick:SetPoint("TOP", slider, "BOTTOMLEFT", x, -6)
        tick:SetText(option.text)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        local option = get_preset_by_slider_value(value)
        local slider_value = option and option.slider_value or 1
        if self:GetValue() ~= slider_value then
            self:SetValue(slider_value)
            return
        end
        local new_preset = (option and option.value) or target.default_preset or "original"
        if target_db.preset == new_preset then
            return
        end
        target_db.preset = new_preset
        M.apply_sound_levels()
    end)
    slider:SetScript("OnMouseUp", function()
        if target_db.play_on_adjust == true then
            queue_adjust_preview(target_key)
        end
    end)
    M.controls[target_key .. "_preset"] = slider

    local test = CreateFrame("Button", nil, box)
    test:SetSize(32, 32)
    test:SetPoint("TOP", slider, "BOTTOM", -70, -36)

    local button_ring = test:CreateTexture(nil, "BORDER")
    button_ring:SetAllPoints()
    button_ring:SetTexture("Interface\\Artifacts\\ArtifactRelic-Slot")
    button_ring:SetDesaturated(true)
    button_ring:SetVertexColor(0.55, 0.55, 0.55, 0.85)

    local play_icon = test:CreateTexture(nil, "OVERLAY")
    play_icon:SetSize(18, 22)
    play_icon:SetPoint("CENTER", test, "CENTER", 1, 0)
    play_icon:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    play_icon:SetTexCoord(0.18, 0.82, 0.16, 0.84)
    play_icon:SetVertexColor(0.9, 0.9, 0.9, 1)
    test:SetScript("OnEnter", function()
        button_ring:SetVertexColor(0.75, 0.75, 0.75, 0.95)
        play_icon:SetVertexColor(1, 1, 1, 1)
    end)
    test:SetScript("OnLeave", function()
        button_ring:SetVertexColor(0.55, 0.55, 0.55, 0.85)
        play_icon:SetVertexColor(0.9, 0.9, 0.9, 1)
        play_icon:SetPoint("CENTER", test, "CENTER", 1, 0)
    end)
    test:SetScript("OnMouseDown", function()
        button_ring:SetVertexColor(0.4, 0.4, 0.4, 0.85)
        play_icon:SetPoint("CENTER", test, "CENTER", 2, -1)
    end)
    test:SetScript("OnMouseUp", function()
        button_ring:SetVertexColor(0.75, 0.75, 0.75, 0.95)
        play_icon:SetPoint("CENTER", test, "CENTER", 1, 0)
    end)
    test:SetScript("OnClick", function()
        M.play_replacement(target_key)
    end)

    local replacement_container, replacement_cb = addon.CreateCheckbox(
        box,
        STRINGS.play_on_adjust_label,
        target_db.play_on_adjust == true,
        function(is_checked)
            target_db.play_on_adjust = is_checked == true
        end
    )
    replacement_container:SetPoint("LEFT", test, "RIGHT", 18, 0)
    M.controls[target_key .. "_play_on_adjust"] = replacement_cb

    if #(target.original_file_ids or {}) == 0 and not target.preview_soundkit then
        local status = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        status:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 16, 14)
        status:SetWidth(UI.detail_width - 32)
        status:SetJustifyH("LEFT")
        status:SetText(STRINGS.status_waiting)
    end

    return box
end

local function build_general_tab(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", addon.UI_THEME.font_title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.pad_y)
    title:SetText("General")

    local panel, text = addon.CreateRivetedPanel(
        parent,
        UI.panel_width,
        addon.RIVETED_PANEL_STYLE.panel_min_height,
        title,
        "TOPLEFT",
        0,
        -34
    )
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -22)
    text:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetText(STRINGS.help_text)
    panel:SetHeight(math.max(addon.RIVETED_PANEL_STYLE.panel_min_height, text:GetHeight() + 44))

    local reset = addon.CreateGlobalReset(parent, get_db(), M.defaults.sound_levels)
    reset:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -20)
end

local function build_sounds_tab(parent)
    get_db()
    local targets = get_ordered_sound_targets()
    local selected_key = targets[1] and targets[1].key
    local rows = {}
    local detail_panels = {}

    local list_box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list_box:SetSize(UI.list_width, 260)
    list_box:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.pad_x, UI.sound_panel_y)
    apply_box_backdrop(list_box)

    local function select_sound(target_key)
        selected_key = target_key
        for _, row in ipairs(rows) do
            local selected = row.target_key == selected_key
            row.bg:SetShown(selected)
            row.text:SetTextColor(selected and 1 or 0.86, selected and 0.82 or 0.86, selected and 0 or 0.86)
        end
        for _, panel in pairs(detail_panels) do
            panel:Hide()
        end
        local target = M.SOUND_TARGETS and M.SOUND_TARGETS[selected_key]
        if target then
            if not detail_panels[selected_key] then
                detail_panels[selected_key] = build_sound_detail_panel(parent, selected_key, target)
            end
            detail_panels[selected_key]:Show()
        end
    end

    for i, entry in ipairs(targets) do
        local row = CreateFrame("Button", nil, list_box)
        row:SetSize(UI.list_width - 18, UI.list_row_height)
        row:SetPoint("TOPLEFT", list_box, "TOPLEFT", 9, -(10 + ((i - 1) * UI.list_row_height)))
        row.target_key = entry.key

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.75, 0.63, 0.12, 0.28)
        row.bg:Hide()

        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.08)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetText(entry.label)
        row:SetScript("OnClick", function()
            select_sound(entry.key)
        end)

        rows[#rows + 1] = row
    end

    if selected_key then
        select_sound(selected_key)
    end
end

local function build_sound_levels_page(parent)
    local tabs = {}
    local panels = {}
    local selected_index = 1

    local tab_defs = {
        { label = "General", builder = build_general_tab },
        { label = "Sounds", builder = build_sounds_tab },
    }

    local function select_tab(index)
        selected_index = index
        for i, button in ipairs(tabs) do
            if i == selected_index then
                PanelTemplates_SelectTab(button)
                panels[i]:Show()
            else
                PanelTemplates_DeselectTab(button)
                panels[i]:Hide()
            end
        end
    end

    for i, def in ipairs(tab_defs) do
        local tab = CreateFrame("Button", addon_name .. "SoundLevelsTab" .. i, parent, "PanelTabButtonTemplate")
        tab:SetText(def.label)
        tab:SetID(i)
        tab:SetPoint(i == 1 and "TOPLEFT" or "LEFT", i == 1 and parent or tabs[i-1], i == 1 and "TOPLEFT" or "RIGHT", i == 1 and UI.pad_x or 5, i == 1 and UI.pad_y or 0)
        PanelTemplates_TabResize(tab, 0)
        tabs[i] = tab

        local panel = CreateFrame("Frame", nil, parent)
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, UI.content_top)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        panel:Hide()
        panels[i] = panel

        def.builder(panel)
        tab:SetScript("OnClick", function(self)
            select_tab(self:GetID())
        end)
    end

    PanelTemplates_SetNumTabs(parent, #tab_defs)
    select_tab(selected_index)
    PanelTemplates_UpdateTabs(parent)
end

function M.on_reset_complete()
    local db = get_db()
    addon.apply_defaults(M.defaults.sound_levels, db)
    M.apply_sound_levels()
    sync_registered_events()

    for target_key in pairs(M.SOUND_TARGETS or {}) do
        local target_db = get_target_db(target_key)
        local preset = M.controls[target_key .. "_preset"]
        if preset and preset.SetValue then
            local option = get_preset_by_value(target_db.preset)
            preset:SetValue(option and option.slider_value or 1)
        end
        local play_on_adjust = M.controls[target_key .. "_play_on_adjust"]
        if play_on_adjust and play_on_adjust.SetChecked then
            play_on_adjust:SetChecked(target_db.play_on_adjust == true)
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        get_db()
        M.apply_sound_levels()
        sync_registered_events()
        if addon.register_category then
            addon.register_category(STRINGS.category_name, build_sound_levels_page, { order = 900 })
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGOUT" then
        for _, target in pairs(M.SOUND_TARGETS or {}) do
            for _, file_id in ipairs(target.original_file_ids or {}) do
                unmute_file(file_id)
            end
        end
    end
end)
