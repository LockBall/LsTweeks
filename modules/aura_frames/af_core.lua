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

local WOW_COOLDOWN_CATEGORIES = M.WOW_COOLDOWN_CATEGORIES

function M.uses_cooldown_icon_overlay(category, bar_mode, db)
    return (not bar_mode) and db and db["cooldown_mode_" .. category] == true
end

-- ============================================================================
-- TIMER TICKER



-- Shared ticker update path for all visible aura icon objects.
-- Runs from af_main.lua and keeps timer/bar text fresh between scans.
function M.tick_visible_icons(now)
    now = now or GetTime()
    local db = M.db
    local short_threshold = (db and db.short_threshold) or 60

    for _, frame in pairs(M.frames) do
        if frame:IsVisible() then
            local is_static_frame = (frame.category == "static")
            local show_timer_text = frame._show_timer_text
            local bar_mode = frame._bar_mode
            for i = 1, #frame.icons do
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
                    local show_cooldown_overlay = M.uses_cooldown_icon_overlay(frame.category, bar_mode, db)
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
                        local ok, live_duration = pcall(C_UnitAuras.GetAuraDuration, "player", obj.aura_index)
                        if not ok then live_duration = nil end
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
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_CooldownViewer")
    end
end

function M.update_blizz_cdm_visibility(category)
    if M.ensure_blizz_cdm_loaded then
        M.ensure_blizz_cdm_loaded()
    end
    local frame = M.get_cdm_viewer_frame and M.get_cdm_viewer_frame(category)
    if not frame then return end

    -- Do not call Hide() here. Hidden CDM viewers stop producing the live child
    -- aura/cooldown state we read; alpha keeps them active but invisible.
    local hide = M.db and M.db["hide_blizz_cdm_" .. category]
    if not hide and (not InCombatLockdown or not InCombatLockdown()) and frame.Show then
        pcall(frame.Show, frame)
    end
    frame:SetAlpha(hide and 0 or 1)
    frame:EnableMouse(not hide)
end

function M.prepare_blizz_cdm_viewer(category)
    if InCombatLockdown and InCombatLockdown() then return end
    if M.ensure_blizz_cdm_loaded then
        M.ensure_blizz_cdm_loaded()
    end
    local frame = M.get_cdm_viewer_frame and M.get_cdm_viewer_frame(category)
    if not frame then return end

    -- Utility can start hidden on reload. Show it once outside combat so
    -- Blizzard builds its child list, then apply alpha-based hiding.
    if frame.Show then
        pcall(frame.Show, frame)
    end
    if M.update_blizz_cdm_visibility then
        M.update_blizz_cdm_visibility(category)
    end
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

    local bar_bg_alpha  = M.BAR_BG_ALPHA_DEFAULT
    local bar_mode_key  = self._bar_mode_key or ("bar_mode_" .. category)
    self._bar_mode_key  = bar_mode_key
    local bar_mode      = cfg_db[bar_mode_key] ~= nil and cfg_db[bar_mode_key] or cfg_db["bar_mode"]
    local frame_width   = cfg_db["width_" .. category] or cfg_db["width"] or 200
    local spacing       = cfg_db[spacing_key] or cfg_db["spacing"] or 6
    local color         = M.get_setting(cfg_db, category, "color", { r = 1, g = 1, b = 1 })
    local barBgC        = M.get_setting(cfg_db, category, "bar_bg_color", { r = color.r, g = color.g, b = color.b, a = bar_bg_alpha })
    local barTextC      = M.get_setting(cfg_db, category, "bar_text_color", { r = 1, g = 1, b = 1 })
    local bgC           = M.get_setting(cfg_db, category, "bg_color", { r = 0, g = 0, b = 0, a = 0.5 })
    local show_timer_text = M.is_timer_text_enabled(cfg_db, category, timer_key)
    local cooldown_icon_overlay = M.uses_cooldown_icon_overlay(category, bar_mode, cfg_db)
    local layout_show_timer_text = show_timer_text and not cooldown_icon_overlay
    self._show_timer_text = show_timer_text
    self._bar_mode        = bar_mode
    local short_threshold = db.short_threshold or 60
    local growth        = cfg_db["growth_" .. category] or cfg_db["growth"] or "DOWN"
    local max_limit     = cfg_db["max_icons_" .. category] or cfg_db["max_icons"] or 40
    local sort_mode     = (not is_custom) and (cfg_db["sort_" .. category] or cfg_db["sort"] or "timeleft") or nil
    local in_combat = InCombatLockdown and InCombatLockdown()
    local is_user_positioning = self._is_user_positioning == true
    local show_val  = cfg_db[show_key] ~= nil and cfg_db[show_key] or cfg_db["show"]
    local preview_enabled = show_val and (cfg_db["test_aura_" .. category] or cfg_db["test_aura"])

    local scale = cfg_db[scale_key] or cfg_db["scale"] or 1.0
    if not in_combat and not is_user_positioning then
        self:SetScale(scale)
    end

    local _width  = frame_width
    local _height = self:GetHeight() or 50
    if _width  < 1 then _width  = 200 end
    if _height < 1 then _height = 50  end
    if not in_combat and not is_user_positioning then
        M.apply_saved_frame_position(self, scale_key, (aura_filter == "HARMFUL") and -25 or 75)
        self:SetSize(_width, _height)
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

    local is_moving = cfg_db[move_key] ~= nil and cfg_db[move_key] or cfg_db["move"]

    if not show_val and not is_moving and not preview_enabled then
        self:Hide()
        return
    end

    if is_moving then
        self.title_bar:Show()
        self.bottom_title_bar:Show()
        self.resizer:Show()
    else
        self.title_bar:Hide()
        self.bottom_title_bar:Hide()
        self.resizer:Hide()
    end

    if is_moving and not show_val and not preview_enabled then
        local timer_font_size = (M.get_timer_number_font_size and M.get_timer_number_font_size(category, self._cfg_db)) or 10
        local bar_layout = M.get_bar_layout_params(timer_font_size)
        local min_height
        if bar_mode then
            min_height = (bar_layout.row_height or 18) + spacing + 12
        else
            local timer_h  = layout_show_timer_text and 12 or 0
            local bot_pad  = layout_show_timer_text and 14 or 12
            min_height = 32 + timer_h + bot_pad
        end
        if not in_combat and not is_user_positioning then
            M.set_height_for_growth(self, min_height, growth)
        end
        self:Show()
        return
    end

    if show_val or preview_enabled then self:Show() end

    if not self._aura_map then self._aura_map = {} end
    self._sorted_ids_cache = nil

    -- Run the unified scan once per dirty event batch, then let the other
    -- preset frames in the same deferred batch reuse M._aura_map.
    if (not is_custom) and M._aura_scan_dirty then
        M.unified_scan(info, short_threshold, 0, 0)
        M._aura_scan_dirty = false
    end

    -- Filter the shared map into this frame's per-frame map.
    wipe(self._aura_map)
    if is_custom then
        if M.scan_custom_aura_map then
            M.scan_custom_aura_map(self, custom_entry, self._aura_map, max_limit, short_threshold)
        end
    else
        if WOW_COOLDOWN_CATEGORIES[category] and M.add_cooldown_viewer_category_entries then
            M.add_cooldown_viewer_category_entries(self._aura_map, category)
        else
            -- Preset frame: match by category string.
            for iid, entry in pairs(M._aura_map) do
                if entry.category == category then
                    self._aura_map[iid] = entry
                end
            end
        end
    end

    if WOW_COOLDOWN_CATEGORIES[category] and M.db and M.db.fade_wow_cooldown_ooc and not is_moving then
        self:SetAlpha(in_combat and 1 or (M.db.wow_cooldown_ooc_alpha or 0.35))
    else
        self:SetAlpha(1)
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

    if show_val or preview_enabled then
        self:Show()
        if not in_combat and not is_user_positioning then
            M.set_height_for_growth(self, new_height, growth)
        end
    elseif not is_moving then
        self:Hide()
    end

    if (show_val or preview_enabled) and not self:IsVisible() then self:Show() end

    local is_bg_enabled = cfg_db[bg_key] ~= nil and cfg_db[bg_key] or cfg_db["bg"]
    if is_moving then
        if is_bg_enabled and bgC then
            self:SetBackdropColor(bgC.r, bgC.g, bgC.b, bgC.a or 1)
            self:SetBackdropBorderColor(1, 1, 1, 1)
        else
            self:SetBackdropColor(0, 0, 0, 0.8)
            self:SetBackdropBorderColor(1, 1, 1, 1)
        end
    else
        if is_bg_enabled and bgC then
            self:SetBackdropColor(bgC.r, bgC.g, bgC.b, bgC.a or 1)
            self:SetBackdropBorderColor(0, 0, 0, 0)
        else
            self:SetBackdropColor(0, 0, 0, 0)
            self:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end
end
