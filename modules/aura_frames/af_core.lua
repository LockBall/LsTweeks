-- Runtime loop for the aura frames module: drives the per-tick timer countdown and the per-frame aura update pipeline.
-- tick_visible_icons() updates timer text and bar values without re-scanning.
-- update_auras() orchestrates the unified scan -> per-frame aura filter -> layout -> render -> resize sequence on each deferred UNIT_AURA event.
local addon_name, addon = ...

local math_max       = math.max
local math_ceil      = math.ceil
local GetTime        = GetTime
local issecretvalue  = issecretvalue
local C_UnitAuras    = C_UnitAuras
local wipe           = wipe
local InCombatLockdown = InCombatLockdown

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

function M.uses_cooldown_icon_overlay(category, bar_mode, db)
    return (not bar_mode) and db and db["cooldown_mode_" .. category] == true
end

local function set_shown_if_changed(frame, shown)
    if not frame then return end
    if shown then
        if not frame:IsShown() then frame:Show() end
    elseif frame:IsShown() then
        frame:Hide()
    end
end

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
    M.apply_saved_frame_position(frame, scale_key, fallback_y)
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

-- ============================================================================
-- TIMER TICKER


-- Shared ticker update path for all visible aura icon objects.
-- Runs from af_main.lua and keeps timer/bar text fresh between scans.
function M.tick_visible_icons(now)
    now = now or GetTime()
    local db = M.db
    local short_threshold = (db and db.short_threshold) or M.DEFAULT_SHORT_THRESHOLD

    for _, frame in pairs(M.frames) do
        if frame:IsVisible() then
            local is_static_frame = (frame.category == "static")
            local show_timer_text = frame._show_timer_text
            local bar_mode = frame._bar_mode
            local show_cooldown_overlay = frame._show_cooldown_overlay == true
            local display_count = frame._display_count
            if display_count == nil or display_count > #frame.icons then
                display_count = #frame.icons
            end
            for i = 1, display_count do
                local obj = frame.icons[i]
                if obj:IsShown() and obj.is_test_preview and M.update_test_preview_state then
                    M.update_test_preview_state(obj, "show_" .. frame.category, short_threshold, now)
                end
                if obj:IsShown() and is_static_frame then
                    if obj.time_text._last_text ~= "" then
                        obj.time_text:SetText("")
                        obj.time_text._last_text = ""
                    end
                elseif obj:IsShown() and ((type(obj.aura_index) == "number") or obj.is_spell_cooldown or obj.is_test_preview) then
                    if show_timer_text then
                        if show_cooldown_overlay then
                            if obj.time_text:IsShown() then obj.time_text:Hide() end
                            obj.time_text:SetText("")
                            obj.time_text._last_text = ""
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
                        local live_duration = nil
                        local ok, result = pcall(C_UnitAuras.GetAuraDuration, "player", obj.aura_index)
                        if ok then live_duration = result end
                        if live_duration then
                            live_remaining = live_duration:GetRemainingDuration()
                            if live_remaining ~= nil and not issecretvalue(live_remaining) then
                                remaining = live_remaining
                            end
                        end
                    end
                    if remaining and remaining > 0 then
                        if show_timer_text and not show_cooldown_overlay then
                            M.set_timer_text(obj.time_text, obj.aura_category or frame.category, remaining)
                        end
                        if obj.bar and obj.bar:IsShown() then
                            if obj.aura_duration and obj.aura_duration > 0 then
                                obj.bar:SetMinMaxValues(0, obj.aura_duration)
                            end
                            obj.bar:SetValue(remaining)
                        end
                    elseif remaining == 0 then
                        if obj.time_text._last_text ~= "" then
                            obj.time_text:SetText("")
                            obj.time_text._last_text = ""
                        end
                        obj.grey_cooldown = false
                    elseif live_remaining ~= nil and issecretvalue(live_remaining) then
                        if show_timer_text and not show_cooldown_overlay then
                            M.set_timer_text(obj.time_text, obj.aura_category or frame.category, live_remaining)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- BLIZZARD BUFF/DEBUFF FRAME TOGGLES

local function set_blizz_frame_state(frame, hide)
    if not frame then return end
    if hide then
        frame:Hide()
        frame:UnregisterAllEvents()
        if frame.SetScript then frame:SetScript("OnShow", nil) end
    else
        frame:RegisterEvent("UNIT_AURA")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
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

function M.update_blizz_cdm_visibility(category)
    M.ensure_blizz_cdm_loaded()
    local frame = M.get_cdm_viewer_frame(category)
    if not frame then return end

    if not frame._lstweeks_cdm_visibility_hooked then
        frame._lstweeks_cdm_visibility_hooked = true
        frame:HookScript("OnShow", function()
            if M.db and M.db["hide_blizz_cdm_" .. category] then
                frame:SetAlpha(0)
                frame:EnableMouse(false)
            end
        end)
    end

    -- Do not call Hide() here. Hidden CDM viewers stop producing the live child
    -- aura/cooldown state we read; alpha keeps them active but invisible.
    local hide = M.db and M.db["hide_blizz_cdm_" .. category]
    if not hide and (not InCombatLockdown or not InCombatLockdown()) and frame.Show then
        pcall(frame.Show, frame)
    end
    frame:SetAlpha(hide and 0 or 1)
    frame:EnableMouse(not hide)
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

    -- Utility can start hidden on reload. Show it once outside combat so
    -- Blizzard builds its child list, then apply alpha-based hiding.
    if frame.Show then
        pcall(frame.Show, frame)
    end
    M.update_blizz_cdm_visibility(category)
end

-- ============================================================================
-- AURA UPDATE (main per-frame refresh)
-- Works for both preset category frames and custom filtered frames.
-- Custom frames set frame.is_custom = true and frame.custom_entry = <entry table>.

function M.update_auras(self, show_key, move_key, timer_key, bg_key, scale_key, spacing_key, aura_filter, info)
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
        set_shown_if_changed(self, false)
        set_shown_if_changed(self.title_bar, false)
        set_shown_if_changed(self.bottom_title_bar, false)
        set_shown_if_changed(self.resizer, false)
        return
    end

    local bar_bg_alpha  = M.BAR_BG_ALPHA_DEFAULT
    local bar_mode_key  = self._bar_mode_key or ("bar_mode_" .. category)
    self._bar_mode_key  = bar_mode_key
    local bar_mode      = cfg_db[bar_mode_key] ~= nil and cfg_db[bar_mode_key] or cfg_db["bar_mode"]
    local frame_width   = cfg_db["width_" .. category] or cfg_db["width"] or M.DEFAULT_FRAME_WIDTH
    local spacing       = cfg_db[spacing_key] or cfg_db["spacing"] or 6
    local color         = M.get_setting(cfg_db, category, "color", { r = 1, g = 1, b = 1 })
    local barBgC        = M.get_setting(cfg_db, category, "bar_bg_color", { r = color.r, g = color.g, b = color.b, a = bar_bg_alpha })
    local barTextC      = M.get_setting(cfg_db, category, "bar_text_color", { r = 1, g = 1, b = 1 })
    local bgC           = M.get_setting(cfg_db, category, "bg_color", { r = 0, g = 0, b = 0, a = 0.5 })
    local show_timer_text = M.is_timer_text_enabled(cfg_db, category, timer_key)
    local cooldown_icon_overlay = M.uses_cooldown_icon_overlay(category, bar_mode, cfg_db)
    local layout_show_timer_text = show_timer_text and not cooldown_icon_overlay
    self._show_timer_text = show_timer_text
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

    if M.WOW_COOLDOWN_CATEGORIES[category] and M.db and M.db.fade_wow_cooldown_ooc and not is_moving then
        set_alpha_if_changed(self, in_combat and 1 or (M.db.wow_cooldown_ooc_alpha or M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA))
    else
        set_alpha_if_changed(self, 1)
    end

    if preview_enabled then
        M.append_test_aura(self._aura_map, show_key, aura_filter, short_threshold)
    else
        self._aura_map["__test_preview__"] = nil
    end

    local display_count = M.render_aura_map(
        self, self._aura_map, bar_mode, color, barBgC, max_limit, aura_filter, sort_mode, show_timer_text, barTextC
    )

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
