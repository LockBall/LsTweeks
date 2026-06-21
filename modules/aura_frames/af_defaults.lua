-- Aura frame constants and default DB values.
-- Defines category lists, CDM frame mappings, and per-category defaults.
-- Runtime files should read these values instead of repeating category names
-- or default settings.
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

-- Single source for built-in Aura Frame categories. Derived tables below keep
-- older call sites stable while preventing separate category lists from drifting.
M.FRAME_DEFS = {
    {
        key = "static",
        label = "Static",
        timer = false,
        cdm = false,
        is_debuff = false,
        tree_order = 1,
        test_label = "Test Static Buff",
        test_sort_id = 1,
    },
    {
        key = "short",
        label = "Short",
        timer = true,
        cdm = false,
        is_debuff = false,
        tree_order = 3,
        test_label = "Test Short Buff",
        test_sort_id = 2,
    },
    {
        key = "long",
        label = "Long",
        timer = true,
        cdm = false,
        is_debuff = false,
        tree_order = 4,
        test_label = "Test Long Buff",
        test_sort_id = 3,
    },
    {
        key = "essential",
        label = "Essential",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "EssentialCooldownViewer",
        tree_order = 5,
        test_label = "Test Essential Buff",
        test_sort_id = 5,
    },
    {
        key = "utility",
        label = "Utility",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "UtilityCooldownViewer",
        tree_order = 6,
        test_label = "Test Utility Buff",
        test_sort_id = 6,
    },
    {
        key = "tracked_buffs",
        label = "Tracked Buffs",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "BuffIconCooldownViewer",
        tree_order = 7,
        test_label = "Test Tracked Buff",
        test_sort_id = 7,
    },
    {
        key = "tracked_bars",
        label = "Tracked Bars",
        timer = true,
        cdm = true,
        is_debuff = false,
        cdm_viewer = "BuffBarCooldownViewer",
        tree_order = 8,
        test_label = "Test Tracked Bar",
        test_sort_id = 8,
    },
    {
        key = "debuff",
        label = "DeBuff",
        frame_label = "Debuffs",
        timer = true,
        cdm = false,
        is_debuff = true,
        tree_order = 2,
        test_label = "Test DeBuff",
        test_sort_id = 9,
    },
}

M.FRAME_DEFS_BY_KEY = {}
M.CATEGORIES = {}
M.TIMER_CATEGORIES = {}
M.CDM_CATEGORIES = {}
M.WOW_COOLDOWN_CATEGORIES = {}
M.CDM_VIEWER_FRAMES = {}

for _, frame_def in ipairs(M.FRAME_DEFS) do
    M.FRAME_DEFS_BY_KEY[frame_def.key] = frame_def
    M.CATEGORIES[#M.CATEGORIES + 1] = frame_def.key
    if frame_def.timer then
        M.TIMER_CATEGORIES[#M.TIMER_CATEGORIES + 1] = frame_def.key
    end
    if frame_def.cdm then
        M.CDM_CATEGORIES[#M.CDM_CATEGORIES + 1] = frame_def.key
        M.WOW_COOLDOWN_CATEGORIES[frame_def.key] = true
    end
    if frame_def.cdm_viewer then
        M.CDM_VIEWER_FRAMES[frame_def.key] = frame_def.cdm_viewer
    end
end

function M.get_frame_def(category)
    return M.FRAME_DEFS_BY_KEY[category]
end

function M.get_preset_keys(category)
    return {
        show_key = "show_" .. category,
        move_key = "move_" .. category,
        timer_key = "timer_" .. category,
        bg_key = "bg_" .. category,
        scale_key = "scale_" .. category,
        spacing_key = "spacing_" .. category,
    }
end

function M.get_frame_def_from_show_key(show_key)
    if type(show_key) ~= "string" then return nil end
    local category = show_key:gsub("^show_", "")
    return M.get_frame_def(category)
end

M.UPDATE_INTERVALS = addon.UPDATE_INTERVALS

M.DEFAULT_FRAME_WIDTH = 200
M.MIN_FRAME_WIDTH = 180
M.MAX_FRAME_WIDTH = 800
M.MIN_FRAME_HEIGHT = 44
M.DEFAULT_MAX_ICONS = 20
M.MAX_ICONS_LIMIT = 40
M.DEFAULT_SHORT_THRESHOLD = 60
M.DEFAULT_TIMER_NUMBER_FONT_KEY = "source_code_pro"
M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA = 0.35
M.DEFAULT_OOC_FADE_DELAY = 2
M.DEFAULT_OOC_FADE_LENGTH = 3

M.CUSTOM_AURA_BASE_FILTERS = {
    { value = "HELPFUL", text = "HELPFUL" },
    { value = "HARMFUL", text = "HARMFUL" },
}

M.CUSTOM_AURA_MODIFIERS = {
    { value = "NONE", text = "NONE" },
    { value = "IMPORTANT", text = "IMPORTANT" },
    { value = "PLAYER", text = "PLAYER" },
    { value = "RAID", text = "RAID" },
    { value = "RAID_IN_COMBAT", text = "RAID_IN_COMBAT" },
    { value = "INCLUDE_NAME_PLATE_ONLY", text = "INCLUDE_NAME_PLATE_ONLY" },
    { value = "MAW", text = "MAW" },
    { value = "CANCELABLE", text = "CANCELABLE", force_base = "HELPFUL" },
    { value = "NOT_CANCELABLE", text = "NOT_CANCELABLE", force_base = "HELPFUL" },
    { value = "BIG_DEFENSIVE", text = "BIG_DEFENSIVE", force_base = "HELPFUL" },
    { value = "EXTERNAL_DEFENSIVE", text = "EXTERNAL_DEFENSIVE", force_base = "HELPFUL" },
    { value = "CROWD_CONTROL", text = "CROWD_CONTROL", force_base = "HARMFUL" },
    { value = "RAID_PLAYER_DISPELLABLE", text = "RAID_PLAYER_DISPELLABLE", force_base = "HARMFUL" },
}

M.CUSTOM_AURA_MODIFIERS_BY_VALUE = {}
for _, def in ipairs(M.CUSTOM_AURA_MODIFIERS) do
    M.CUSTOM_AURA_MODIFIERS_BY_VALUE[def.value] = def
end

-- Shared default background color and opacity.
M.BAR_BG_ALPHA_DEFAULT = 0.50
M.BAR_BG_GRAY_DEFAULT = 0.50

local function default_bg_color()
    return {
        r = M.BAR_BG_GRAY_DEFAULT,
        g = M.BAR_BG_GRAY_DEFAULT,
        b = M.BAR_BG_GRAY_DEFAULT,
        a = M.BAR_BG_ALPHA_DEFAULT,
    }
end

-- The Data: strictly default values
M.defaults = {
    last_frames_node = "static",
    last_tab_index = 1,

    -- Global Toggles
    enable_blizz_buffs = true,
    enable_blizz_debuffs = true,
    snap_to_grid   = true,
    show_grid      = true,
    show_bar_section_outlines = false,
    cancel_modifier = "CTRL",
    short_threshold = M.DEFAULT_SHORT_THRESHOLD,
    timer_number_font = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size = 10,
    timer_number_font_bold = false,

    -- STATIC
    show_static     = true,
    move_static     = true,
    timer_static    = false,
    tooltip_static  = true,
    bg_static       = false,
    scale_static    = 1.0,
    spacing_static  = 2.0,
    width_static    = M.DEFAULT_FRAME_WIDTH,
    bar_mode_static = false,
    color_static    = { r = 0, g = 0.5, b = 1 },
    bar_bg_color_static = default_bg_color(),
    fade_ooc_static = false,
    ooc_alpha_static = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_static = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_static = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_static = M.DEFAULT_MAX_ICONS,
    growth_static = "RIGHT",
    bg_color_static = default_bg_color(),
    sort_static  = "name",
    test_aura_static = true,

    bar_text_color_static = { r = 1, g = 1, b = 1 },

    -- SHORT
    show_short      = true,
    move_short      = true,
    timer_short     = true,
    timer_swipe_short = true,
    tooltip_short   = true,
    bg_short        = false,
    scale_short     = 1.0,
    spacing_short   = 1.5,
    width_short     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_short  = true,
    color_short     = { r = 0, g = 0.5, b = 1 },
    bar_bg_color_short = default_bg_color(),
    fade_ooc_short = false,
    ooc_alpha_short = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_short = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_short = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_short = M.DEFAULT_MAX_ICONS,
    growth_short = "DOWN",
    bg_color_short = default_bg_color(),
    sort_short   = "timeleft",
    test_aura_short = true,
    timer_number_font_short = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size_short = 10,
    timer_number_font_bold_short = false,
    timer_color_short = { r = 1, g = 1, b = 1 },
    bar_text_color_short = { r = 1, g = 1, b = 1 },

    -- LONG
    show_long       = true,
    move_long       = true,
    timer_long      = true,
    timer_swipe_long = true,
    tooltip_long    = true,
    bg_long         = false,
    scale_long      = 1.0,
    spacing_long    = 2.0,
    width_long      = M.DEFAULT_FRAME_WIDTH,
    bar_mode_long   = false,
    color_long      = { r = 0, g = 0.5, b = 1 },
    bar_bg_color_long = default_bg_color(),
    fade_ooc_long = false,
    ooc_alpha_long = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_long = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_long = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_long  = M.DEFAULT_MAX_ICONS,
    growth_long = "RIGHT",
    bg_color_long = default_bg_color(),
    sort_long    = "timeleft",
    test_aura_long = true,
    timer_number_font_long = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size_long = 10,
    timer_number_font_bold_long = false,
    timer_color_long = { r = 1, g = 1, b = 1 },
    bar_text_color_long = { r = 1, g = 1, b = 1 },

    -- ESSENTIAL
    cooldown_mode_essential = false,
    hide_blizz_cdm_essential = false,
    show_essential      = false,
    move_essential      = false,
    timer_essential     = true,
    timer_swipe_essential = true,
    tooltip_essential   = true,
    bg_essential        = false,
    scale_essential     = 1.0,
    spacing_essential   = 1.5,
    width_essential     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_essential  = false,
    color_essential     = { r = 1, g = 0.45, b = 0.25 },
    bar_bg_color_essential = default_bg_color(),
    fade_ooc_essential = true,
    ooc_alpha_essential = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_essential = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_essential = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_essential = M.DEFAULT_MAX_ICONS,
    growth_essential = "RIGHT",
    bg_color_essential = default_bg_color(),
    sort_essential = "timeleft",
    test_aura_essential = false,
    timer_number_font_essential = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size_essential = 10,
    timer_number_font_bold_essential = false,
    timer_color_essential = { r = 1, g = 1, b = 1 },
    bar_text_color_essential = { r = 1, g = 1, b = 1 },

    -- UTILITY
    cooldown_mode_utility = true,
    hide_blizz_cdm_utility = false,
    show_utility      = false,
    move_utility      = false,
    timer_utility     = true,
    timer_swipe_utility = true,
    tooltip_utility   = true,
    bg_utility        = false,
    scale_utility     = 1.0,
    spacing_utility   = 1.5,
    width_utility     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_utility  = false,
    color_utility     = { r = 0.65, g = 0.55, b = 1 },
    bar_bg_color_utility = default_bg_color(),
    fade_ooc_utility = true,
    ooc_alpha_utility = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_utility = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_utility = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_utility = M.DEFAULT_MAX_ICONS,
    growth_utility = "RIGHT",
    bg_color_utility = default_bg_color(),
    sort_utility = "timeleft",
    test_aura_utility = false,
    timer_number_font_utility = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size_utility = 10,
    timer_number_font_bold_utility = false,
    timer_color_utility = { r = 1, g = 1, b = 1 },
    bar_text_color_utility = { r = 1, g = 1, b = 1 },

    -- TRACKED BUFFS
    hide_blizz_cdm_tracked_buffs = false,
    show_tracked_buffs      = false,
    move_tracked_buffs      = false,
    timer_tracked_buffs     = true,
    timer_swipe_tracked_buffs = true,
    tooltip_tracked_buffs   = true,
    bg_tracked_buffs        = false,
    scale_tracked_buffs     = 1.0,
    spacing_tracked_buffs   = 1.5,
    width_tracked_buffs     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_tracked_buffs  = false,
    color_tracked_buffs     = { r = 0.2, g = 0.85, b = 0.55 },
    bar_bg_color_tracked_buffs = default_bg_color(),
    fade_ooc_tracked_buffs = true,
    ooc_alpha_tracked_buffs = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_tracked_buffs = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_tracked_buffs = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_tracked_buffs = M.DEFAULT_MAX_ICONS,
    growth_tracked_buffs = "RIGHT",
    bg_color_tracked_buffs = default_bg_color(),
    sort_tracked_buffs = "timeleft",
    test_aura_tracked_buffs = false,
    timer_number_font_tracked_buffs = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size_tracked_buffs = 10,
    timer_number_font_bold_tracked_buffs = false,
    timer_color_tracked_buffs = { r = 1, g = 1, b = 1 },
    bar_text_color_tracked_buffs = { r = 1, g = 1, b = 1 },

    -- TRACKED BARS
    hide_blizz_cdm_tracked_bars = false,
    show_tracked_bars      = false,
    move_tracked_bars      = false,
    timer_tracked_bars     = true,
    timer_swipe_tracked_bars = true,
    tooltip_tracked_bars   = true,
    bg_tracked_bars        = false,
    scale_tracked_bars     = 1.0,
    spacing_tracked_bars   = 1.5,
    width_tracked_bars     = M.DEFAULT_FRAME_WIDTH,
    bar_mode_tracked_bars  = true,
    color_tracked_bars     = { r = 0.2, g = 0.65, b = 1 },
    bar_bg_color_tracked_bars = default_bg_color(),
    fade_ooc_tracked_bars = true,
    ooc_alpha_tracked_bars = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_tracked_bars = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_tracked_bars = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_tracked_bars = M.DEFAULT_MAX_ICONS,
    growth_tracked_bars = "DOWN",
    bg_color_tracked_bars = default_bg_color(),
    sort_tracked_bars = "timeleft",
    test_aura_tracked_bars = false,
    timer_number_font_tracked_bars = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size_tracked_bars = 10,
    timer_number_font_bold_tracked_bars = false,
    timer_color_tracked_bars = { r = 1, g = 1, b = 1 },
    bar_text_color_tracked_bars = { r = 1, g = 1, b = 1 },

    -- DEBUFFS
    show_debuff     = true,
    move_debuff     = true,
    timer_debuff    = true,
    timer_swipe_debuff = true,
    tooltip_debuff  = true,
    bg_debuff       = false,
    scale_debuff    = 1.0,
    spacing_debuff  = 1.0,
    width_debuff    = M.DEFAULT_FRAME_WIDTH,
    bar_mode_debuff = true,
    color_debuff    = { r = 1, g = 0.2, b = 0.2 },
    bar_bg_color_debuff = default_bg_color(),
    fade_ooc_debuff = false,
    ooc_alpha_debuff = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay_debuff = M.DEFAULT_OOC_FADE_DELAY,
    fade_length_debuff = M.DEFAULT_OOC_FADE_LENGTH,
    max_icons_debuff = M.DEFAULT_MAX_ICONS,
    growth_debuff = "UP",
    bg_color_debuff = default_bg_color(),
    sort_debuff  = "timeleft",
    test_aura_debuff = true,
    timer_number_font_debuff = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size_debuff = 10,
    timer_number_font_bold_debuff = false,
    timer_color_debuff = { r = 1, g = 1, b = 1 },
    bar_text_color_debuff = { r = 1, g = 1, b = 1 },

    -- Custom filtered frames (array of entry tables, see M.CUSTOM_FRAME_TEMPLATE)
    custom_frames = {},

    -- POSITIONS
    -- pos.x = left edge offset from screen center; pos.y = top edge offset from screen center
    positions = {
        static = { point = "TOPLEFT", x = 485, y = 373.5 },
        debuff = { point = "TOPLEFT", x = 485, y = 246.5 },
        short  = { point = "TOPLEFT", x = 485, y = 128.5 },
        long   = { point = "TOPLEFT", x = 485, y =  29 },
        essential = { point = "TOPLEFT", x = -100, y = 25 },
        utility = { point = "TOPLEFT", x = -100, y = -25 },
        tracked_buffs = { point = "TOPLEFT", x = -100, y = -75 },
        tracked_bars = { point = "TOPLEFT", x = -100, y = -125 },
    }
}

--#region CUSTOM FRAME TEMPLATE ================================================
-- Default values for a newly created custom filtered frame.
-- Each entry in M.db.custom_frames is a copy of this template with a unique id/name.
M.CUSTOM_FRAME_TEMPLATE = {
    -- Identity (always overwritten on create, never defaulted)
    -- id   = "custom_N"   set by spawn logic
    -- name = "Custom N"   set by spawn logic

    aura_base_filter = "HELPFUL",
    aura_modifier    = "IMPORTANT",

    -- Display
    show     = true,
    move     = true,
    timer    = true,
    timer_swipe = true,
    tooltip  = true,
    bg       = false,
    scale    = 1.0,
    spacing  = 1.5,
    width    = M.DEFAULT_FRAME_WIDTH,
    bar_mode = true,
    color    = { r = 0.8, g = 0.6, b = 1.0 },
    bar_bg_color = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 },
    fade_ooc = false,
    ooc_alpha = M.DEFAULT_WOW_COOLDOWN_OOC_ALPHA,
    fade_delay = M.DEFAULT_OOC_FADE_DELAY,
    fade_length = M.DEFAULT_OOC_FADE_LENGTH,
    bg_color     = default_bg_color(),
    max_icons    = M.DEFAULT_MAX_ICONS,
    growth       = "DOWN",
    test_aura    = true,

    -- Timer font (matches TIMER_CATEGORIES convention)
    timer_number_font      = M.DEFAULT_TIMER_NUMBER_FONT_KEY,
    timer_number_font_size = 10,
    timer_number_font_bold = false,
    timer_color     = { r = 1, g = 1, b = 1 },
    bar_text_color  = { r = 1, g = 1, b = 1 },

    -- Position
    position = { point = "TOPLEFT", x = 0, y = 50 },
}

-- Max number of custom frames the user can create.
M.MAX_CUSTOM_FRAMES = 4

--#endregion CUSTOM FRAME TEMPLATE =============================================
