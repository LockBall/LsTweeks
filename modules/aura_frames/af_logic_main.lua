-- Main aura update logic for Aura Frames: runtime config cache, frame state helpers, OOC fade, and per-frame refresh.
-- update_auras() orchestrates scan, render, layout, sizing, and visibility for preset and custom aura frames.
local addon_name, addon = ...

local math_ceil      = math.ceil
local GetTime        = GetTime
local C_Timer        = C_Timer
local wipe           = wipe
local InCombatLockdown = InCombatLockdown

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

function M.uses_cooldown_icon_overlay(category, bar_mode, db)
    return (not bar_mode) and db and db["cooldown_mode_" .. category] == true
end

function M.invalidate_frame_runtime_config(frame)
    if not frame then return end
    frame._runtime_config_cache = nil
    frame._layout_cache = nil
end

function M.invalidate_all_frame_runtime_config()
    local frames_list = M.frames_list
    if not frames_list then return end
    for i = 1, #frames_list do
        M.invalidate_frame_runtime_config(frames_list[i])
    end
end

local function resolve_runtime_config(frame, cfg_db, category, is_custom, timer_key, spacing_key)
    local cache = frame._runtime_config_cache
    if cache then return cache end

    local bar_mode_key = frame._bar_mode_key or ("bar_mode_" .. category)
    frame._bar_mode_key = bar_mode_key

    local bar_mode = cfg_db[bar_mode_key] ~= nil and cfg_db[bar_mode_key] or cfg_db["bar_mode"]
    local show_timer_text = M.is_timer_text_enabled(cfg_db, category, timer_key)
    local cooldown_icon_overlay = M.uses_cooldown_icon_overlay(category, bar_mode, cfg_db)
    local color = M.get_setting(cfg_db, category, "color", { r = 1, g = 1, b = 1 })
    local bar_bg_color = M.get_bar_bg_color(cfg_db, category, color)
    local bar_text_color = M.get_setting(cfg_db, category, "bar_text_color", { r = 1, g = 1, b = 1 })
    local bg_color = M.get_setting(cfg_db, category, "bg_color", { r = 0, g = 0, b = 0, a = 0.5 })

    cache = {
        bar_mode = bar_mode,
        frame_width = cfg_db["width_" .. category] or cfg_db["width"] or M.DEFAULT_FRAME_WIDTH,
        spacing = cfg_db[spacing_key] or cfg_db["spacing"] or 6,
        show_timer_text = show_timer_text,
        show_timer_swipe = (not bar_mode) and M.get_setting(cfg_db, category, "timer_swipe", true) ~= false,
        show_tooltip = M.get_setting(cfg_db, category, "tooltip", true) ~= false,
        cooldown_icon_overlay = cooldown_icon_overlay,
        layout_show_timer_text = show_timer_text and not cooldown_icon_overlay,
        growth = cfg_db["growth_" .. category] or cfg_db["growth"] or "DOWN",
        max_limit = cfg_db["max_icons_" .. category] or cfg_db["max_icons"] or M.MAX_ICONS_LIMIT,
        sort_mode = (not is_custom) and (cfg_db["sort_" .. category] or cfg_db["sort"] or "timeleft") or nil,
        color = {
            r = color.r or 1,
            g = color.g or 1,
            b = color.b or 1,
            a = color.a or 1,
        },
        bar_bg_color = {
            r = bar_bg_color.r or 1,
            g = bar_bg_color.g or 1,
            b = bar_bg_color.b or 1,
            a = bar_bg_color.a or M.BAR_BG_ALPHA_DEFAULT,
        },
        bar_text_color = {
            r = bar_text_color.r or 1,
            g = bar_text_color.g or 1,
            b = bar_text_color.b or 1,
        },
        bg_color = {
            r = bg_color.r or 0,
            g = bg_color.g or 0,
            b = bg_color.b or 0,
            a = bg_color.a or 0.5,
        },
    }
    frame._runtime_config_cache = cache
    return cache
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
    local min_alpha = M.MIN_WOW_COOLDOWN_OOC_ALPHA
    local max_alpha = M.MAX_WOW_COOLDOWN_OOC_ALPHA
    if value < min_alpha then return min_alpha end
    if value > max_alpha then return max_alpha end
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
    if not fade_ooc
        and not frame._ooc_fade_timer
        and not frame._ooc_fade_state
        and (frame._lstweeks_applied_alpha == nil or frame._lstweeks_applied_alpha == 1) then
        return
    end

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

    local runtime_config = resolve_runtime_config(self, cfg_db, category, is_custom, timer_key, spacing_key)
    local bar_mode      = runtime_config.bar_mode
    local frame_width   = runtime_config.frame_width
    local spacing       = runtime_config.spacing
    local color         = runtime_config.color
    local barBgC        = runtime_config.bar_bg_color
    local barTextC      = runtime_config.bar_text_color
    local bgC           = runtime_config.bg_color
    local show_timer_text = runtime_config.show_timer_text
    local show_timer_swipe = runtime_config.show_timer_swipe
    local cooldown_icon_overlay = runtime_config.cooldown_icon_overlay
    local layout_show_timer_text = runtime_config.layout_show_timer_text
    self._show_timer_text = show_timer_text
    self._show_timer_swipe = show_timer_swipe
    self._show_tooltip    = runtime_config.show_tooltip
    self._show_cooldown_overlay = cooldown_icon_overlay
    self._bar_mode        = bar_mode
    local short_threshold = db.short_threshold or M.DEFAULT_SHORT_THRESHOLD
    local growth        = runtime_config.growth
    local max_limit     = runtime_config.max_limit
    local sort_mode     = runtime_config.sort_mode
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

    -- Run the unified scan once per dirty event batch, then let the other
    -- preset frames in the same deferred batch reuse M._aura_map.
    if activity.needs_shared_scan and M._aura_scan_dirty then
        M.unified_scan(info, short_threshold, 0, 0)
        M._aura_scan_dirty = false
    end

    local render_map
    if activity.needs_custom_scan then
        if not self._aura_map then self._aura_map = {} end
        M.scan_custom_aura_map(self, custom_entry, self._aura_map, max_limit, short_threshold)
        render_map = self._aura_map
    else
        if activity.needs_cdm_scan then
            if not self._aura_map then self._aura_map = {} end
            wipe(self._aura_map)
            M.add_cooldown_viewer_category_entries(self._aura_map, category)
            render_map = self._aura_map
        else
            -- Preset frame: use the scan-built bucket when available.
            local category_bucket = M._aura_maps_by_category and M._aura_maps_by_category[category]
            if category_bucket and not preview_enabled then
                render_map = category_bucket
            else
                if not self._aura_map then self._aura_map = {} end
                wipe(self._aura_map)
                render_map = self._aura_map
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
    end

    M.refresh_frame_ooc_fade(self, activity, cfg_db)

    if preview_enabled then
        if render_map ~= self._aura_map then
            if not self._aura_map then self._aura_map = {} end
            wipe(self._aura_map)
            if render_map then
                for iid, entry in pairs(render_map) do
                    self._aura_map[iid] = entry
                end
            end
            render_map = self._aura_map
        end
        M.append_test_aura(render_map, show_key, aura_filter, short_threshold)
    elseif render_map == self._aura_map then
        self._aura_map["__test_preview__"] = nil
    end

    local display_count = M.render_aura_map(
        self, render_map, bar_mode, color, barBgC, max_limit, aura_filter, sort_mode, show_timer_text, barTextC
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
