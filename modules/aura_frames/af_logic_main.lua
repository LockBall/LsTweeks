-- Main aura update logic for Aura Frames: managed-frame routing, runtime config cache,
-- frame state helpers, OOC fade, and addon-rendered per-frame refresh.
-- update_auras() orchestrates scan, render, layout, sizing, and visibility for preset and custom aura frames.
local addon_name, addon = ...

local GetTime        = GetTime
local C_Timer        = C_Timer
local wipe           = wipe
local InCombatLockdown = InCombatLockdown

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

--#region RUNTIME CONFIGURATION AND FRAME STATE ================================
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

function M.on_shared_color_changed()
    M.invalidate_all_frame_runtime_config()
    if M.sync_background_color_controls then
        M.sync_background_color_controls()
    end
    if M.apply_number_font_to_all then M.apply_number_font_to_all() end
    if M.is_runtime_enabled and not M.is_runtime_enabled() then return end

    local frames_list = M.frames_list
    if not frames_list then return end
    for i = 1, #frames_list do
        local frame = frames_list[i]
        local params = frame and frame.update_params
        if params then
            M.update_auras(frame, params.show_key, params.move_key, params.timer_key,
                params.bg_key, params.scale_key, params.spacing_key, params.aura_filter)
        end
    end
end

function M.resolve_bar_color(category, local_color)
    local resolved = local_color
    if M.db
        and M.db.shared_background_color_enabled == true
        and M.get_bar_color_sync_enabled(category)
    then
        resolved = M.is_debuff_frame_category(category)
            and M.db.shared_debuff_bar_color
            or M.db.shared_buff_bar_color
        resolved = resolved or local_color
    end

    local color_sync = addon.all_the_colors
    if color_sync and color_sync.resolve_module_color then
        local color_key = M.is_debuff_frame_category(category)
            and "aura_debuff_bar_color"
            or "aura_buff_bar_color"
        resolved = color_sync.resolve_module_color(
            M.MODULE_KEY, color_key, resolved, M.get_color_consumer_group(category))
    end
    return resolved
end

function M.resolve_text_color(category, text_type, local_color)
    local resolved = local_color
    if M.db
        and M.db.shared_background_color_enabled == true
        and M.get_text_color_sync_enabled(category)
    then
        resolved = text_type == "timer"
            and M.db.shared_timer_text_color
            or M.db.shared_bar_text_color
        resolved = resolved or local_color
    end

    local color_sync = addon.all_the_colors
    if color_sync and color_sync.resolve_module_color then
        local color_key = text_type == "timer"
            and "aura_timer_text_color"
            or "aura_bar_text_color"
        resolved = color_sync.resolve_module_color(
            M.MODULE_KEY, color_key, resolved, M.get_color_consumer_group(category))
    end
    return resolved
end

function M.resolve_text_font(category, text_type, local_font)
    if M.db
        and M.db.shared_background_color_enabled == true
        and M.get_text_font_sync_enabled(category)
    then
        return (text_type == "timer" and M.db.shared_timer_text_font or M.db.shared_bar_text_font)
            or local_font
    end
    return local_font
end

function M.apply_shared_font_to_all(local_key, shared_key)
    if not (M.db and local_key and shared_key) then return false end
    local selected_font = M.db[shared_key]
    if not selected_font then return false end

    for _, category in ipairs(M.CATEGORIES or {}) do
        M.db[local_key .. "_" .. category] = selected_font
    end
    for _, entry in ipairs(M.db.custom_frames or {}) do
        entry[local_key] = selected_font
    end

    if M.on_shared_color_changed then M.on_shared_color_changed() end
    if M.sync_general_controls_from_db then M.sync_general_controls_from_db() end
    return true
end

local function resolve_runtime_config(frame, cfg_db, category, is_custom, timer_key, spacing_key)
    local cache = frame._runtime_config_cache
    if cache then return cache end

    local bar_mode_key = frame._bar_mode_key or ("bar_mode_" .. category)
    frame._bar_mode_key = bar_mode_key

    local bar_mode = cfg_db[bar_mode_key]
    if bar_mode == nil then
        bar_mode = cfg_db["bar_mode"]
    end
    local show_timer_text = M.is_timer_text_enabled(cfg_db, category, timer_key)
    local cooldown_icon_overlay = M.uses_cooldown_icon_overlay(category, bar_mode, cfg_db)
    local color = M.get_setting(cfg_db, category, "color", { r = 1, g = 1, b = 1 })
    local bar_bg_color = M.get_bar_bg_color(cfg_db, category, color)
    local bar_text_color = M.get_setting(cfg_db, category, "bar_text_color", { r = 1, g = 1, b = 1 })
    local frame_bg_enabled, bg_color = M.resolve_frame_background(cfg_db, category)
    color = M.resolve_bar_color(category, color)
    bar_text_color = M.resolve_text_color(category, "bar", bar_text_color)
    bar_bg_color = M.resolve_background_color(category, "bar", bar_bg_color)

    local growth_layout = addon.GetGrowthDirection(M.get_mode_growth(cfg_db, category, bar_mode))

    cache = {
        bar_mode = bar_mode,
        frame_width = cfg_db["width_" .. category] or cfg_db["width"] or M.DEFAULT_FRAME_WIDTH,
        spacing = cfg_db[spacing_key] or cfg_db["spacing"] or 6,
        show_timer_text = show_timer_text,
        show_timer_swipe = (not bar_mode) and M.get_setting(cfg_db, category, "timer_swipe", true) ~= false,
        show_tooltip = M.get_setting(cfg_db, category, "tooltip", true) ~= false,
        cooldown_icon_overlay = cooldown_icon_overlay,
        layout_show_timer_text = show_timer_text and not cooldown_icon_overlay,
        growth = growth_layout.value,
        max_limit = M.AURA_FRAME_LIMIT,
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
        frame_bg_enabled = frame_bg_enabled,
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
    if frame._lstweeks_applied_alpha ~= alpha then
        frame._lstweeks_applied_alpha = alpha
        frame:SetAlpha(alpha)
    end

    -- Blizzard managed AuraButtons do not reliably inherit visual alpha across
    -- the constrained AuraContainer boundary.  Fade the addon-owned aggregate
    -- container as well, without touching individual protected AuraButtons.
    local backend = frame._managed_aura_backend or frame._managed_cdm_backend
    local container = backend and backend.container
    if container and backend._lstweeks_applied_alpha ~= alpha then
        backend._lstweeks_applied_alpha = alpha
        container:SetAlpha(alpha)
    end
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
    value = tonumber(value) or addon.DEFAULT_FADE_ALPHA
    local range = M.SETTING_RANGES.ooc_alpha
    local min_alpha = range.min
    local max_alpha = range.max
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

local function refresh_frame_ooc_fade_for_state(frame, in_combat, activity, cfg_db)
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
    local color_sync = addon.all_the_colors
    if color_sync and color_sync.resolve_ooc_fade then
        fade_ooc = color_sync.resolve_ooc_fade(M.MODULE_KEY, fade_ooc)
    end
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
        in_combat == true,
        M.get_setting(cfg_db, category, "ooc_alpha", addon.DEFAULT_FADE_ALPHA),
        M.get_setting(cfg_db, category, "fade_delay", M.DEFAULT_OOC_FADE_DELAY),
        M.get_setting(cfg_db, category, "fade_length", M.DEFAULT_OOC_FADE_LENGTH)
    )
end

function M.refresh_frame_ooc_fade(frame, activity, cfg_db)
    local in_combat = InCombatLockdown and InCombatLockdown()
    refresh_frame_ooc_fade_for_state(frame, in_combat, activity, cfg_db)
end

function M.refresh_frame_fade_for_combat_state(frame, in_combat)
    refresh_frame_ooc_fade_for_state(frame, in_combat == true)
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

function M.apply_aura_frame_shell_transform(frame, cfg_db, scale_key, fallback_y)
    if not (frame and cfg_db) then return end
    if (InCombatLockdown and InCombatLockdown()) or frame._is_user_positioning == true then return end

    local scale = cfg_db[scale_key] or cfg_db.scale or 1.0
    set_scale_if_changed(frame, scale)
    apply_position_if_changed(frame, scale_key, fallback_y, scale)
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

--#endregion RUNTIME CONFIGURATION AND FRAME STATE =============================
--#region AURA UPDATE (MAIN PER-FRAME REFRESH) =================================
-- Works for both preset category frames and custom filtered frames.
-- Custom frames set frame.is_custom = true and frame.custom_entry = <entry table>.

function M.update_auras(self, show_key, move_key, timer_key, bg_key, scale_key, spacing_key, aura_filter)
    if M.is_runtime_enabled and not M.is_runtime_enabled() then return end
    if self and self._managed_aura_backend and M.update_managed_preset_frame then
        M.update_managed_preset_frame(self, show_key, move_key)
        local managed_activity = M.get_frame_activity_state(self, show_key, move_key)
        if managed_activity.test_aura ~= true then return end
    end
    if not self or not self.icons then return end

    local db       = M.db
    local category = self.category
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
        if self._managed_cdm_backend and M.set_managed_aura_backend_enabled then
            M.set_managed_aura_backend_enabled(self._managed_cdm_backend, false)
        end
        if M.apply_addon_frame_background then
            M.apply_addon_frame_background(self, {
                display_count = 0,
                enabled = false,
                in_combat = InCombatLockdown and InCombatLockdown(),
                is_moving = false,
            })
        end
        cancel_frame_ooc_fade(self)
        set_alpha_if_changed(self, 1)
        set_shown_if_changed(self, false)
        M.update_aura_frame_move_controls(self, false)
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
    local managed_preview = self._managed_aura_backend ~= nil and preview_enabled
    local max_limit     = runtime_config.max_limit
    local sort_mode     = runtime_config.sort_mode
    local in_combat = InCombatLockdown and InCombatLockdown()
    local is_user_positioning = self._is_user_positioning == true

    M.apply_aura_frame_shell_transform(
        self, cfg_db, scale_key, (aura_filter == "HARMFUL") and -25 or 75)

    local _width  = frame_width
    local _height = self:GetHeight() or 50
    if _width  < 1 then _width  = M.DEFAULT_FRAME_WIDTH end
    if _height < 1 then _height = 50  end
    if not in_combat and not is_user_positioning then
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
    M.update_aura_frame_move_controls(self, is_moving)
    if needs_layout and not in_combat and not is_user_positioning then
        M.setup_layout(self, show_key, spacing_key, bar_mode)
        if managed_preview and M.position_managed_test_preview then
            M.position_managed_test_preview(self, growth)
        end
    end

    set_shown_if_changed(self, true)

    if not self._aura_map then self._aura_map = {} end
    wipe(self._aura_map)
    if activity.needs_custom_scan then
        M.scan_custom_aura_map(self, custom_entry, self._aura_map, max_limit, short_threshold)
    elseif activity.needs_cdm_scan then
        M.add_cooldown_viewer_category_entries(self._aura_map, category)
    end
    local render_map = self._aura_map

    M.refresh_frame_ooc_fade(self, activity, cfg_db)

    if preview_enabled then
        M.append_test_aura(render_map, show_key, aura_filter)
    end

    local display_count = M.render_aura_map(
        self, render_map, bar_mode, color, barBgC, max_limit, aura_filter, sort_mode, show_timer_text, barTextC
    )

    local managed_cdm_aura_mode = false
    if self._managed_cdm_backend and M.refresh_managed_cdm_backend then
        M.refresh_managed_cdm_backend(self, bar_mode)
        if M.set_managed_cdm_move_outline_shown then
            managed_cdm_aura_mode = M.set_managed_cdm_move_outline_shown(self, is_moving)
        end
    end

    if M.refresh_visible_icon_ticker then M.refresh_visible_icon_ticker() end

    local new_height = M.get_aura_frame_height(
        self._layout_cache,
        display_count,
        bar_mode,
        spacing,
        layout_show_timer_text
    )

    if not managed_preview and not in_combat and not is_user_positioning then
        set_height_for_growth_if_changed(self, new_height, growth)
    end

    M.apply_addon_frame_background(self, {
        display_count = display_count,
        enabled = runtime_config.frame_bg_enabled,
        color = bgC,
        in_combat = in_combat,
        is_moving = is_moving,
        suppressed = managed_cdm_aura_mode or managed_preview,
    })
    if managed_preview and M.apply_managed_test_preview_background then
        M.apply_managed_test_preview_background(self, cfg_db, category)
    end
end

--#endregion AURA UPDATE (MAIN PER-FRAME REFRESH) ==============================
