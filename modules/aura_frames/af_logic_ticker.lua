-- Visible icon ticker logic for Aura Frames.
-- Keeps timer text, cooldown state, and bar values fresh between aura scans.
local addon_name, addon = ...

local math_max      = math.max
local math_min      = math.min
local GetTime       = GetTime
local issecretvalue = issecretvalue
local C_UnitAuras   = C_UnitAuras
local C_Timer       = C_Timer

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

local clear_timer_text = M.clear_timer_text
local set_bar_minmax_if_changed = M.set_bar_minmax_if_changed
--#region TIMER TICKER =========================================================


local function aura_icon_needs_tick(obj, frame, now)
    if not (obj and obj:IsShown()) then return false end
    if obj.is_test_preview then return true end
    if obj.is_spell_cooldown then return true end

    local is_static_entry = (frame and frame.category == "static") or obj.aura_is_static == true
    if is_static_entry then return false end

    local show_timer_text = frame and frame._show_timer_text
    local show_cooldown_overlay = frame and frame._show_cooldown_overlay == true
    local bar_visible = obj.bar and obj.bar:IsShown()
    if not (bar_visible or (show_timer_text and not show_cooldown_overlay)) then
        return false
    end

    if obj.aura_expiration and obj.aura_expiration > now then return true end
    if obj.aura_scan_time and obj.aura_remaining and not issecretvalue(obj.aura_remaining) and obj.aura_remaining > 0 then
        return true
    end
    return type(obj.aura_index) == "number"
end

local function get_cached_duration_remaining(obj)
    local duration_object = obj and obj.aura_live_duration
    if not (duration_object and type(duration_object.GetRemainingDuration) == "function") then
        return nil
    end
    local ok, remaining = pcall(function()
        return duration_object:GetRemainingDuration()
    end)
    if ok then return remaining end
    obj.aura_live_duration = nil
    return nil
end

function M.frame_needs_visible_icon_tick(frame, now)
    if not (frame and frame:IsVisible() and frame.icons) then return false end
    local display_count = frame._display_count or 0
    if display_count <= 0 then return false end
    local icon_count = #frame.icons
    if display_count > icon_count then display_count = icon_count end
    now = now or GetTime()
    for i = 1, display_count do
        if aura_icon_needs_tick(frame.icons[i], frame, now) then
            return true
        end
    end
    return false
end

function M.any_frame_needs_visible_icon_tick(now)
    local frames_list = M.frames_list
    if not frames_list then return false end
    now = now or GetTime()
    for i = 1, #frames_list do
        if M.frame_needs_visible_icon_tick(frames_list[i], now) then
            return true
        end
    end
    return false
end

function M.stop_visible_icon_ticker()
    local ticker = M._visible_icon_ticker
    if ticker then
        ticker:Cancel()
        M._visible_icon_ticker = nil
    end
end

function M.get_visible_icon_tick_interval()
    local default_interval = M.defaults.aura_visible_icon_tick
        or M.UPDATE_INTERVALS.aura_visible_icon_tick
    local value = M.db and tonumber(M.db.aura_visible_icon_tick) or default_interval
    local range = M.SETTING_RANGES.aura_visible_icon_tick
    local min_interval = range.min
    local max_interval = range.max
    local step = range.step
    value = math_max(min_interval, math_min(max_interval, value))
    value = min_interval + math.floor(((value - min_interval) / step) + 0.5) * step
    return math_max(min_interval, math_min(max_interval, value))
end

function M.ensure_visible_icon_ticker(needs_tick_known)
    if M._visible_icon_ticker then return end
    if not (C_Timer and C_Timer.NewTicker) then return end
    if not needs_tick_known and not M.any_frame_needs_visible_icon_tick() then return end

    M._visible_icon_ticker = C_Timer.NewTicker(M.get_visible_icon_tick_interval(), function()
        if not M.tick_visible_icons() then
            M.stop_visible_icon_ticker()
        end
    end)
end

function M.refresh_visible_icon_ticker()
    if M.any_frame_needs_visible_icon_tick() then
        M.ensure_visible_icon_ticker(true)
    else
        M.stop_visible_icon_ticker()
    end
end

function M.restart_visible_icon_ticker()
    M.stop_visible_icon_ticker()
    M.refresh_visible_icon_ticker()
end

-- Shared ticker update path for all visible aura icon objects.
-- Started on demand and keeps timer/bar text fresh between scans.
function M.tick_visible_icons(now)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        if M.stop_visible_icon_ticker then M.stop_visible_icon_ticker() end
        return false
    end

    now = now or GetTime()
    local db = M.db
    local short_threshold = (db and db.short_threshold) or M.DEFAULT_SHORT_THRESHOLD

    local frames_list = M.frames_list
    if not frames_list then return false end
    local needs_tick = false
    for frame_index = 1, #frames_list do
        local frame = frames_list[frame_index]
        if frame:IsVisible() then
            local is_static_frame = (frame.category == "static")
            local show_timer_text = frame._show_timer_text
            local bar_mode = frame._bar_mode
            local show_cooldown_overlay = frame._show_cooldown_overlay == true
            local display_count = frame._display_count or 0
            local icon_count = #frame.icons
            if display_count > icon_count then
                display_count = icon_count
            end
            for i = 1, display_count do
                local obj = frame.icons[i]
                    if obj:IsShown() then
                    if obj.is_test_preview and M.update_test_preview_state then
                        M.update_test_preview_state(obj, obj.test_preview_show_key or ("show_" .. frame.category), short_threshold, now)
                    end
                    local is_static_entry = is_static_frame or obj.aura_is_static == true
                    if is_static_entry then
                        clear_timer_text(obj.time_text)
                        if obj.bar and obj.bar:IsShown() then
                            set_bar_minmax_if_changed(obj.bar, 0, 1)
                            obj.bar:SetValue(1)
                        end
                    elseif (type(obj.aura_index) == "number") or obj.is_spell_cooldown or obj.is_test_preview then
                        if show_timer_text then
                            if show_cooldown_overlay then
                                if obj.time_text:IsShown() then obj.time_text:Hide() end
                                clear_timer_text(obj.time_text)
                            elseif not obj.time_text:IsShown() then
                                obj.time_text:Show()
                            end
                        else
                            if obj.time_text:IsShown() then obj.time_text:Hide() end
                        end
                        local remaining
                        if obj.aura_expiration and obj.aura_expiration > 0 then
                            remaining = math_max(0, obj.aura_expiration - now)
                        elseif obj.aura_scan_time and obj.aura_remaining
                            and not issecretvalue(obj.aura_remaining)
                            and obj.aura_remaining > 0 then
                            remaining = math_max(0, obj.aura_remaining - (now - obj.aura_scan_time))
                        end
                        local live_remaining
                        local need_live_fallback = (remaining == nil) and (type(obj.aura_index) == "number")
                            and (show_timer_text or (obj.bar and obj.bar:IsShown()))
                        if need_live_fallback then
                            local live_duration = obj.aura_live_duration
                            if live_duration then
                                live_remaining = get_cached_duration_remaining(obj)
                                if live_remaining ~= nil and not issecretvalue(live_remaining) then
                                    remaining = live_remaining
                                end
                            else
                                local ok, result = pcall(C_UnitAuras.GetAuraDuration, "player", obj.aura_index)
                                if ok then live_duration = result end
                                if live_duration then
                                    obj.aura_live_duration = live_duration
                                    live_remaining = get_cached_duration_remaining(obj)
                                    if live_remaining ~= nil and not issecretvalue(live_remaining) then
                                        remaining = live_remaining
                                    end
                                end
                            end
                        end
                        if remaining and remaining > 0 then
                            if M.should_reclassify_aura_category
                                and M.should_reclassify_aura_category(frame.category, remaining, short_threshold, obj.is_test_preview)
                                and M.queue_threshold_reclassification then
                                M.queue_threshold_reclassification()
                            end
                            if show_timer_text and not show_cooldown_overlay then
                                M.set_timer_text(obj.time_text, obj.aura_category or frame.category, remaining, obj.aura_timer_behavior)
                            end
                            if obj.bar and obj.bar:IsShown() then
                                if obj.aura_duration and obj.aura_duration > 0 then
                                    set_bar_minmax_if_changed(obj.bar, 0, obj.aura_duration)
                                end
                                obj.bar:SetValue(remaining)
                            end
                        elseif remaining == 0 then
                            clear_timer_text(obj.time_text)
                            obj.grey_cooldown = false
                        elseif live_remaining ~= nil and issecretvalue(live_remaining) then
                            if show_timer_text and not show_cooldown_overlay then
                                M.set_timer_text(obj.time_text, obj.aura_category or frame.category, live_remaining, obj.aura_timer_behavior)
                            end
                        end
                    end
                    if not needs_tick and aura_icon_needs_tick(obj, frame, now) then
                        needs_tick = true
                    end
                end
            end
        end
    end
    return needs_tick
end

--#endregion TIMER TICKER ======================================================
