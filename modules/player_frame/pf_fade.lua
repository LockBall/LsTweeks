-- Player Frame OOC fade runtime: state machine for combat/delay/fade/health-threshold transitions.
-- Health gate uses UnitHealthPercent + a step curve; health is only evaluated between fade states, never inside the animation loop.
local _, addon = ...
addon.player_frame = addon.player_frame or { controls = {}, frames = {} }

local M = addon.player_frame
local F = M.fade or {}
M.fade = F

local math_min = math.min
local math_max = math.max

local ALPHA_EPSILON       = 0.001
local HEALTH_UPDATE_DELAY = (addon.UPDATE_INTERVALS and addon.UPDATE_INTERVALS.tenth_sec) or 0.1

local STATE_IDLE        = "idle"
local STATE_COMBAT      = "combat"
local STATE_DELAY       = "delay"
local STATE_WAIT_HEALTH = "wait_health"
local STATE_FADING      = "fading"
local STATE_FADED       = "faded"

local state             = STATE_IDLE
local playerInCombat    = (InCombatLockdown and InCombatLockdown()) or false
local fadeDelayTimer    = nil
local fadeTicker        = nil
local queuedHealthTimer = nil
local pfHookApplied              = false
---@type LuaCurveObject?
local healthCurve                = nil
local lastKnownBelowThreshold    = false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get_defaults()
    return M.FADE_DEFAULTS or {}
end

local function get_clamped_db(db, key, lo, hi)
    local defaults = get_defaults()
    local v = tonumber(db and db[key]) or defaults[key]
    return math_max(lo, math_min(hi, v))
end

local function get_fade_delay(db)  return get_clamped_db(db, "fade_delay",              0,  5) end
local function get_fade_length(db) return get_clamped_db(db, "fade_length",             0, 10) end
local function get_fade_alpha(db)  return get_clamped_db(db, "fade_alpha",            0.1, 1.0) end
local function get_threshold(db)   return get_clamped_db(db, "health_visible_threshold", 0, 100) end

local function set_alpha(a)
    if PlayerFrame then
        PlayerFrame:SetAlpha(a)
    end
end

local function get_health_curve()
    if healthCurve then return healthCurve end
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then
        return nil
    end
    healthCurve = C_CurveUtil.CreateCurve()
    return healthCurve
end

-- Returns true when health is below threshold.
-- Uses UnitHealthPercent + a three-point floor-step curve:
--   (0, 1) → (threshold/100, 0) → (1, 0)
-- Floor step returns the value at the previous keypoint, so health in [0, threshold)
-- maps to 1 and health at/above threshold maps to 0. No addon arithmetic on health.
-- Falls back to true (keep visible) when the result is unavailable or secret.
local function is_health_below_threshold(db)
    local threshold = get_threshold(db)
    if threshold <= 0 then return false end
    if not UnitHealthPercent then return true end

    local curve = get_health_curve()
    if not curve then return true end

    -- Four-point curve that works regardless of interpolation mode (linear,
    -- floor-step, ceiling-step): flat segment at 1 from health 0 to just below
    -- threshold, then drops to 0 at threshold. Linear stays flat; floor-step
    -- returns the 1 from the previous keypoint; ceiling-step sees the 1 at
    -- the next keypoint for all health below threshold - epsilon.
    local t = threshold / 100
    curve:SetType(Enum.LuaCurveType.Step)
    curve:ClearPoints()
    curve:AddPoint(0,         1)
    curve:AddPoint(t - 0.001, 1)
    curve:AddPoint(t,         0)
    curve:AddPoint(1,         0)

    local ok, result = pcall(UnitHealthPercent, "player", true, curve)
    if not ok or type(result) ~= "number" then return lastKnownBelowThreshold end
    local ok2, below = pcall(function() return result > 0.5 end)
    if not ok2 then return lastKnownBelowThreshold end
    lastKnownBelowThreshold = below
    return below
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

-- ---------------------------------------------------------------------------
-- Core transitions
-- ---------------------------------------------------------------------------

-- begin_fade: always starts from full alpha and animates to target_alpha.
-- Cancels any pending delay or running animation before starting.
local function begin_fade(db)
    stop_animation()
    cancel_delay()
    state = STATE_FADING

    local target = get_fade_alpha(db)
    local length = get_fade_length(db)

    if length <= ALPHA_EPSILON then
        set_alpha(target)
        state = STATE_FADED
        return
    end

    set_alpha(1)

    local elapsed = 0
    fadeTicker = C_Timer.NewTicker(HEALTH_UPDATE_DELAY, function()
        if not PlayerFrame or playerInCombat then
            stop_animation()
            state = playerInCombat and STATE_COMBAT or STATE_IDLE
            if playerInCombat then set_alpha(1) end
            return
        end

        elapsed = math_min(length, elapsed + HEALTH_UPDATE_DELAY)

        if elapsed >= length then
            stop_animation()
            set_alpha(target)
            state = STATE_FADED
        else
            set_alpha(1 + (target - 1) * (elapsed / length))
        end
    end)
end

-- on_delay_expired: evaluate health after post-combat delay and either start
-- fading or wait for health to recover.
local function on_delay_expired(db)
    if playerInCombat or not (db and db.fade_out_of_combat) then
        state = STATE_IDLE
        set_alpha(1)
        return
    end
    if is_health_below_threshold(db) then
        state = STATE_WAIT_HEALTH
        -- alpha already 1 from on_leave_combat or earlier set_alpha
    else
        begin_fade(db)
    end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function F.stop_transition()
    cancel_delay()
    stop_animation()
    state = STATE_IDLE
end

function F.on_enter_combat()
    playerInCombat = true
    cancel_delay()
    stop_animation()
    state = STATE_COMBAT
    set_alpha(1)
end

function F.on_leave_combat(db)
    playerInCombat = false
    cancel_delay()
    stop_animation()
    set_alpha(1)

    if not (db and db.fade_out_of_combat) then
        state = STATE_IDLE
        return
    end

    local delay = get_fade_delay(db)
    if delay > ALPHA_EPSILON then
        state = STATE_DELAY
        if C_Timer and C_Timer.NewTimer then
            fadeDelayTimer = C_Timer.NewTimer(delay, function()
                fadeDelayTimer = nil
                on_delay_expired(db)
            end)
        else
            on_delay_expired(db)
        end
    else
        on_delay_expired(db)
    end
end

-- Called from debounced UNIT_HEALTH / UNIT_MAXHEALTH events.
-- Health is only evaluated in states where fading is relevant and the delay has elapsed.
function F.on_health_update(db)
    if playerInCombat or not (db and db.fade_out_of_combat) then return end

    if state == STATE_DELAY then
        -- Keep lastKnownBelowThreshold current during the post-combat delay so the
        -- fallback is accurate when the delay timer fires.
        is_health_below_threshold(db)
        return
    end

    if state == STATE_WAIT_HEALTH then
        if not is_health_below_threshold(db) then
            begin_fade(db)
        end

    elseif state == STATE_FADED then
        if is_health_below_threshold(db) then
            state = STATE_WAIT_HEALTH
            set_alpha(1)
        else
            set_alpha(get_fade_alpha(db))
        end

    elseif state == STATE_FADING then
        if is_health_below_threshold(db) then
            stop_animation()
            state = STATE_WAIT_HEALTH
            set_alpha(1)
        end
        -- health OK: let animation continue
    end
    -- STATE_DELAY: delay timer owns the transition, health ignored until it fires
    -- STATE_COMBAT / STATE_IDLE: no fade action
end

-- Called from M.update_player_frame() on settings changes, PLAYER_ENTERING_WORLD,
-- on_reset_complete, and the PlayerFrame OnShow hook.
function F.apply(db)
    if not PlayerFrame then return end

    if not pfHookApplied then
        PlayerFrame:HookScript("OnShow", function()
            M.update_player_frame()
        end)
        pfHookApplied = true
    end

    if not (db and db.fade_out_of_combat) then
        cancel_delay()
        stop_animation()
        state = STATE_IDLE
        set_alpha(1)
        return
    end

    if playerInCombat then
        cancel_delay()
        stop_animation()
        state = STATE_COMBAT
        set_alpha(1)
        return
    end

    -- OOC, fade enabled.
    -- Delay and health-wait states manage themselves; don't interrupt them here.
    if state == STATE_DELAY or state == STATE_WAIT_HEALTH then return end

    -- All other states (IDLE, COMBAT, FADING, FADED): re-evaluate.
    -- Deferred to next frame via C_Timer to escape potentially tainted event context;
    -- health APIs return secret values when called from tainted execution.
    C_Timer.After(0, function()
        on_delay_expired(db)
    end)
end

-- Called from set_player_frame_setting before M.update_player_frame() when the
-- health threshold slider changes; resets state so apply() re-evaluates immediately.
function F.on_threshold_changed()
    lastKnownBelowThreshold = false
    stop_animation()
    if state ~= STATE_DELAY then
        state = STATE_IDLE
    end
end

-- Debounces rapid UNIT_HEALTH / UNIT_MAXHEALTH events.
function F.queue_health_update(get_db)
    if queuedHealthTimer then
        queuedHealthTimer:Cancel()
        queuedHealthTimer = nil
    end
    if C_Timer and C_Timer.NewTimer then
        queuedHealthTimer = C_Timer.NewTimer(HEALTH_UPDATE_DELAY, function()
            queuedHealthTimer = nil
            F.on_health_update(get_db and get_db())
        end)
    else
        F.on_health_update(get_db and get_db())
    end
end

function F.get_debug_state()
    return state, playerInCombat
end
