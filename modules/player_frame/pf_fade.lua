-- Player Frame OOC fade runtime: time-based fade with pass-through health curve gating.


--#region FILE CONTENTS ======================================================

local _, addon = ...
addon.player_frame = addon.player_frame or { controls = {}, frames = {} }

local M = addon.player_frame
local F = M.fade or {}
M.fade = F

local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local pcall = pcall
local C_Timer = C_Timer
local GetTime = GetTime

local ALPHA_EPSILON       = 0.001
local TIME_EPSILON        = 0.001
local FADE_TICK_INTERVAL  = (addon.UPDATE_INTERVALS and (addon.UPDATE_INTERVALS.player_frame_fade_tick or addon.UPDATE_INTERVALS.tenth_sec)) or 0.1
local HEALTH_DEBOUNCE_DELAY = FADE_TICK_INTERVAL
local HEALTH_RELEASE_CAP  = 0.99
local RELEASE_25_MIN      = 0.06
local RELEASE_25_MAX      = 0.30
local RELEASE_50_MIN      = 0.20
local RELEASE_50_MAX      = 0.60
local RELEASE_75_MIN      = 0.50
local RELEASE_75_MAX      = 0.90

local STATE_IDLE   = "idle"
local STATE_COMBAT = "combat"
local STATE_DELAY  = "delay"
local STATE_FADING = "fading"
local STATE_FADED  = "faded"

local state             = STATE_IDLE
local playerInCombat    = (InCombatLockdown and InCombatLockdown()) or false
local fadeDelayTimer    = nil
local fadeTicker        = nil
local queuedHealthTimer = nil
local queuedApply       = false
local pfHookApplied     = false
local currentBaseAlpha  = 1
---@type LuaCurveObject?
local healthCurve       = nil
local curveBaseAlpha    = nil
local curveThreshold    = nil
local curveReleaseSpeed = nil

local DEFAULTS = M.FADE_DEFAULTS
local RANGES = M.FADE_SETTING_RANGES

local function is_runtime_enabled()
    return not addon.is_module_enabled or addon.is_module_enabled(M.MODULE_KEY)
end

local function refresh_combat_state()
    if InCombatLockdown then
        playerInCombat = InCombatLockdown() or false
    end
    return playerInCombat
end

local function get_clamped_db(db, key)
    local range = RANGES[key]
    if M.get_clamped_fade_value then
        return M.get_clamped_fade_value(db, key, range.min, range.max)
    end

    local v = tonumber(db and db[key]) or DEFAULTS[key]
    return math_max(range.min, math_min(range.max, v))
end

local function get_fade_delay(db)  return get_clamped_db(db, "fade_delay") end
local function get_fade_length(db) return get_clamped_db(db, "fade_length") end
local function get_fade_alpha(db)  return get_clamped_db(db, "fade_alpha") end
local function get_threshold(db)   return get_clamped_db(db, "health_visible_threshold") end
local function get_release_speed(db) return get_clamped_db(db, "health_release_speed") / 100 end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function get_health_curve()
    if healthCurve then return healthCurve end
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end
    healthCurve = C_CurveUtil.CreateCurve()
    healthCurve:SetType(Enum.LuaCurveType.Linear)
    return healthCurve
end

local function clear_health_curve_cache()
    curveBaseAlpha = nil
    curveThreshold = nil
    curveReleaseSpeed = nil
end

local function get_health_gated_alpha(db, base_alpha)
    local threshold = get_threshold(db)
    if threshold <= 0 then return base_alpha end
    if playerInCombat or not UnitHealthPercent then return 1 end

    local curve = get_health_curve()
    if not curve then return 1 end

    local release_start = math_min(threshold / 100, HEALTH_RELEASE_CAP)
    local release_span  = 1 - release_start
    local alpha_span    = 1 - base_alpha
    local release_speed = get_release_speed(db)
    if base_alpha ~= curveBaseAlpha or threshold ~= curveThreshold or release_speed ~= curveReleaseSpeed then
        local release_25 = lerp(RELEASE_25_MIN, RELEASE_25_MAX, release_speed)
        local release_50 = lerp(RELEASE_50_MIN, RELEASE_50_MAX, release_speed)
        local release_75 = lerp(RELEASE_75_MIN, RELEASE_75_MAX, release_speed)

        curve:ClearPoints()
        curve:AddPoint(0, 1)
        curve:AddPoint(release_start, 1)
        curve:AddPoint(release_start + (release_span * 0.25), 1 - (alpha_span * release_25))
        curve:AddPoint(release_start + (release_span * 0.50), 1 - (alpha_span * release_50))
        curve:AddPoint(release_start + (release_span * 0.75), 1 - (alpha_span * release_75))
        curve:AddPoint(1, base_alpha)

        curveBaseAlpha = base_alpha
        curveThreshold = threshold
        curveReleaseSpeed = release_speed
    end

    local ok, alpha = pcall(UnitHealthPercent, "player", true, curve)
    if ok then return alpha end
    return 1
end

local function set_base_alpha(db, base_alpha, use_health_gate)
    if not PlayerFrame then return end
    currentBaseAlpha = base_alpha
    if use_health_gate then
        local ok = pcall(PlayerFrame.SetAlpha, PlayerFrame, get_health_gated_alpha(db, base_alpha))
        if not ok then
            PlayerFrame:SetAlpha(1)
        end
    else
        PlayerFrame:SetAlpha(base_alpha)
    end
end

local function stop_animation()
    if fadeTicker then
        fadeTicker:Cancel()
        fadeTicker = nil
    end
end

local function cancel_delay()
    if fadeDelayTimer then
        fadeDelayTimer:Cancel()
        fadeDelayTimer = nil
    end
end

local function cancel_health_update()
    if queuedHealthTimer then
        queuedHealthTimer:Cancel()
        queuedHealthTimer = nil
    end
end

local function restore_combat_state(db)
    cancel_delay()
    stop_animation()
    cancel_health_update()
    state = STATE_COMBAT
    set_base_alpha(db, 1, false)
end

local function begin_fade(db, force_visible_start)
    stop_animation()
    cancel_delay()
    state = STATE_FADING

    local target = get_fade_alpha(db)
    local length = get_fade_length(db)
    local start_alpha = force_visible_start and 1 or currentBaseAlpha

    if length <= TIME_EPSILON then
        set_base_alpha(db, target, true)
        state = STATE_FADED
        return
    end

    set_base_alpha(db, start_alpha, not force_visible_start)

    if math_abs(target - start_alpha) <= ALPHA_EPSILON then
        set_base_alpha(db, target, true)
        state = STATE_FADED
        return
    end

    local start_time = GetTime()
    fadeTicker = C_Timer.NewTicker(FADE_TICK_INTERVAL, function()
        if not PlayerFrame or playerInCombat then
            stop_animation()
            state = playerInCombat and STATE_COMBAT or STATE_IDLE
            if playerInCombat then set_base_alpha(db, 1, false) end
            return
        end

        local elapsed = math_min(length, GetTime() - start_time)
        local progress = elapsed / length
        local base_alpha = start_alpha + ((target - start_alpha) * progress)
        set_base_alpha(db, base_alpha, true)

        if elapsed >= length then
            stop_animation()
            set_base_alpha(db, target, true)
            state = STATE_FADED
        end
    end)
end

local function on_delay_expired(db, force_visible_start)
    if playerInCombat or not is_runtime_enabled() or not (db and db.fade_out_of_combat) then
        state = playerInCombat and STATE_COMBAT or STATE_IDLE
        set_base_alpha(db, 1, false)
        return
    end

    begin_fade(db, force_visible_start)
end

local function queue_apply(db)
    if queuedApply then return end
    queuedApply = true
    C_Timer.After(0, function()
        queuedApply = false
        on_delay_expired(db, false)
    end)
end

function F.stop_transition()
    cancel_delay()
    stop_animation()
    cancel_health_update()
    state = STATE_IDLE
end

function F.on_enter_combat()
    playerInCombat = true
    cancel_delay()
    stop_animation()
    cancel_health_update()
    state = STATE_COMBAT
    set_base_alpha(nil, 1, false)
end

function F.on_leave_combat(db)
    playerInCombat = false
    cancel_delay()
    stop_animation()
    set_base_alpha(db, 1, false)

    if not (db and db.fade_out_of_combat) then
        state = STATE_IDLE
        return
    end

    local delay = get_fade_delay(db)
    if delay > TIME_EPSILON then
        state = STATE_DELAY
        fadeDelayTimer = C_Timer.NewTimer(delay, function()
            fadeDelayTimer = nil
            on_delay_expired(db, true)
        end)
    else
        on_delay_expired(db, true)
    end
end

function F.on_health_update(db)
    if playerInCombat or not (db and db.fade_out_of_combat) then return end
    if state == STATE_DELAY or state == STATE_FADING then return end

    if state == STATE_FADED then
        set_base_alpha(db, get_fade_alpha(db), true)
    end
end

function F.apply(db)
    if not PlayerFrame then return end

    refresh_combat_state()

    if not (db and db.fade_out_of_combat) then
        cancel_delay()
        stop_animation()
        cancel_health_update()
        state = STATE_IDLE
        set_base_alpha(db, 1, false)
        return
    end

    if not pfHookApplied then
        PlayerFrame:HookScript("OnShow", function()
            M.update_player_frame()
        end)
        pfHookApplied = true
    end

    if playerInCombat then
        cancel_delay()
        stop_animation()
        cancel_health_update()
        state = STATE_COMBAT
        set_base_alpha(db, 1, false)
        return
    end

    if state == STATE_DELAY or state == STATE_FADING then return end

    queue_apply(db)
end

function F.on_threshold_changed(db)
    clear_health_curve_cache()

    if refresh_combat_state() then
        restore_combat_state(db)
        return
    end

    stop_animation()
    if state ~= STATE_DELAY then
        state = STATE_IDLE
        if db and db.fade_out_of_combat and not playerInCombat then
            queue_apply(db)
        end
    end
end

function F.on_fade_setting_changed(db, key)
    if key == "health_visible_threshold" then
        F.on_threshold_changed(db)
        return
    end

    if state == STATE_FADING then
        if refresh_combat_state() then
            restore_combat_state(db)
            return
        end

        stop_animation()
        state = STATE_IDLE
        if db and db.fade_out_of_combat and not playerInCombat then
            queue_apply(db)
        end
    end
end

function F.queue_health_update(get_db)
    local db = get_db and get_db()
    if playerInCombat or not (db and db.fade_out_of_combat) then return end
    if state ~= STATE_FADED then return end
    if get_threshold(db) <= 0 then return end

    cancel_health_update()
    queuedHealthTimer = C_Timer.NewTimer(HEALTH_DEBOUNCE_DELAY, function()
        queuedHealthTimer = nil
        F.on_health_update(get_db and get_db())
    end)
end

function F.get_runtime_status()
    return {
        state = state,
        player_in_combat = playerInCombat == true,
        fade_delay_timer = fadeDelayTimer ~= nil,
        fade_ticker = fadeTicker ~= nil,
        queued_health_timer = queuedHealthTimer ~= nil,
        queued_apply = queuedApply == true,
    }
end

--#endregion FILE CONTENTS ===================================================
