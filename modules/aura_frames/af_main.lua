-- Bootstrap and frame construction for the aura frames module
-- loads last so all other af_* files have already populated M.
-- Creates preset and custom aura frames with their icon pools,
-- buckets UNIT_AURA events, starts the timer ticker, and registers the settings tab.

local addon_name, addon = ...
local M = addon.aura_frames

-- Runtime state tables. The saved DB is attached during ADDON_LOADED.
M.frames = M.frames or {}
M.controls = M.controls or {}

-- CACHED GLOBALS AND CONSTANTS
local MAX_POOL_SIZE = 20 -- Default pool size
local MIN_FRAME_WIDTH = 180
local MIN_FRAME_HEIGHT = 44
local format = string.format

local WOW_COOLDOWN_SHOW_KEYS = {
    "show_essential",
    "show_utility",
    "show_tracked_buffs",
    "show_tracked_bars",
}

local WOW_COOLDOWN_CATEGORIES = M.CDM_CATEGORIES
local UPDATE_INTERVALS = M.UPDATE_INTERVALS
local NEXT_FRAME_INTERVAL = UPDATE_INTERVALS.next_frame

local WOW_COOLDOWN_REFRESH_PROFILES = {
    immediate = {
        delays = { UPDATE_INTERVALS.next_frame },
        prepare_viewers = false,
        clear_child_cache = true,
    },
    hook = {
        delays = { UPDATE_INTERVALS.next_frame },
        prepare_viewers = false,
        clear_child_cache = false,
        defer_zero = true,
    },
    startup = {
        delays = {
            UPDATE_INTERVALS.fifth_sec,
            UPDATE_INTERVALS.six_tenths_sec,
            UPDATE_INTERVALS.one_point_two_sec,
            UPDATE_INTERVALS.two_point_five_sec,
            UPDATE_INTERVALS.five_sec,
        },
        prepare_viewers = true,
        clear_child_cache = true,
    },
    settings = {
        delays = {
            UPDATE_INTERVALS.next_frame,
            UPDATE_INTERVALS.fifth_sec,
            UPDATE_INTERVALS.six_tenths_sec,
            UPDATE_INTERVALS.one_point_two_sec,
        },
        prepare_viewers = true,
        clear_child_cache = true,
    },
}

M.NUMBER_FONT_OPTIONS = {
    {
        key = "source_code_pro",
        label = "Source Code Pro",
        path = "Interface\\AddOns\\LsTweeks\\media\\fonts\\SourceCodePro-Regular.ttf",
        size = 9,
        flags = "",
    },
    {
        key = "game_default",
        label = "Game Default",
        path = nil,
        size = nil,
        flags = nil,
    },
}

M.NUMBER_FONT_BOLD_PATHS = {
    source_code_pro = "Interface\\AddOns\\LsTweeks\\media\\fonts\\SourceCodePro-Bold.ttf",
}

local function get_number_font_def(key, category, cfg_db)
    local selected_key = key
    local db = cfg_db or M.db
    if not selected_key and db then
        if cfg_db and db.timer_number_font then
            selected_key = db.timer_number_font
        elseif category and db["timer_number_font_"..category] then
            selected_key = db["timer_number_font_"..category]
        else
            selected_key = db.timer_number_font
        end
    end
    selected_key = selected_key or "source_code_pro"
    for _, def in ipairs(M.NUMBER_FONT_OPTIONS) do
        if def.key == selected_key then
            return def
        end
    end
    return M.NUMBER_FONT_OPTIONS[1]
end

function M.get_number_font_options()
    return M.NUMBER_FONT_OPTIONS
end

function M.apply_number_font_to_text(font_string, category, cfg_db)
    if not font_string or not font_string.SetFont then return end
    local def = get_number_font_def(nil, category, cfg_db)
    local size = (M.get_timer_number_font_size and M.get_timer_number_font_size(category, cfg_db))
        or def.size
        or 10
    local flags = def.flags or ""

    -- Always pass an integer size to SetFont. WoW/FreeType rounds fractional
    -- sizes inconsistently; doing it ourselves keeps rendering deterministic.
    size = math.floor(size + 0.5)

    if size < 6 then size = 6 end
    if size > 18 then size = 18 end

    if def.path then
        local use_bold = false
        local db = cfg_db or M.db
        if db then
            local bold_key = category and ("timer_number_font_bold_"..category)
            if cfg_db and db.timer_number_font_bold ~= nil then
                use_bold = db.timer_number_font_bold
            elseif bold_key and db[bold_key] ~= nil then
                use_bold = db[bold_key]
            else
                use_bold = db.timer_number_font_bold or false
            end
        end
        local bold_path = use_bold and M.NUMBER_FONT_BOLD_PATHS[def.key]
        font_string:SetFont(bold_path or def.path, size, flags)
    elseif STANDARD_TEXT_FONT then
        font_string:SetFont(STANDARD_TEXT_FONT, size, flags)
    else
        font_string:SetFontObject(GameFontHighlightSmall)
    end

    if cfg_db or M.db then
        -- Custom frames store timer_color directly; preset frames use timer_color_<cat>.
        local c = M.get_setting and M.get_setting(cfg_db, category, "timer_color")
        if c then
            font_string:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
        end
    end
end

function M.apply_number_font_to_all()
    if not M.frames then return end
    for _, frame in pairs(M.frames) do
        if frame and frame.icons then
            local category = frame.category
            local cfg_db = frame._cfg_db
            for _, obj in ipairs(frame.icons) do
                if obj and obj.time_text then
                    M.apply_number_font_to_text(obj.time_text, category, cfg_db)
                end
            end
        end
    end
end

local function run_wow_cooldown_refresh(refresh_config)
    if not M.frames then return end
    if refresh_config.prepare_viewers and M.prepare_blizz_cdm_viewer then
        for _, category in ipairs(WOW_COOLDOWN_CATEGORIES) do
            M.prepare_blizz_cdm_viewer(category)
        end
    end
    if refresh_config.clear_child_cache and M.clear_cooldown_viewer_child_cache then
        for _, category in ipairs(WOW_COOLDOWN_CATEGORIES) do
            M.clear_cooldown_viewer_child_cache(category)
        end
    end
    for _, show_key in ipairs(WOW_COOLDOWN_SHOW_KEYS) do
        local frame = M.frames[show_key]
        local p = frame and frame.update_params
        if p then
            frame._sorted_ids_cache = nil
            M.update_auras(frame, p.show_key, p.move_key, p.timer_key, p.bg_key, p.scale_key, p.spacing_key, p.aura_filter)
        end
    end
end

local function schedule_wow_cooldown_refresh(delay, refresh_config)
    delay = delay or 0
    M._cdm_refresh_pending = M._cdm_refresh_pending or {}
    local key = tostring(delay)
        .. "|" .. tostring(refresh_config.prepare_viewers == true)
        .. "|" .. tostring(refresh_config.clear_child_cache == true)
        .. "|" .. tostring(refresh_config.defer_zero == true)
    if M._cdm_refresh_pending[key] then return end

    local function refresh()
        M._cdm_refresh_pending[key] = nil
        run_wow_cooldown_refresh(refresh_config)
    end

    M._cdm_refresh_pending[key] = true
    if (delay > 0 or refresh_config.defer_zero) and C_Timer and C_Timer.After then
        C_Timer.After(delay, refresh)
    else
        refresh()
    end
end

function M.queue_wow_cooldown_refresh(profile)
    local refresh_config = type(profile) == "table" and profile
        or WOW_COOLDOWN_REFRESH_PROFILES[profile or "immediate"]
        or WOW_COOLDOWN_REFRESH_PROFILES.immediate
    local delays = refresh_config.delays or { refresh_config.delay or 0 }
    for _, delay in ipairs(delays) do
        schedule_wow_cooldown_refresh(delay, refresh_config)
    end
end

-- AURA CONTAINER GENERATOR
function M.create_aura_frame(show_key, move_key, timer_key, bg_key, scale_key, spacing_key, display_name, is_debuff, frame_opts)
    local category = show_key:sub(6)
    frame_opts = frame_opts or {}
    local bar_bg_alpha = M.BAR_BG_ALPHA_DEFAULT
    local frame = CreateFrame("Frame", "LsTweaksAuraFrame_"..show_key, UIParent, "BackdropTemplate")
    frame.category = category
    frame.is_custom = frame_opts.is_custom == true
    frame.custom_entry = frame_opts.custom_entry
    frame._cfg_db = frame_opts.cfg_db
    
    M.apply_tooltip_panel_backdrop(frame)

    frame:SetMovable(true) 
    frame:SetResizable(true) 
    frame:SetClampedToScreen(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT)
    end
    local cfg_db = frame._cfg_db or M.db
    local initial_width = cfg_db["width_"..category] or cfg_db["width"] or 200
    if initial_width < MIN_FRAME_WIDTH then initial_width = MIN_FRAME_WIDTH end
    frame:SetSize(initial_width, 50)

    M.apply_saved_frame_position(frame, scale_key, is_debuff and -25 or 75)
    
    -- TITLE BAR LOGIC
    local TITLEBAR_ANCHORS = {
        top =    { from = "BOTTOM", to = "TOP", offset = -2 },
        bottom = { from = "TOP",    to = "BOTTOM", offset = 2 },
    }

    local function CreateTitleBar(parent, label, is_bottom)
        local cfg = is_bottom and TITLEBAR_ANCHORS.bottom or TITLEBAR_ANCHORS.top
        local tb = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        tb:SetPoint(cfg.from.."LEFT",  parent, cfg.to.."LEFT",  0, cfg.offset)
        tb:SetPoint(cfg.from.."RIGHT", parent, cfg.to.."RIGHT", 0, cfg.offset)
        tb:SetHeight(20)
        M.apply_title_bar_backdrop(tb)
        local text = tb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(label)
        tb.label_text = text
        tb:EnableMouse(true)
        tb:RegisterForDrag("LeftButton")
        tb:SetScript("OnDragStart", function() M.start_frame_drag(parent) end)
        tb:SetScript("OnDragStop", function()
            M.stop_frame_drag(parent, scale_key)
        end)
        return tb
    end
    
    frame.title_bar = CreateTitleBar(frame, display_name, false)
    frame.bottom_title_bar = CreateTitleBar(frame, display_name, true)
    
    -- RESIZER
    frame.resizer = CreateFrame("Button", nil, frame)
    frame.resizer:SetSize(16, 16)
    frame.resizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    frame:SetScript("OnSizeChanged", function(s, w)
        if s._clamping_size then return end
        if w and w < MIN_FRAME_WIDTH then
            s._clamping_size = true
            s:SetWidth(MIN_FRAME_WIDTH)
            s._clamping_size = nil
        end
    end)

    frame.resizer:SetScript("OnMouseDown", function()
        frame._is_user_positioning = true
        frame:StartSizing("RIGHT")
    end)
    frame.resizer:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        frame._is_user_positioning = nil
        local clamped_width = frame:GetWidth()
        if clamped_width < MIN_FRAME_WIDTH then
            clamped_width = MIN_FRAME_WIDTH
            frame:SetWidth(clamped_width)
        end
        M.db["width_"..category] = clamped_width
        local ws = M.controls and M.controls["width_slider_"..category]
        if ws and ws.slider then ws.slider:SetValue(clamped_width) end
        local params = frame.update_params
        if params then
            M.update_auras(frame, params.show_key, params.move_key, params.timer_key, params.bg_key, params.scale_key, params.spacing_key, params.aura_filter)
        end
    end)

    -- ICON POOL MANAGEMENT    Pre-create set number of icons/bars to avoid combat lockdown errors
    frame.icons = {}
    local pool_size = M.db["max_icons_"..category] or MAX_POOL_SIZE
    local bar_bg_default = M.db["bar_bg_color_"..category] or M.db["color_"..category] or { r = 1, g = 1, b = 1, a = bar_bg_alpha }

    for i = 1, pool_size do
        local obj = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        obj:Hide()
        
        -- Icon Texture
        obj.texture = obj:CreateTexture(nil, "ARTWORK")

        -- Native cooldown overlay for spell-cooldown mode. Pre-created so combat
        -- updates can feed Blizzard DurationObjects without creating frames.
        obj.cooldown = CreateFrame("Cooldown", nil, obj, "CooldownFrameTemplate")
        obj.cooldown:SetAllPoints(obj)
        obj.cooldown:SetDrawEdge(false)
        obj.cooldown:SetDrawSwipe(true)
        obj.cooldown:SetDrawBling(false)
        obj.cooldown:SetHideCountdownNumbers(false)
        obj.cooldown:Hide()

        -- Status Bar (for bar mode)
        obj.bar = CreateFrame("StatusBar", nil, obj)
        obj.bar:EnableMouse(false)
        obj.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        obj.bar:SetMinMaxValues(0, 1)
        obj.bar_bg = obj.bar:CreateTexture(nil, "BACKGROUND")
        obj.bar_bg:SetAllPoints()
        obj.bar_bg:SetColorTexture(bar_bg_default.r, bar_bg_default.g, bar_bg_default.b, bar_bg_default.a or bar_bg_alpha)
        obj.bar:Hide()
        
        -- Text Overlay Frame - created AFTER bar so it renders on top
        -- This is a separate frame layer that ensures text is always visible above the bar
        obj.text_overlay = CreateFrame("Frame", nil, obj)
        obj.text_overlay:EnableMouse(false)
        obj.text_overlay:SetFrameLevel(obj.bar:GetFrameLevel() + 1)

        -- Stack slot: left zone of bar (stack count display area)
        obj.stack_slot = CreateFrame("Frame", nil, obj.text_overlay)
        M.add_debug_outline(obj.stack_slot, 1, 0.4, 0, 0.9)

        -- Name slot: middle zone of bar
        obj.name_slot = CreateFrame("Frame", nil, obj.text_overlay)
        M.add_debug_outline(obj.name_slot, 0, 0.6, 1, 0.9)

        -- Text - create as children of text_overlay so they render above the bar
        obj.name_text  = obj.text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall", 7)
        obj.name_text:SetJustifyH("LEFT")
        obj.name_text:SetWordWrap(false)
        if obj.name_text.SetMaxLines then
            obj.name_text:SetMaxLines(1)
        end

        -- Timer slot: right zone of bar; timer text anchors here so glyph width
        -- changes do not affect the timer's reference position.
        obj.timer_slot = CreateFrame("Frame", nil, obj.text_overlay)
        M.add_debug_outline(obj.timer_slot, 0, 1, 0.3, 0.9)

        obj.time_text  = obj.text_overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall", 7)
        M.apply_number_font_to_text(obj.time_text, category)
        obj.time_text:SetWordWrap(false)
        if obj.time_text.SetMaxLines then
            obj.time_text:SetMaxLines(1)
        end

        -- Stack count (shown bottom-right of icon in icon mode; in stack_slot in bar mode)
        obj.count_text = obj.text_overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        obj.count_text:Hide()
        
        -- Tooltip
        obj:EnableMouse(true)
        obj:SetScript("OnEnter", function(s)
            if not s.aura_name then return end
            
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:ClearLines()
            
            local updated = false
            if s.aura_index then
                -- Modern API (12.0.5+): stable auraInstanceID lookup, no index fragility
                local ok, result = pcall(function()
                    return GameTooltip:SetUnitAuraByAuraInstanceID("player", s.aura_index)
                end)
                updated = ok and result
            end

            if not updated then
                GameTooltip:AddLine(s.aura_name, 1, 1, 1)
                if s.aura_duration and s.aura_duration > 0 then
                    local remaining_str = s.aura_remaining and format("%.1f", s.aura_remaining) or "?"
                    local duration_str = format("%.1f", s.aura_duration)
                    GameTooltip:AddLine(remaining_str .. "s / " .. duration_str .. "s", 0.7, 0.7, 1)
                else
                    GameTooltip:AddLine("(Permanent)", 0.7, 0.7, 1)
                end
            end

            if M.db and M.db.show_spell_id and s.aura_spell_id then
                GameTooltip:AddLine("Spell ID: " .. tostring(s.aura_spell_id), 0.6, 0.6, 0.6)
                -- Force rerender: SetUnitAuraByAuraInstanceID calls Show() internally,
                -- so the tooltip is already visible when we append; calling Show() again
                -- flushes the new line into the layout.
                GameTooltip:Show()
            end

            GameTooltip:Show()
        end)
        obj:SetScript("OnLeave", function() 
            GameTooltip:Hide() 
        end)

        frame.icons[i] = obj
    end

    -- Map-based aura cache: auraInstanceID → entry table. Persists across events.
    frame._aura_map = {}

    frame:RegisterUnitEvent("UNIT_AURA", "player")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Combat start
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Combat end
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    if M.WOW_COOLDOWN_CATEGORIES and M.WOW_COOLDOWN_CATEGORIES[category] then
        frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    end
    
    -- Store parameters on frame itself for robust access during callbacks
    frame.update_params = {
        show_key = show_key,
        move_key = move_key,
        timer_key = timer_key,
        bg_key = bg_key,
        scale_key = scale_key,
        spacing_key = spacing_key,
        category = category,
        aura_filter = frame_opts.aura_filter or (is_debuff and "HARMFUL" or "HELPFUL")
    }
    
    frame:SetScript("OnEvent", function(self, event, unit, info)
        local params = self.update_params
        if not params then return end

        local relevant = (event == "UNIT_AURA" and unit == "player")
            or event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_REGEN_DISABLED"
            or event == "PLAYER_REGEN_ENABLED"
            or event == "PLAYER_SPECIALIZATION_CHANGED"
            or event == "SPELL_UPDATE_COOLDOWN"
            or event == "SPELL_UPDATE_CHARGES"

        if not relevant then return end

        -- KEY: do NOT scan inside the event handler.
        -- ElkBuffBars uses a short RegisterBucketEvent("UNIT_AURA") delay for exactly this reason:
        -- C_UnitAuras calls made directly in OnEvent return "secret values" in combat
        -- because the execution context is still tainted by the event dispatch.
        -- Deferring through the aura bucket runs the scan after the tainted
        -- event context exits, so aura fields return clean, readable values.
        --
        -- Merge UNIT_AURA payloads while waiting for the deferred scan.
        if event == "UNIT_AURA" then
            self._pending_aura_info = M.merge_aura_info(self._pending_aura_info, info)
        end
        if event ~= "SPELL_UPDATE_COOLDOWN" and event ~= "SPELL_UPDATE_CHARGES" then
            M.mark_aura_scan_dirty()
        end

        -- Deduplication: if a scan is already queued for this frame, don't queue another.
        -- Multiple rapid UNIT_AURA events (common in combat) collapse to one scan.
        if not self._scan_pending then
            self._scan_pending = true
            local f = self
            -- A tenth second matches ElkBuffBars' short UNIT_AURA bucket and
            -- coalesces noisy event bursts without making aura changes feel late.
            -- This ensures the scan runs outside the event-dispatch taint window.
            C_Timer.After(UPDATE_INTERVALS.tenth_sec, function()
                f._scan_pending = false
                local event_info = f._pending_aura_info
                f._pending_aura_info = nil
                M.update_auras(f, params.show_key, params.move_key, params.timer_key,
                    params.bg_key, params.scale_key, params.spacing_key, params.aura_filter, event_info)
            end)
        end
    end)
    
    M.frames[show_key] = frame
    return frame
end

-- ============================================================================
-- CUSTOM FRAME LIFECYCLE

-- Builds the WoW frame for a custom entry. Called at load (for saved entries)
-- and at runtime (when user clicks + Custom). The frame is keyed by entry.id.
function M.create_custom_frame(entry)
    if not entry or not entry.id then return end
    local id       = entry.id
    local show_key = "show_" .. id  -- e.g. "show_custom_1"
    entry.aura_base_filter = (entry.aura_base_filter == "HARMFUL" or entry.filter == "HARMFUL") and "HARMFUL" or "HELPFUL"
    entry.aura_modifier = entry.aura_modifier or "NONE"
    local aura_filter = M.get_custom_aura_filter and M.get_custom_aura_filter(entry) or entry.aura_base_filter

    -- Custom frames use flat keys ("timer", "bg", etc.) inside the entry table,
    -- not the prefixed pattern used by preset frames ("timer_static", etc.).
    local frame = M.create_aura_frame(
        show_key,
        "move",
        "timer",
        "bg",
        "scale",
        "spacing",
        entry.name or id,
        aura_filter:find("HARMFUL", 1, true) ~= nil,
        {
            is_custom = true,
            custom_entry = entry,
            cfg_db = entry,
            aura_filter = aura_filter,
        }
    )

    -- Override update_params to use flat entry keys and the selected AuraFilters string.
    frame.update_params.show_key    = show_key
    frame.update_params.move_key    = "move"
    frame.update_params.timer_key   = "timer"
    frame.update_params.bg_key      = "bg"
    frame.update_params.scale_key   = "scale"
    frame.update_params.spacing_key = "spacing"
    frame.update_params.aura_filter = aura_filter

    -- Override resizer OnMouseUp: write width to entry.width instead of flat DB key.
    if frame.resizer then
        frame.resizer:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            frame._is_user_positioning = nil
            local w = frame:GetWidth()
            if w < MIN_FRAME_WIDTH then w = MIN_FRAME_WIDTH; frame:SetWidth(w) end
            entry.width = w
            local ws = M.controls and M.controls["custom_" .. id .. "_width"]
            if ws and ws.slider then ws.slider:SetValue(w) end
            local current_filter = frame.update_params and frame.update_params.aura_filter or aura_filter
            M.update_auras(frame, show_key, "move", "timer", "bg", "scale", "spacing", current_filter)
        end)
    end

    -- Override OnDragStop for title bars: write position to entry.position.
    local function on_drag_stop()
        M.stop_frame_drag(frame, "scale")
    end
    if frame.title_bar then
        frame.title_bar:SetScript("OnDragStop", on_drag_stop)
    end
    if frame.bottom_title_bar then
        frame.bottom_title_bar:SetScript("OnDragStop", on_drag_stop)
    end

    return frame
end

-- Creates a new entry, persists it to DB, builds the WoW frame, and returns the entry.
function M.spawn_custom_frame()
    if not M.db then return nil end
    M.db.custom_frames = M.db.custom_frames or {}
    if #M.db.custom_frames >= (M.MAX_CUSTOM_FRAMES or 4) then return nil end

    local entry = M.new_custom_entry()
    table.insert(M.db.custom_frames, entry)
    M.create_custom_frame(entry)
    return entry
end

-- Hides and fully removes a custom frame by id. Removes DB entry.
function M.destroy_custom_frame(id)
    if not id then return end
    local show_key = "show_" .. id
    local frame    = M.frames[show_key]
    if frame then
        frame:Hide()
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        M.frames[show_key] = nil
    end
    if M.db and M.db.custom_frames then
        for i, entry in ipairs(M.db.custom_frames) do
            if entry.id == id then
                table.remove(M.db.custom_frames, i)
                break
            end
        end
    end
    if M.controls then
        local prefix = "custom_" .. id .. "_"
        for key in pairs(M.controls) do
            if type(key) == "string" and key:sub(1, #prefix) == prefix then
                M.controls[key] = nil
            end
        end
    end
end

-- ============================================================================
-- INITIALIZATION ENGINE: Orchestrate startup of aura frames once addon data is loaded
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name == addon_name then
        -- Ensure the sub-table exists and link the module to the core database
        if not Ls_Tweeks_DB.aura_frames then Ls_Tweeks_DB.aura_frames = {} end
        M.db = Ls_Tweeks_DB.aura_frames

        -- Session-scoped spell learning tables: reset every login, never written to DB.
        M._known_static = {}
        M._known_long   = {}
        M._aura_scan_dirty = true

        -- Populate missing settings using the defaults defined in af_defaults.lua
        if M.defaults then addon.apply_defaults(M.defaults, M.db) end

        if not M.db.timer_number_font then
            M.db.timer_number_font = "source_code_pro"
        end
        if not M.db.timer_number_font_size then
            M.db.timer_number_font_size = (M.get_timer_number_font_size and M.get_timer_number_font_size()) or 10
        end

        -- Migrate legacy global font settings to per-category settings.
        -- Static frame has no timer text, so it does not need per-category timer font settings.
        for _, cat in ipairs(M.TIMER_CATEGORIES) do
            local font_key = "timer_number_font_"..cat
            local size_key = "timer_number_font_size_"..cat
            if not M.db[font_key] then
                M.db[font_key] = M.db.timer_number_font or "source_code_pro"
            end
            if not M.db[size_key] then
                M.db[size_key] = (M.get_timer_number_font_size and M.get_timer_number_font_size()) or 10
            end
            local bold_key = "timer_number_font_bold_"..cat
            if M.db[bold_key] == nil then
                M.db[bold_key] = M.db.timer_number_font_bold or false
            end
        end

        local bar_bg_alpha = M.BAR_BG_ALPHA_DEFAULT

        -- Migrate legacy neutral bar background defaults to color-matched default alpha.
        -- Only updates untouched old default values.
        local function is_legacy_bar_bg(c)
            return type(c) == "table"
                and c.r == 0.6 and c.g == 0.6 and c.b == 0.6
                and (c.a == 0.25 or c.a == nil)
        end
        for _, cat in ipairs(M.CATEGORIES) do
            local bg_key = "bar_bg_color_" .. cat
            if is_legacy_bar_bg(M.db[bg_key]) then
                local fill = M.db["color_" .. cat] or { r = 1, g = 1, b = 1 }
                M.db[bg_key] = { r = fill.r, g = fill.g, b = fill.b, a = bar_bg_alpha }
            end
        end
        
        -- Create the visual containers for each specific category
        M.create_aura_frame("show_static",  "move_static",  "timer_static", "bg_static",    "scale_static", "spacing_static",   "Static",   false)
        M.create_aura_frame("show_short",   "move_short",   "timer_short",  "bg_short",     "scale_short",  "spacing_short",    "Short",    false)
        M.create_aura_frame("show_long",    "move_long",    "timer_long",   "bg_long",      "scale_long",   "spacing_long",     "Long",     false)
        M.create_aura_frame("show_essential", "move_essential", "timer_essential", "bg_essential", "scale_essential", "spacing_essential", "Essential", false)
        M.create_aura_frame("show_utility", "move_utility", "timer_utility", "bg_utility", "scale_utility", "spacing_utility", "Utility", false)
        M.create_aura_frame("show_tracked_buffs", "move_tracked_buffs", "timer_tracked_buffs", "bg_tracked_buffs", "scale_tracked_buffs", "spacing_tracked_buffs", "Tracked Buffs", false)
        M.create_aura_frame("show_tracked_bars", "move_tracked_bars", "timer_tracked_bars", "bg_tracked_bars", "scale_tracked_bars", "spacing_tracked_bars", "Tracked Bars", false)
        M.create_aura_frame("show_debuff",  "move_debuff",  "timer_debuff", "bg_debuff",    "scale_debuff", "spacing_debuff",   "Debuffs",  true)

        -- Create saved custom filtered frames.
        if M.db.custom_frames then
            for _, entry in ipairs(M.db.custom_frames) do
                M.create_custom_frame(entry)
            end
        end

        -- Migrate any stored positions to TOPLEFT-anchor format.
        -- Defer one frame so GetLeft()/GetTop() return valid screen coordinates.
        C_Timer.After(NEXT_FRAME_INTERVAL, function()
            for _, frame in pairs(M.frames) do
                local pos = M.get_frame_position_table and M.get_frame_position_table(frame)
                if pos and pos.point ~= "TOPLEFT" then
                    local x, y = M.sync_frame_position_to_db and M.sync_frame_position_to_db(frame, pos)
                    if x and y then
                        M.apply_saved_frame_position(frame)
                    end
                end
            end
        end)

        -- Timer text and bar fill need smooth tenths; heavier aura scans stay event-bucketed.
        -- Logic is delegated so af_main stays focused on construction/bootstrap.
        C_Timer.NewTicker(UPDATE_INTERVALS.tenth_sec, function()
            M.tick_visible_icons()
        end)

        -- Sync the Blizzard frame visibility based on user preferences
        M.toggle_blizz_buffs(not M.db.enable_blizz_buffs)
        M.toggle_blizz_debuffs(not M.db.enable_blizz_debuffs)
        M.queue_wow_cooldown_refresh("startup")

        -- Integrate the settings tab into the main addon configuration menu
        if addon.register_category and M.BuildSettings then
            addon.register_category("Buffs & Debuffs", function(parent) M.BuildSettings(parent) end)
        end

        M.create_grid_overlay()

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- RESET AND REFRESH: Restores UI states following a settings reset or global change
function M.on_reset_complete()
    M.toggle_blizz_buffs(not M.db.enable_blizz_buffs)
    M.toggle_blizz_debuffs(not M.db.enable_blizz_debuffs)
    M.apply_number_font_to_all()
    if M.set_grid_visible then M.set_grid_visible(M.db.show_grid == true) end

    local valid_custom_ids = {}
    for _, entry in ipairs(M.db.custom_frames or {}) do
        if entry.id then valid_custom_ids[entry.id] = true end
    end
    local orphan_custom_ids = {}
    for show_key, frame in pairs(M.frames) do
        if frame.is_custom then
            local id = frame.custom_entry and frame.custom_entry.id or show_key:match("^show_(.+)$")
            if id and not valid_custom_ids[id] then
                orphan_custom_ids[#orphan_custom_ids + 1] = id
            end
        end
    end
    for _, id in ipairs(orphan_custom_ids) do
        M.destroy_custom_frame(id)
    end

    for _, frame in pairs(M.frames) do
        local p = frame.update_params
        if p then
            frame._layout_cache = nil
            -- Re-link custom entry reference in case DB was replaced by reset.
            if frame.is_custom and frame.custom_entry then
                local id = frame.custom_entry.id
                if M.db.custom_frames then
                    for _, entry in ipairs(M.db.custom_frames) do
                        if entry.id == id then frame.custom_entry = entry; break end
                    end
                end
                p.aura_filter = M.get_custom_aura_filter and M.get_custom_aura_filter(frame.custom_entry) or p.aura_filter
            end
            M.update_auras(frame, p.show_key, p.move_key, p.timer_key, p.bg_key, p.scale_key, p.spacing_key, p.aura_filter)
        end
    end

    if M.sync_general_controls_from_db then
        M.sync_general_controls_from_db()
    end
    if M.refresh_frames_tree then
        M.refresh_frames_tree()
    end
end
