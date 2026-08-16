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

function M.restore_blizz_cdm_viewer_settings()
    for frame, state in pairs(M._cd_viewer_state or {}) do
        if frame and state and state.forced_hidden then
            state.forced_hidden = nil
            if frame.SetAlpha then frame:SetAlpha(1) end
            if frame.EnableMouse then frame:EnableMouse(true) end
        end
    end
end

function M.update_blizz_cdm_visibility(category)
    local hide = M.db and M.db["hide_blizz_cdm_" .. category]
    local existing_frame = M.get_cdm_viewer_frame(category)
    local existing_state = existing_frame and M._cd_viewer_state and M._cd_viewer_state[existing_frame]
    if not hide and not (existing_state and existing_state.forced_hidden) then return end

    M.ensure_blizz_cdm_loaded()
    local frame = M.get_cdm_viewer_frame(category)
    if not frame then return end

    local state = M._cd_viewer_state and M._cd_viewer_state[frame]
    if not hide and not (state and state.forced_hidden) then return end

    if not state then
        state = get_cdm_viewer_state(frame)
    end

    if hide then
        state.forced_hidden = true
        if frame.SetAlpha then frame:SetAlpha(0) end
        if frame.EnableMouse then frame:EnableMouse(false) end
    elseif state.forced_hidden then
        state.forced_hidden = nil
        if frame.SetAlpha then frame:SetAlpha(1) end
        if frame.EnableMouse then frame:EnableMouse(true) end
    end
end

function M.update_all_blizz_cdm_visibility()
    if not M.CDM_CATEGORIES then return end
    for _, category in ipairs(M.CDM_CATEGORIES) do
        M.update_blizz_cdm_visibility(category)
    end
end

--#endregion BLIZZARD BUFF/DEBUFF FRAME TOGGLES ================================
