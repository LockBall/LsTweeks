-- Native Blizzard aura-frame visibility logic for Aura Frames.
-- Suppresses Blizzard-owned BuffFrame, DebuffFrame, and CooldownViewer frames without calling Hide().
local addon_name, addon = ...

local InCombatLockdown = InCombatLockdown

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

--#region BLIZZARD BUFF/DEBUFF FRAME TOGGLES ===================================

local blizz_aura_frame_state = setmetatable({}, { __mode = "k" })
local cdm_setting_restore_frame

local function get_blizz_aura_frame_state(frame)
    local state = blizz_aura_frame_state[frame]
    if not state then
        state = {}
        blizz_aura_frame_state[frame] = state
    end
    return state
end

local function get_cdm_viewer_state(frame)
    M._cd_viewer_state = M._cd_viewer_state or setmetatable({}, { __mode = "k" })
    local state = M._cd_viewer_state[frame]
    if not state then
        state = {}
        M._cd_viewer_state[frame] = state
    end
    return state
end

local function queue_cdm_setting_restore()
    if cdm_setting_restore_frame then
        cdm_setting_restore_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    cdm_setting_restore_frame = CreateFrame("Frame")
    cdm_setting_restore_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    cdm_setting_restore_frame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        M.restore_blizz_cdm_viewer_settings()
    end)
end

local function set_blizz_frame_state(frame, hide)
    if not frame then return end
    local state = get_blizz_aura_frame_state(frame)

    if hide then
        state.forced_hidden = true
        if not state.on_show_hooked and frame.HookScript then
            state.on_show_hooked = true
            frame:HookScript("OnShow", function(self)
                local current_state = blizz_aura_frame_state[self]
                if current_state and current_state.forced_hidden then
                    if self.SetAlpha then self:SetAlpha(0) end
                    if self.EnableMouse then self:EnableMouse(false) end
                end
            end)
        end
        if frame.SetAlpha then frame:SetAlpha(0) end
        if frame.EnableMouse then frame:EnableMouse(false) end
        return
    end

    if state.forced_hidden then
        state.forced_hidden = nil
        if frame.SetAlpha then frame:SetAlpha(1) end
        if frame.EnableMouse then frame:EnableMouse(true) end
    end
end

function M.toggle_blizz_buffs(hide)
    set_blizz_frame_state(BuffFrame, hide)
end

function M.toggle_blizz_debuffs(hide)
    set_blizz_frame_state(DebuffFrame, hide)
end

function M.ensure_blizz_cdm_loaded()
    if M._blizz_cdm_load_attempted then return end
    M._blizz_cdm_load_attempted = true
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
    end
end

function M.ensure_blizz_cdm_viewer_always_visible(category)
    if InCombatLockdown and InCombatLockdown() then return end
    local frame = M.get_cdm_viewer_frame(category)
    local visible_setting_enum = Enum and Enum.CooldownViewerVisibleSetting
    local edit_setting_enum = Enum and Enum.EditModeCooldownViewerSetting
    if not (frame and visible_setting_enum and edit_setting_enum) then return end

    local always = visible_setting_enum.Always
    if frame.visibleSetting == always then return end

    local previous_setting = frame.visibleSetting
    local applied = false
    if frame.UpdateSystemSettingValue then
        applied = pcall(frame.UpdateSystemSettingValue, frame, edit_setting_enum.VisibleSetting, always)
    else
        frame.visibleSetting = always
        applied = true
    end
    if not applied then return end

    local state = get_cdm_viewer_state(frame)
    if not state.visible_setting_captured then
        state.visible_setting_captured = true
        state.previous_visible_setting = previous_setting
    end

    if frame.UpdateShownState then
        pcall(frame.UpdateShownState, frame)
    end
end

function M.restore_blizz_cdm_viewer_settings()
    if InCombatLockdown and InCombatLockdown() then
        queue_cdm_setting_restore()
        return
    end

    local visible_setting_enum = Enum and Enum.CooldownViewerVisibleSetting
    local edit_setting_enum = Enum and Enum.EditModeCooldownViewerSetting
    local always = visible_setting_enum and visible_setting_enum.Always
    local setting = edit_setting_enum and edit_setting_enum.VisibleSetting
    if always == nil or setting == nil then return end

    for frame, state in pairs(M._cd_viewer_state or {}) do
        if frame and state and state.visible_setting_captured then
            local previous_setting = state.previous_visible_setting
            if previous_setting ~= nil and frame.visibleSetting == always then
                local restored = false
                if frame.UpdateSystemSettingValue then
                    restored = pcall(frame.UpdateSystemSettingValue, frame, setting, previous_setting)
                else
                    frame.visibleSetting = previous_setting
                    restored = true
                end
                if restored and frame.UpdateShownState then
                    pcall(frame.UpdateShownState, frame)
                end
            end
            state.visible_setting_captured = nil
            state.previous_visible_setting = nil
        end
    end
end

function M.update_blizz_cdm_visibility(category)
    M.ensure_blizz_cdm_loaded()
    local frame = M.get_cdm_viewer_frame(category)
    if not frame then return end

    local hide = M.db and M.db["hide_blizz_cdm_" .. category]
    local state = M._cd_viewer_state and M._cd_viewer_state[frame]
    if not hide and not (state and state.forced_hidden) then return end

    if not state then
        state = get_cdm_viewer_state(frame)
    end

    local function apply_visibility_state()
        local hide = M.db and M.db["hide_blizz_cdm_" .. category]
        if hide then
            state.forced_hidden = true
            if frame.SetAlpha then frame:SetAlpha(0) end
            if frame.EnableMouse then frame:EnableMouse(false) end
            return
        end

        if state.forced_hidden then
            state.forced_hidden = nil
            if (not InCombatLockdown or not InCombatLockdown()) and frame.Show then
                pcall(frame.Show, frame)
            end
            if frame.SetAlpha then frame:SetAlpha(1) end
            if frame.EnableMouse then frame:EnableMouse(true) end
        end
    end

    local needs_hook = hide or state.forced_hidden
    if needs_hook and not state.visibility_hooked then
        state.visibility_hooked = true
        frame:HookScript("OnShow", function()
            apply_visibility_state()
        end)
    end

    -- Do not call Hide() here. Hidden CDM viewers stop producing the live child
    -- aura/cooldown state we read; alpha keeps them active but invisible.
    apply_visibility_state()
end

function M.update_all_blizz_cdm_visibility()
    if not M.CDM_CATEGORIES then return end
    for _, category in ipairs(M.CDM_CATEGORIES) do
        M.update_blizz_cdm_visibility(category)
    end
end

function M.prepare_blizz_cdm_viewer(category)
    if InCombatLockdown and InCombatLockdown() then return end
    M.ensure_blizz_cdm_loaded()
    local frame = M.get_cdm_viewer_frame(category)
    if not frame then return end

    M.ensure_blizz_cdm_viewer_always_visible(category)

    -- Blizzard viewers must be shown while mirrored so they keep producing
    -- child state. Visual suppression is handled below with alpha.
    if frame.Show then
        pcall(frame.Show, frame)
    end
    M.update_blizz_cdm_visibility(category)
end

--#endregion BLIZZARD BUFF/DEBUFF FRAME TOGGLES ================================
