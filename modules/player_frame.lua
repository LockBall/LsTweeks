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
    },
}

local UI_CONFIG = {
    checkbox_offset_x = 20,
    checkbox_offset_y = -20,
}

local STRINGS = {
    category_name = "Player Frame",
    checkbox_label = "Disable Player Frame Combat Text",
    help_text =
        "Hides the default damage and healing numbers on the Player Frame 'portrait'."
        .. "\nTestable while fighting training dummies in rested areas.",
}

local hitIndicatorFrame = nil
local hookApplied = false
local hidePortraitText = false

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
end

local loader = CreateFrame("Frame")
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
                local panel_style = addon.RIVETED_PANEL_STYLE
                local db = get_player_frame_db()

                local cb_container, cb = addon.CreateCheckbox(
                    parent,
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
                cb_container:SetPoint("TOPLEFT", parent, "TOPLEFT", cfg.checkbox_offset_x, cfg.checkbox_offset_y)

                local panelWidth = 475
                local panelMinHeight = panel_style.panel_min_height
                local panelGapY = -4
                local textPad = panel_style.padding
                local notePanel, noteText = addon.CreateRivetedPanel(
                    parent,
                    panelWidth,
                    panelMinHeight,
                    cb_container,
                    "BOTTOMLEFT",
                    0,
                    0
                )

                if not notePanel or not noteText then return end
                notePanel:ClearAllPoints()
                notePanel:SetPoint("TOPLEFT", cb_container, "BOTTOMLEFT", 0, panelGapY)

                noteText:ClearAllPoints()
                noteText:SetJustifyH("LEFT")
                noteText:SetJustifyV("TOP")
                noteText:SetWordWrap(true)
                noteText:SetText(STRINGS.help_text)

                noteText:SetPoint("TOPLEFT", notePanel, "TOPLEFT", textPad, -textPad)
                noteText:SetPoint("RIGHT", notePanel, "RIGHT", -textPad, 0)

                local textHeight = noteText:GetHeight()
                notePanel:SetHeight(math.max(panelMinHeight, textHeight + (textPad * 2)))
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        M.update_player_frame()
        init_complete(self)
    end
end)
