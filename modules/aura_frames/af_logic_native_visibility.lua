-- Native Blizzard aura-frame visibility logic for Aura Frames.
-- Shelters BuffFrame and DebuffFrame under an addon-owned hidden parent, and visually suppresses
-- CooldownViewer frames without stopping the child state consumed by Aura Frames.
local addon_name, addon = ...

local InCombatLockdown = InCombatLockdown

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

--#region BLIZZARD BUFF/DEBUFF FRAME TOGGLES ===================================

local blizz_aura_frame_state = setmetatable({}, { __mode = "k" })
local blizz_setting_restore_frame
local blizz_aura_suppressor

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

local function get_blizz_aura_suppressor()
    if blizz_aura_suppressor then return blizz_aura_suppressor end
    blizz_aura_suppressor = CreateFrame("Frame", addon_name .. "AuraFrameSuppressor", UIParent)
    blizz_aura_suppressor:Hide()
    return blizz_aura_suppressor
end

local function queue_blizz_setting_restore()
    if blizz_setting_restore_frame then
        blizz_setting_restore_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    blizz_setting_restore_frame = CreateFrame("Frame")
    blizz_setting_restore_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    blizz_setting_restore_frame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        M.apply_blizz_aura_frame_settings()
        M.restore_blizz_cdm_viewer_settings()
    end)
end

local function set_blizz_frame_state(frame, hide)
    if not (frame and frame.GetParent and frame.SetParent) then return end
    local state = get_blizz_aura_frame_state(frame)

    if hide then
        if state.suppressed then return end
        if InCombatLockdown and InCombatLockdown() then
            queue_blizz_setting_restore()
            return
        end

        local original_parent = frame:GetParent() or UIParent
        local suppressor = get_blizz_aura_suppressor()
        local changed, err = pcall(frame.SetParent, frame, suppressor)
        if not changed or frame:GetParent() ~= suppressor then
            state.suppression_error = tostring(err or "parent unchanged")
            return
        end

        state.suppressed = true
        state.original_parent = original_parent
        state.suppression_error = nil
        return
    end

    if not state.suppressed then return end
    if InCombatLockdown and InCombatLockdown() then
        queue_blizz_setting_restore()
        return
    end

    if frame:GetParent() == blizz_aura_suppressor then
        local restored, err = pcall(frame.SetParent, frame, state.original_parent or UIParent)
        if not restored then
            state.suppression_error = tostring(err)
            return
        end
    end

    state.suppressed = nil
    state.original_parent = nil
    state.suppression_error = nil
end

function M.set_blizz_buffs_enabled(enabled)
    set_blizz_frame_state(BuffFrame, not enabled)
end

function M.set_blizz_debuffs_enabled(enabled)
    set_blizz_frame_state(DebuffFrame, not enabled)
end

function M.restore_blizz_aura_frame_settings()
    set_blizz_frame_state(BuffFrame, false)
    set_blizz_frame_state(DebuffFrame, false)
end

function M.apply_blizz_aura_frame_settings()
    if M._module_runtime_enabled and M.db then
        M.set_blizz_buffs_enabled(M.db.enable_blizz_buffs)
        M.set_blizz_debuffs_enabled(M.db.enable_blizz_debuffs)
        return
    end
    M.restore_blizz_aura_frame_settings()
end

function M.get_blizz_aura_suppression_status()
    local count = 0
    local last_error
    for frame, state in pairs(blizz_aura_frame_state) do
        if state.suppressed and frame:GetParent() == blizz_aura_suppressor then
            count = count + 1
        end
        if state.suppression_error then
            last_error = state.suppression_error
        end
    end
    return count, last_error
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
        queue_blizz_setting_restore()
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
