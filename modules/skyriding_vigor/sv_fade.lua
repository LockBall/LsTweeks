-- Skyriding Vigor fade helpers: alpha transitions and full-charge fade policy.
local _, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local CreateFrame = CreateFrame
local GetTime = GetTime
local tonumber = tonumber

--#region ALPHA PRIMITIVES =====================================================

local function set_frame_alpha(frame, alpha)
    if frame._sv_alpha == alpha then return end
    frame:SetAlpha(alpha)
    frame._sv_alpha = alpha
end

function M.set_frame_alpha(frame, alpha)
    if not frame then return end
    set_frame_alpha(frame, alpha)
end

local function get_fade_driver(frame)
    local driver = frame._sv_fade_driver
    if driver then return driver end

    -- Keep fade updates separate from the main frame drag callback.
    driver = CreateFrame("Frame", nil, frame)
    driver:Hide()
    frame._sv_fade_driver = driver
    return driver
end

function M.cancel_frame_fade(frame)
    if not frame then return end
    local driver = frame._sv_fade_driver
    if frame._sv_fade_state or driver then
        frame._sv_fade_state = nil
        if driver then
            driver._sv_fade_state = nil
            driver:SetScript("OnUpdate", nil)
            driver:Hide()
        end
    end
end

--#endregion ALPHA PRIMITIVES ==================================================

--#region FADE ANIMATION =======================================================

function M.fade_frame_alpha(frame, target_alpha, duration)
    if not frame then return end
    duration = tonumber(duration) or 0
    local signature = tostring(target_alpha) .. ":" .. tostring(duration)
    local state = frame._sv_fade_state
    if state and state.signature == signature then return end

    M.cancel_frame_fade(frame)
    if duration <= 0 then
        set_frame_alpha(frame, target_alpha)
        return
    end
    if frame._sv_alpha == target_alpha then return end

    state = {
        frame = frame,
        signature = signature,
        started_at = GetTime(),
        start_alpha = frame._sv_alpha or (frame.GetAlpha and frame:GetAlpha()) or 1,
        target_alpha = target_alpha,
        duration = duration,
    }
    frame._sv_fade_state = state
    local driver = get_fade_driver(frame)
    driver._sv_fade_state = state
    driver:SetScript("OnUpdate", function(self)
        local fade_state = self._sv_fade_state
        if not fade_state then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        local progress = (GetTime() - fade_state.started_at) / fade_state.duration
        if progress >= 1 then
            set_frame_alpha(fade_state.frame, fade_state.target_alpha)
            fade_state.frame._sv_fade_state = nil
            self._sv_fade_state = nil
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        local alpha = fade_state.start_alpha + ((fade_state.target_alpha - fade_state.start_alpha) * progress)
        set_frame_alpha(fade_state.frame, alpha)
    end)
    driver:Show()
end

function M.restore_frame_alpha(frame)
    M.cancel_frame_fade(frame)
    M.set_frame_alpha(frame, 1)
end

--#endregion FADE ANIMATION ====================================================

--#region FULL-CHARGE POLICY ===================================================

function M.apply_full_charge_fade(frame, db, charges_full, is_active_flight)
    local defaults = M.DEFAULTS or {}
    if db.fade_when_full and not M._fill_test_enabled and not db.move_mode and charges_full and not is_active_flight then
        M.fade_frame_alpha(frame, db.fade_alpha or defaults.fade_alpha or 0.25, db.fade_length or defaults.fade_length or 3)
    else
        M.restore_frame_alpha(frame)
    end
end

--#endregion FULL-CHARGE POLICY ================================================
