-- Runtime loop for the aura frames module: drives the per-tick timer countdown and the per-frame aura update pipeline.
-- tick_visible_icons() updates timer text and bar values without re-scanning.
-- update_auras() orchestrates the unified scan -> per-frame aura filter -> layout -> render -> resize sequence on each deferred UNIT_AURA event.
local addon_name, addon = ...

local math_max       = math.max
local math_ceil      = math.ceil
local GetTime        = GetTime
local issecretvalue  = issecretvalue
local C_UnitAuras    = C_UnitAuras
local C_Timer        = C_Timer
local wipe           = wipe
local InCombatLockdown = InCombatLockdown

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

function M.uses_cooldown_icon_overlay(category, bar_mode, db)
    return (not bar_mode) and db and db["cooldown_mode_" .. category] == true
end

local set_shown_if_changed = M.set_shown_if_changed
local clear_timer_text = M.clear_timer_text

local function set_scale_if_changed(frame, scale)
    if not frame then return end
    scale = scale or 1
    if frame._lstweeks_applied_scale == scale then return end
    frame._lstweeks_applied_scale = scale
    frame:SetScale(scale)
end

local function set_alpha_if_changed(frame, alpha)
    if not frame then return end
    alpha = alpha or 1
    if frame._lstweeks_applied_alpha == alpha then return end
    frame._lstweeks_applied_alpha = alpha
    frame:SetAlpha(alpha)
end

local function cancel_frame_ooc_fade(frame)
    if not frame then return end
    if frame._ooc_fade_timer then
        frame._ooc_fade_timer:Cancel()
        frame._ooc_fade_timer = nil
    end
    if frame._ooc_fade_state then
        frame._ooc_fade_state = nil
        frame:SetScript("OnUpdate", nil)
    end
end
M.cancel_frame_ooc_fade = cancel_frame_ooc_fade

local function clamp_ooc_alpha(value)
    value = tonumber(value) or M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA
    if value < 0.1 then return 0.1 end
    if value > 1 then return 1 end
    return value
end

local function normalize_fade_seconds(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    return value
end

local function start_frame_ooc_fade(frame, state)
    if not (frame and frame._ooc_fade_state == state) then return end
    local duration = state.duration
    if duration <= 0 then
        set_alpha_if_changed(frame, state.target_alpha)
        state.done = true
        return
    end

    state.start_time = GetTime()
    state.start_alpha = frame._lstweeks_applied_alpha or (frame.GetAlpha and frame:GetAlpha()) or 1
    frame:SetScript("OnUpdate", function(self)
        local fade_state = self._ooc_fade_state
        if not fade_state then
            self:SetScript("OnUpdate", nil)
            return
        end

        local progress = (GetTime() - fade_state.start_time) / fade_state.duration
        if progress >= 1 then
            set_alpha_if_changed(self, fade_state.target_alpha)
            fade_state.done = true
            self:SetScript("OnUpdate", nil)
            return
        end

        local alpha = fade_state.start_alpha + ((fade_state.target_alpha - fade_state.start_alpha) * progress)
        set_alpha_if_changed(self, alpha)
    end)
end

local function apply_ooc_fade(frame, enabled, is_moving, in_combat, target_alpha, delay, duration)
    if not enabled or is_moving or frame._is_mouse_over then
        cancel_frame_ooc_fade(frame)
        set_alpha_if_changed(frame, 1)
        return
    end

    if in_combat then
        cancel_frame_ooc_fade(frame)
        set_alpha_if_changed(frame, 1)
        return
    end

    target_alpha = clamp_ooc_alpha(target_alpha)
    delay = normalize_fade_seconds(delay)
    duration = normalize_fade_seconds(duration)

    local signature = target_alpha .. "|" .. delay .. "|" .. duration
    local state = frame._ooc_fade_state
    if state and state.signature == signature then return end

    cancel_frame_ooc_fade(frame)
    state = {
        signature = signature,
        target_alpha = target_alpha,
        duration = duration,
    }
    frame._ooc_fade_state = state

    if delay > 0 and C_Timer and C_Timer.NewTimer then
        frame._ooc_fade_timer = C_Timer.NewTimer(delay, function()
            if frame._ooc_fade_state == state then
                frame._ooc_fade_timer = nil
                start_frame_ooc_fade(frame, state)
            end
        end)
    else
        start_frame_ooc_fade(frame, state)
    end
end

function M.refresh_frame_ooc_fade(frame, activity, cfg_db)
    if not frame then return end
    local params = frame.update_params
    cfg_db = cfg_db or M.get_frame_config_db(frame)
    if not (params and cfg_db) then return end

    activity = activity or M.get_frame_activity_state(frame, params.show_key, params.move_key)
    if not activity.enabled then
        cancel_frame_ooc_fade(frame)
        set_alpha_if_changed(frame, 1)
        return
    end

    local category = frame.category
    local fade_ooc = M.get_setting(cfg_db, category, "fade_ooc", false) == true
    apply_ooc_fade(
        frame,
        fade_ooc,
        activity.moving == true,
        InCombatLockdown and InCombatLockdown(),
        M.get_setting(cfg_db, category, "ooc_alpha", M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA),
        M.get_setting(cfg_db, category, "fade_delay", M.DEFAULT_OOC_FADE_DELAY),
        M.get_setting(cfg_db, category, "fade_length", M.DEFAULT_OOC_FADE_LENGTH)
    )
end

function M.set_aura_frame_hovered(frame, hovered)
    if not frame then return end
    hovered = hovered == true
    if frame._is_mouse_over == hovered then return end
    frame._is_mouse_over = hovered
    if M.refresh_frame_ooc_fade then
        M.refresh_frame_ooc_fade(frame)
    end
end

local function apply_position_if_changed(frame, scale_key, fallback_y, scale)
    local pos = M.get_frame_position_table(frame)
    local point = pos and pos.point or "TOPLEFT"
    local x = pos and pos.x or -100
    local y = pos and pos.y or fallback_y or 75
    scale = scale or M.get_frame_position_scale(frame, scale_key)

    if frame._lstweeks_pos_point == point
        and frame._lstweeks_pos_x == x
        and frame._lstweeks_pos_y == y
        and frame._lstweeks_pos_scale == scale then
        return
    end

    frame._lstweeks_pos_point = point
    frame._lstweeks_pos_x = x
    frame._lstweeks_pos_y = y
    frame._lstweeks_pos_scale = scale
    M.apply_saved_frame_position(frame, scale_key, fallback_y, scale)
end

local function set_size_if_changed(frame, width, height)
    if not frame then return end
    if frame._lstweeks_width == width and frame._lstweeks_height == height then return end
    frame._lstweeks_width = width
    frame._lstweeks_height = height
    frame:SetSize(width, height)
end

local function set_height_for_growth_if_changed(frame, height, growth)
    if frame._lstweeks_growth_height == height and frame._lstweeks_growth == growth then return end
    frame._lstweeks_growth_height = height
    frame._lstweeks_growth = growth
    M.set_height_for_growth(frame, height, growth)
end

local function set_backdrop_state_if_changed(frame, bg_r, bg_g, bg_b, bg_a, br_r, br_g, br_b, br_a)
    if frame._lstweeks_bg_r == bg_r
        and frame._lstweeks_bg_g == bg_g
        and frame._lstweeks_bg_b == bg_b
        and frame._lstweeks_bg_a == bg_a
        and frame._lstweeks_br_r == br_r
        and frame._lstweeks_br_g == br_g
        and frame._lstweeks_br_b == br_b
        and frame._lstweeks_br_a == br_a then
        return
    end

    frame._lstweeks_bg_r = bg_r
    frame._lstweeks_bg_g = bg_g
    frame._lstweeks_bg_b = bg_b
    frame._lstweeks_bg_a = bg_a
    frame._lstweeks_br_r = br_r
    frame._lstweeks_br_g = br_g
    frame._lstweeks_br_b = br_b
    frame._lstweeks_br_a = br_a
    frame:SetBackdropColor(bg_r, bg_g, bg_b, bg_a)
    frame:SetBackdropBorderColor(br_r, br_g, br_b, br_a)
end

local function set_bar_minmax_if_changed(bar, min_value, max_value)
    if not bar then return end
    if bar._lstweeks_min_value == min_value and bar._lstweeks_max_value == max_value then return end
    bar._lstweeks_min_value = min_value
    bar._lstweeks_max_value = max_value
    bar:SetMinMaxValues(min_value, max_value)
end

--#region TIMER TICKER =========================================================


local function aura_icon_needs_tick(obj, frame, now)
    if not (obj and obj:IsShown()) then return false end
    if obj.is_test_preview then return true end
    if obj.is_spell_cooldown then return true end

    local is_static_frame = frame and frame.category == "static"
    if is_static_frame then return false end

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

function M.ensure_visible_icon_ticker(needs_tick_known)
    if M._visible_icon_ticker then return end
    if not (C_Timer and C_Timer.NewTicker) then return end
    if not needs_tick_known and not M.any_frame_needs_visible_icon_tick() then return end

    M._visible_icon_ticker = C_Timer.NewTicker(M.UPDATE_INTERVALS.aura_visible_icon_tick or M.UPDATE_INTERVALS.tenth_sec, function()
        M.tick_visible_icons()
        if not M.any_frame_needs_visible_icon_tick() then
            M.stop_visible_icon_ticker()
        end
    end)
end

function M.refresh_visible_icon_ticker()
    if M._visible_icon_ticker then return end
    if M.any_frame_needs_visible_icon_tick() then
        M.ensure_visible_icon_ticker(true)
    else
        M.stop_visible_icon_ticker()
    end
end

-- Shared ticker update path for all visible aura icon objects.
-- Started on demand and keeps timer/bar text fresh between scans.
function M.tick_visible_icons(now)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then
        if M.stop_visible_icon_ticker then M.stop_visible_icon_ticker() end
        return
    end

    now = now or GetTime()
    local db = M.db
    local short_threshold = (db and db.short_threshold) or M.DEFAULT_SHORT_THRESHOLD

    local frames_list = M.frames_list
    if not frames_list then return end
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
                        M.update_test_preview_state(obj, "show_" .. frame.category, short_threshold, now)
                    end
                    if is_static_frame then
                        clear_timer_text(obj.time_text)
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
                end
            end
        end
    end
end

--#endregion TIMER TICKER ======================================================

--#region BLIZZARD BUFF/DEBUFF FRAME TOGGLES ===================================

local blizz_aura_frame_state = setmetatable({}, { __mode = "k" })

local function get_blizz_aura_frame_state(frame)
    local state = blizz_aura_frame_state[frame]
    if not state then
        state = {}
        blizz_aura_frame_state[frame] = state
    end
    return state
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
                    self:Hide()
                end
            end)
        end
        frame:Hide()
        return
    end

    if state.forced_hidden then
        state.forced_hidden = nil
        frame:Show()
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

    if frame.UpdateSystemSettingValue then
        pcall(frame.UpdateSystemSettingValue, frame, edit_setting_enum.VisibleSetting, always)
    else
        frame.visibleSetting = always
    end

    if frame.UpdateShownState then
        pcall(frame.UpdateShownState, frame)
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
        M._cd_viewer_state = M._cd_viewer_state or setmetatable({}, { __mode = "k" })
        state = {}
        M._cd_viewer_state[frame] = state
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

--#region AURA UPDATE (MAIN PER-FRAME REFRESH) =================================
-- Works for both preset category frames and custom filtered frames.
-- Custom frames set frame.is_custom = true and frame.custom_entry = <entry table>.

function M.update_auras(self, show_key, move_key, timer_key, bg_key, scale_key, spacing_key, aura_filter, info)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then return end
    if not self or not self.icons then return end

    local db       = M.db
    local category = self.category  -- e.g. "static", "short", "custom_1"
    local is_custom = self.is_custom
    local custom_entry = is_custom and self.custom_entry

    -- For custom frames, keys are stored inside the entry table, not in the flat DB.
    local cfg_db = is_custom and custom_entry or db
    if not cfg_db then return end
    local activity = M.get_frame_activity_state(self, show_key, move_key)
    local is_moving = activity.moving == true
    local preview_enabled = activity.test_aura == true
    if not activity.enabled then
        self._display_count = 0
        cancel_frame_ooc_fade(self)
        set_alpha_if_changed(self, 1)
        set_shown_if_changed(self, false)
        set_shown_if_changed(self.title_bar, false)
        set_shown_if_changed(self.bottom_title_bar, false)
        set_shown_if_changed(self.resizer, false)
        if M.refresh_visible_icon_ticker then M.refresh_visible_icon_ticker() end
        return
    end

    local bar_mode_key  = self._bar_mode_key or ("bar_mode_" .. category)
    self._bar_mode_key  = bar_mode_key
    local bar_mode      = cfg_db[bar_mode_key] ~= nil and cfg_db[bar_mode_key] or cfg_db["bar_mode"]
    local frame_width   = cfg_db["width_" .. category] or cfg_db["width"] or M.DEFAULT_FRAME_WIDTH
    local spacing       = cfg_db[spacing_key] or cfg_db["spacing"] or 6
    local color         = M.get_setting(cfg_db, category, "color", { r = 1, g = 1, b = 1 })
    local barBgC        = M.get_bar_bg_color(cfg_db, category, color)
    local barTextC      = M.get_setting(cfg_db, category, "bar_text_color", { r = 1, g = 1, b = 1 })
    local bgC           = M.get_setting(cfg_db, category, "bg_color", { r = 0, g = 0, b = 0, a = 0.5 })
    local show_timer_text = M.is_timer_text_enabled(cfg_db, category, timer_key)
    local show_timer_swipe = (not bar_mode) and M.get_setting(cfg_db, category, "timer_swipe", true) ~= false
    local cooldown_icon_overlay = M.uses_cooldown_icon_overlay(category, bar_mode, cfg_db)
    local layout_show_timer_text = show_timer_text and not cooldown_icon_overlay
    self._show_timer_text = show_timer_text
    self._show_timer_swipe = show_timer_swipe
    self._show_tooltip    = M.get_setting(cfg_db, category, "tooltip", true) ~= false
    self._show_cooldown_overlay = cooldown_icon_overlay
    self._bar_mode        = bar_mode
    local short_threshold = db.short_threshold or M.DEFAULT_SHORT_THRESHOLD
    local growth        = cfg_db["growth_" .. category] or cfg_db["growth"] or "DOWN"
    local max_limit     = cfg_db["max_icons_" .. category] or cfg_db["max_icons"] or M.MAX_ICONS_LIMIT
    local sort_mode     = (not is_custom) and (cfg_db["sort_" .. category] or cfg_db["sort"] or "timeleft") or nil
    local in_combat = InCombatLockdown and InCombatLockdown()
    local is_user_positioning = self._is_user_positioning == true

    local scale = cfg_db[scale_key] or cfg_db["scale"] or 1.0
    if not in_combat and not is_user_positioning then
        set_scale_if_changed(self, scale)
    end

    local _width  = frame_width
    local _height = self:GetHeight() or 50
    if _width  < 1 then _width  = M.DEFAULT_FRAME_WIDTH end
    if _height < 1 then _height = 50  end
    if not in_combat and not is_user_positioning then
        apply_position_if_changed(self, scale_key, (aura_filter == "HARMFUL") and -25 or 75, scale)
        set_size_if_changed(self, _width, _height)
    end

    -- For custom frames, expose cfg_db on the frame so setup_layout can read it.
    if is_custom then self._cfg_db = cfg_db end

    local needs_layout = not self._layout_cache
        or self._layout_cache.frame_width     ~= frame_width
        or self._layout_cache.bar_mode        ~= bar_mode
        or self._layout_cache.show_timer_text ~= show_timer_text
        or self._layout_cache.layout_show_timer_text ~= layout_show_timer_text
        or self._layout_cache.cooldown_icon_overlay ~= cooldown_icon_overlay
        or self._layout_cache.spacing         ~= spacing
        or self._layout_cache.growth          ~= growth
    if needs_layout and not in_combat and not is_user_positioning then
        M.setup_layout(self, show_key, spacing_key, bar_mode)
    end

    if is_moving then
        set_shown_if_changed(self.title_bar, true)
        set_shown_if_changed(self.bottom_title_bar, true)
        set_shown_if_changed(self.resizer, true)
    else
        set_shown_if_changed(self.title_bar, false)
        set_shown_if_changed(self.bottom_title_bar, false)
        set_shown_if_changed(self.resizer, false)
    end

    set_shown_if_changed(self, true)
    if activity.needs_cdm_viewer and M.prepare_blizz_cdm_viewer then
        M.prepare_blizz_cdm_viewer(category)
    end

    if not self._aura_map then self._aura_map = {} end

    -- Run the unified scan once per dirty event batch, then let the other
    -- preset frames in the same deferred batch reuse M._aura_map.
    if activity.needs_shared_scan and M._aura_scan_dirty then
        M.unified_scan(info, short_threshold, 0, 0)
        M._aura_scan_dirty = false
    end

    -- Filter the shared map into this frame's per-frame map.
    wipe(self._aura_map)
    if activity.needs_custom_scan then
        M.scan_custom_aura_map(self, custom_entry, self._aura_map, max_limit, short_threshold)
    else
        if activity.needs_cdm_scan then
            M.add_cooldown_viewer_category_entries(self._aura_map, category)
        else
            -- Preset frame: use the scan-built bucket when available.
            local category_bucket = M._aura_maps_by_category and M._aura_maps_by_category[category]
            if category_bucket then
                for iid, entry in pairs(category_bucket) do
                    self._aura_map[iid] = entry
                end
            else
                for iid, entry in pairs(M._aura_map) do
                    if entry.category == category then
                        self._aura_map[iid] = entry
                    end
                end
            end
        end
    end

    M.refresh_frame_ooc_fade(self, activity, cfg_db)

    if preview_enabled then
        M.append_test_aura(self._aura_map, show_key, aura_filter, short_threshold)
    else
        self._aura_map["__test_preview__"] = nil
    end

    local display_count = M.render_aura_map(
        self, self._aura_map, bar_mode, color, barBgC, max_limit, aura_filter, sort_mode, show_timer_text, barTextC
    )
    if M.refresh_visible_icon_ticker then M.refresh_visible_icon_ticker() end

    local lc = self._layout_cache
    local icon_timer_h = layout_show_timer_text and 12 or 0
    local icon_bot_pad = layout_show_timer_text and 14 or 12
    local new_height = bar_mode and ((lc and lc.row_height or 18) + spacing + 12)
                                or  ((lc and lc.icon_size  or 32) + icon_timer_h + icon_bot_pad)
    if display_count > 0 then
        if bar_mode then
            local bar_row_h = lc and lc.row_height or 18
            new_height = display_count * (bar_row_h + spacing) + 12
        elseif lc and (lc.growth == "DOWN" or lc.growth == "UP") then
            local isz = lc.icon_size or 32
            new_height = display_count * (isz + spacing + icon_timer_h) - spacing + icon_bot_pad
        elseif lc and lc.icons_per_row then
            local isz = lc.icon_size or 32
            local rows = math_ceil(display_count / lc.icons_per_row)
            new_height = rows * (isz + spacing + icon_timer_h) - spacing + icon_bot_pad
        else
            new_height = display_count * 44
        end
    end

    if not in_combat and not is_user_positioning then
        set_height_for_growth_if_changed(self, new_height, growth)
    end

    local is_bg_enabled = cfg_db[bg_key] ~= nil and cfg_db[bg_key] or cfg_db["bg"]
    local bg_r, bg_g, bg_b, bg_a
    local br_r, br_g, br_b, br_a
    if is_moving then
        if is_bg_enabled and bgC then
            bg_r, bg_g, bg_b, bg_a = bgC.r, bgC.g, bgC.b, bgC.a or 1
            br_r, br_g, br_b, br_a = 1, 1, 1, 1
        else
            bg_r, bg_g, bg_b, bg_a = 0, 0, 0, 0.8
            br_r, br_g, br_b, br_a = 1, 1, 1, 1
        end
    else
        if is_bg_enabled and bgC then
            bg_r, bg_g, bg_b, bg_a = bgC.r, bgC.g, bgC.b, bgC.a or 1
            br_r, br_g, br_b, br_a = 0, 0, 0, 0
        else
            bg_r, bg_g, bg_b, bg_a = 0, 0, 0, 0
            br_r, br_g, br_b, br_a = 0, 0, 0, 0
        end
    end
    set_backdrop_state_if_changed(self, bg_r, bg_g, bg_b, bg_a, br_r, br_g, br_b, br_a)
end

--#endregion AURA UPDATE (MAIN PER-FRAME REFRESH) ==============================
