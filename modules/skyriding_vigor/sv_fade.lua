-- Skyriding Vigor fade helpers: alpha transitions and full-charge fade policy.
local _, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

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

function M.cancel_frame_fade(frame)
    if not frame then return end
    if frame._sv_fade_state then
        frame._sv_fade_state = nil
        frame:SetScript("OnUpdate", nil)
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
        signature = signature,
        started_at = GetTime(),
        start_alpha = frame._sv_alpha or (frame.GetAlpha and frame:GetAlpha()) or 1,
        target_alpha = target_alpha,
        duration = duration,
    }
    frame._sv_fade_state = state
    frame:SetScript("OnUpdate", function(self)
        local fade_state = self._sv_fade_state
        if not fade_state then
            self:SetScript("OnUpdate", nil)
            return
        end
        local progress = (GetTime() - fade_state.started_at) / fade_state.duration
        if progress >= 1 then
            set_frame_alpha(self, fade_state.target_alpha)
            self._sv_fade_state = nil
            self:SetScript("OnUpdate", nil)
            return
        end
        local alpha = fade_state.start_alpha + ((fade_state.target_alpha - fade_state.start_alpha) * progress)
        set_frame_alpha(self, alpha)
    end)
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
