-- Player Frame OOC fade runtime: combat transitions, alpha fade, and health curve gate.
local _, addon = ...
addon.player_frame = addon.player_frame or {
    controls = {},
    frames = {}
}

local M = addon.player_frame
local F = M.fade or {}
M.fade = F

local ALPHA_EPSILON = 0.001
local HEALTH_UPDATE_DELAY = (addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.tenth_sec) or 0.1

local fadeDelayEndTime = 0
local fadeDelayTimer = nil
local fadeUpdateFrame = nil
local fadeActive = false
local queuedHealthFadeTimer = nil
local lastDebugMessage = nil
local lastDebugTime = 0
local currentFadeBaseAlpha = 1
local healthReleaseFadeRestartUsed = false
local playerInCombat = InCombatLockdown and InCombatLockdown() or false
---@type LuaCurveObject?
local healthAlphaCurve = nil
local playerFrameHookApplied = false

local function get_defaults()
    return M.FADE_DEFAULTS or {}
end

local function get_clamped_fade_value(db, key, min_value, max_value)
    local defaults = get_defaults()
    local value = tonumber(db and db[key]) or defaults[key]
    return math.max(min_value, math.min(max_value, value))
end

local function get_fade_delay(db)
    return get_clamped_fade_value(db, "fade_delay", 0, 5)
end

local function get_fade_length(db)
    return get_clamped_fade_value(db, "fade_length", 0, 10)
end

local function get_fade_alpha(db)
    return get_clamped_fade_value(db, "fade_alpha", 0.1, 1.0)
end

local function get_health_visible_threshold(db)
    return get_clamped_fade_value(db, "health_visible_threshold", 0, 100)
end

local function debug_fade(db, message)
    if not (db and db.debug_fade) then return end
    local now = GetTime and GetTime() or 0
    if message == lastDebugMessage and (now - lastDebugTime) < 1 then return end
    lastDebugMessage = message
    lastDebugTime = now
    print("|cff33ff99LsTweeks PlayerFrame:|r " .. message)
end

local function is_player_in_combat()
    return playerInCombat or (InCombatLockdown and InCombatLockdown())
end

local function setup_player_frame_on_show_hook(frame)
    if playerFrameHookApplied or not frame then return end

    frame:HookScript("OnShow", function()
        M.update_player_frame()
    end)
    playerFrameHookApplied = true
end

function F.stop_transition()
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

local function reset_fade_progress_to_visible()
    currentFadeBaseAlpha = 1
end

local function reset_health_release_restart()
    healthReleaseFadeRestartUsed = false
end

---@return LuaCurveObject?
local function get_health_alpha_curve()
    if healthAlphaCurve then return healthAlphaCurve end
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end

    healthAlphaCurve = C_CurveUtil.CreateCurve()
    healthAlphaCurve:SetType(Enum.LuaCurveType.Step)
    return healthAlphaCurve
end

---@param target_alpha number
---@return number
local function get_health_gated_alpha(db, target_alpha)
    local threshold = get_health_visible_threshold(db)
    if threshold <= 0 then return target_alpha end
    if is_player_in_combat() or not UnitHealthPercent then return 1 end

    local curve = get_health_alpha_curve()
    if not curve then return 1 end

    curve:ClearPoints()
    curve:AddPoint(0, 1)
    curve:AddPoint(threshold / 100, target_alpha)
    curve:AddPoint(1, target_alpha)

    local ok, alpha = pcall(UnitHealthPercent, "player", true, curve)
    if ok and type(alpha) == "number" then return alpha end
    return 1
end

local function set_player_frame_alpha(db, base_alpha, use_health_gate)
    currentFadeBaseAlpha = base_alpha
    local applied_alpha = base_alpha
    if use_health_gate then
        applied_alpha = get_health_gated_alpha(db, base_alpha)
    end

    PlayerFrame:SetAlpha(applied_alpha)
    return applied_alpha
end

function F.set_visible(db)
    if not PlayerFrame then return end
    set_player_frame_alpha(db, 1, false)
end

local function is_alpha_held_visible(applied_alpha, base_alpha)
    local ok, is_held = pcall(function()
        return base_alpha < (1 - ALPHA_EPSILON) and applied_alpha >= (1 - ALPHA_EPSILON)
    end)
    return ok and is_held
end

local function get_fade_update_frame()
    if fadeUpdateFrame then return fadeUpdateFrame end
    fadeUpdateFrame = CreateFrame("Frame")
    return fadeUpdateFrame
end

function F.begin_delay(db)
    F.stop_transition()
    if not (db and db.fade_out_of_combat) then return false end

    local delay = get_fade_delay(db)
    if delay <= 0 then return false end

    fadeDelayEndTime = GetTime() + delay
    if C_Timer and C_Timer.NewTimer then
        fadeDelayTimer = C_Timer.NewTimer(delay, function()
            fadeDelayTimer = nil
            fadeDelayEndTime = 0
            M.update_player_frame()
        end)
    end
    return true
end

local function apply_ooc_fade_alpha(db, animate, force_visible_start)
    local alpha = get_fade_alpha(db)
    local length = get_fade_length(db)
    local starting_alpha = force_visible_start and 1 or currentFadeBaseAlpha

    if not animate or length <= 0 or (not force_visible_start and math.abs(currentFadeBaseAlpha - alpha) <= ALPHA_EPSILON) then
        F.stop_transition()
        local applied_alpha = set_player_frame_alpha(db, alpha, true)
        if is_alpha_held_visible(applied_alpha, alpha) then
            reset_fade_progress_to_visible()
        end
        return
    end

    if force_visible_start then
        set_player_frame_alpha(db, 1, true)
    end

    currentFadeBaseAlpha = starting_alpha
    local current_alpha = starting_alpha
    local fade_elapsed = 0
    local last_update_time = GetTime()
    local update_frame = get_fade_update_frame()

    fadeActive = true
    update_frame:SetScript("OnUpdate", function(self)
        if not fadeActive or not PlayerFrame then
            self:SetScript("OnUpdate", nil)
            return
        end

        if is_player_in_combat() then
            F.stop_transition()
            F.set_visible(db)
            return
        end

        local now = GetTime()
        local candidate_elapsed = math.min(length, fade_elapsed + (now - last_update_time))
        last_update_time = now

        local progress = math.min(1, candidate_elapsed / length)
        local fade_alpha = current_alpha + ((alpha - current_alpha) * progress)
        local applied_alpha = set_player_frame_alpha(db, fade_alpha, true)

        if is_alpha_held_visible(applied_alpha, fade_alpha) then
            reset_fade_progress_to_visible()
            current_alpha = 1
            fade_elapsed = 0
            return
        end

        fade_elapsed = candidate_elapsed
        if progress >= 1 then
            fadeActive = false
            self:SetScript("OnUpdate", nil)
            set_player_frame_alpha(db, alpha, true)
        end
    end)
end

function F.apply(db)
    if not PlayerFrame then return end

    setup_player_frame_on_show_hook(PlayerFrame)
    if is_player_in_combat() or not (db and db.fade_out_of_combat) then
        F.stop_transition()
        reset_health_release_restart()
        F.set_visible(db)
        debug_fade(db, "fade blocked: combat or OOC fade disabled")
        return
    end

    if GetTime() < fadeDelayEndTime then
        F.set_visible(db)
        debug_fade(db, format("fade waiting: delay %.1fs remaining", fadeDelayEndTime - GetTime()))
        return
    end

    debug_fade(db, "fade allowed: applying curve health gate")
    apply_ooc_fade_alpha(db, true)
end

function F.update_health(force_visible_start, db)
    if not (PlayerFrame and db and db.fade_out_of_combat) then return end
    if is_player_in_combat() or GetTime() < fadeDelayEndTime then return end
    if fadeActive then return end
    if force_visible_start then
        local alpha = get_fade_alpha(db)
        if healthReleaseFadeRestartUsed or math.abs(currentFadeBaseAlpha - alpha) > ALPHA_EPSILON then return end
        healthReleaseFadeRestartUsed = true
    end

    apply_ooc_fade_alpha(db, true, force_visible_start)
end

function F.queue_health_update(get_db)
    if queuedHealthFadeTimer then
        queuedHealthFadeTimer:Cancel()
        queuedHealthFadeTimer = nil
    end

    if C_Timer and C_Timer.NewTimer then
        queuedHealthFadeTimer = C_Timer.NewTimer(HEALTH_UPDATE_DELAY, function()
            queuedHealthFadeTimer = nil
            F.update_health(true, get_db and get_db())
        end)
        return
    end

    F.update_health(true, get_db and get_db())
end

function F.on_threshold_changed()
    F.stop_transition()
    reset_fade_progress_to_visible()
    reset_health_release_restart()
end

function F.on_enter_combat(db)
    playerInCombat = true
    F.stop_transition()
    reset_health_release_restart()
    F.set_visible(db)
end

function F.on_leave_combat(db)
    playerInCombat = false
    reset_health_release_restart()
    local delay_started = F.begin_delay(db)
    F.set_visible(db)
    if not delay_started then
        M.update_player_frame()
    end
end
