-- Visual bar implementation for the Skyriding Vigor module.
-- Style presentation, atlas layout, positioning, and bar construction live here.
local addon_name, addon = ...

addon.skyriding_vigor = addon.skyriding_vigor or {
    controls = {},
    slots = {},
}

local M = addon.skyriding_vigor

local C_Texture_GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local error = error
local tostring = tostring
local tonumber = tonumber

-- ============================================================================
-- STYLE DEFINITIONS
-- ============================================================================

local MAX_SLOTS = 6
local DEFAULT_STYLE_KEY = "default"
local DEFAULT_NODE_COLOR_KEY = "default"
local NODE_COLORS = {
    default = {
        label = "Default",
    },
    bronze = {
        label = "Bronze (Default)",
    },
    dark = {
        label = "Dark",
    },
    gold = {
        label = "Gold",
    },
    silver = {
        label = "Silver",
    },
}
local NODE_COLOR_ORDER = { "bronze", "dark", "gold", "silver" }
local DEFAULT_DECOR_COLOR_KEY = "default"
local DECOR_COLORS = NODE_COLORS
local DECOR_COLOR_ORDER = NODE_COLOR_ORDER
local BAR_STYLES = {
    default = {
        label = "Default",
        frame = "dragonriding_vigor_frame",
        frame_colors = {
            default = "dragonriding_vigor_frame",
        },
        background = "dragonriding_vigor_background",
        fill = "dragonriding_vigor_fill",
        fill_full = "dragonriding_vigor_fillfull",
        visible_edge_inset_x = 11.00,
        spacing_offset = 0.00,
        background_scale_x = 0.50,
        background_scale_y = 0.50,
        background_offset_x = 0.00,
        background_offset_y = 0.00,
        background_above_frame = false,
        fill_color = { r = 1, g = 1, b = 1, a = 1 },
        fill_add_alpha = 0.18,
    },
    storm_race = {
        label = "Storm Race",
        frame = "dragonriding_sgvigor_frame_bronze",
        default_node_color = "bronze",
        frame_colors = {
            bronze = "dragonriding_sgvigor_frame_bronze",
            dark = "dragonriding_sgvigor_frame_dark",
            gold = "dragonriding_sgvigor_frame_gold",
            silver = "dragonriding_sgvigor_frame_silver",
        },
        background = "dragonriding_sgvigor_background",
        fill = "dragonriding_sgvigor_fillfull",
        fill_full = "dragonriding_sgvigor_fillfull",
        visible_edge_inset_x = 0.00,
        spacing_offset = 0.00,
        background_scale_x = 0.75,
        background_scale_y = 0.75,
        background_offset_x = 0.00,
        background_offset_y = 0.00,
        background_above_frame = false,
        fill_color = { r = 1, g = 1, b = 1, a = 1 },
        fill_add_alpha = 0.18,
    },
}
local BAR_STYLE_ORDER = { "default", "storm_race" }
local DEFAULT_DECOR_STYLE_KEY = "default"
local DECOR_STYLES = {
    default = {
        label = "Default",
        atlas = "dragonriding_vigor_decor",
        atlas_colors = {
            default = "dragonriding_vigor_decor",
        },
        scale = 1,
        scale_x = 1,
        scale_y = 1,
        decor_node_gap_x = -18.0,
        offset_y = -15.0,
    },
    storm_race = {
        label = "Storm Race",
        atlas = "dragonriding_sgvigor_decor_bronze",
        default_decor_color = "bronze",
        atlas_colors = {
            bronze = "dragonriding_sgvigor_decor_bronze",
            dark = "dragonriding_sgvigor_decor_dark",
            gold = "dragonriding_sgvigor_decor_gold",
            silver = "dragonriding_sgvigor_decor_silver",
        },
        scale = 1,
        scale_x = 1,
        scale_y = 1,
        decor_node_gap_x = -20.0,
        offset_y = 5.0,
    },
}
local DECOR_STYLE_ORDER = { "default", "storm_race" }
local GRID_SIZE = 20

local SCALE_RANGE = { min = 0.40, max = 2, step = 0.05 }
local FILL_ADD_ALPHA_RANGE = { min = 0, max = 1, step = 0.01 }
local SPACING_RANGE = { min = 0, max = 25, step = 0.5 }
local FADE_ALPHA_RANGE = { min = 0.05, max = 1, step = 0.05 }
local FADE_LENGTH_RANGE = { min = 0, max = 10, step = 0.5 }
local POSITION_RANGE = { min = -1000, max = 1000, step = 1 }

local BACKGROUND_LAYOUT = {
    scale_x = 0.50,
    scale_y = 0.50,
    offset_x = 0.00,
    offset_y = 0.00,
}
local SHOW_BACKGROUND_LAYER = true

local FILL_LAYOUT = {
    scale_x = 0.50,
    scale_y = 0.50,
    offset_x = 0.00,
    offset_y = 0.00,
}
local SHOW_FILL_LAYER = true
local FILL_ADD_ALPHA = 0.18

local FRAME_LAYOUT = {
    scale_x = 1.00,
    scale_y = 1.00,
    offset_x = 0.00,
    offset_y = 0.00,
    visible_edge_inset_x = 11.00,
}
local SHOW_FRAME_LAYER = true

local WING_LAYOUT = {
    scale_x = 1,
    scale_y = 1,
}

M.MAX_SLOTS = MAX_SLOTS
M.BAR_STYLE_DEFAULT = DEFAULT_STYLE_KEY
M.BAR_STYLE_OPTIONS = {}
for _, key in ipairs(BAR_STYLE_ORDER) do
    M.BAR_STYLE_OPTIONS[#M.BAR_STYLE_OPTIONS + 1] = {
        value = key,
        text = BAR_STYLES[key].label,
    }
end
M.NODE_COLOR_DEFAULT = DEFAULT_NODE_COLOR_KEY
M.NODE_COLOR_OPTIONS = {}
for _, key in ipairs(NODE_COLOR_ORDER) do
    M.NODE_COLOR_OPTIONS[#M.NODE_COLOR_OPTIONS + 1] = {
        value = key,
        text = NODE_COLORS[key].label,
    }
end
M.DECOR_COLOR_DEFAULT = DEFAULT_DECOR_COLOR_KEY
M.DECOR_COLOR_OPTIONS = {}
for _, key in ipairs(DECOR_COLOR_ORDER) do
    M.DECOR_COLOR_OPTIONS[#M.DECOR_COLOR_OPTIONS + 1] = {
        value = key,
        text = DECOR_COLORS[key].label,
    }
end
M.DECOR_STYLE_DEFAULT = DEFAULT_DECOR_STYLE_KEY
M.DECOR_STYLE_OPTIONS = {}
for _, key in ipairs(DECOR_STYLE_ORDER) do
    M.DECOR_STYLE_OPTIONS[#M.DECOR_STYLE_OPTIONS + 1] = {
        value = key,
        text = DECOR_STYLES[key].label,
    }
end
M.SETTING_SPECS = {
    fade_alpha = FADE_ALPHA_RANGE,
    fade_length = FADE_LENGTH_RANGE,
    fill_add_alpha = FILL_ADD_ALPHA_RANGE,
    scale = SCALE_RANGE,
    spacing = SPACING_RANGE,
    decor_scale = SCALE_RANGE,
    decor_x_position = { min = -30, max = 10, step = 0.5 },
    decor_y_position = { min = -30, max = 10, step = 0.5 },
    x_position = POSITION_RANGE,
    y_position = POSITION_RANGE,
}
M.SLIDER_KEYS = { "fade_alpha", "fade_length", "spacing", "scale", "fill_add_alpha" }
M.LAYOUT_SETTING_KEYS = {
    scale = true,
    spacing = true,
    style = true,
    node_color = true,
    decor_style = true,
}

-- ============================================================================
-- SHARED ACCESSORS
-- ============================================================================

local function get_db()
    return M.get_db and M.get_db()
end

local function get_defaults()
    return M.DEFAULTS or {}
end

local function clamp_number(value, fallback, spec)
    value = tonumber(value)
    if not value then value = fallback end
    if spec and value < spec.min then return spec.min end
    if spec and value > spec.max then return spec.max end
    return value
end

local function atlas_exists(atlas)
    if not atlas then return true end
    if not C_Texture_GetAtlasInfo then return false end
    local info = C_Texture_GetAtlasInfo(atlas)
    return info and info.width and info.height and info.width > 0 and info.height > 0
end

-- ============================================================================
-- STYLE DB HELPERS
-- ============================================================================

local function is_valid_style(style)
    return style and atlas_exists(style.frame) and atlas_exists(style.background)
        and atlas_exists(style.fill) and atlas_exists(style.fill_full)
end

local function get_valid_node_color_key(style, key)
    local atlas = style and style.frame_colors and style.frame_colors[key]
    if key and atlas and atlas_exists(atlas) then
        return key
    end
    atlas = style and style.default_node_color and style.frame_colors and style.frame_colors[style.default_node_color]
    if atlas and atlas_exists(atlas) then
        return style.default_node_color
    end
    atlas = style and style.frame_colors and style.frame_colors[DEFAULT_NODE_COLOR_KEY]
    if atlas and atlas_exists(atlas) then
        return DEFAULT_NODE_COLOR_KEY
    end
    return DEFAULT_NODE_COLOR_KEY
end

local function get_valid_decor_color_key(style, key)
    local atlas = style and style.atlas_colors and style.atlas_colors[key]
    if key and atlas and atlas_exists(atlas) then
        return key
    end
    atlas = style and style.default_decor_color and style.atlas_colors and style.atlas_colors[style.default_decor_color]
    if atlas and atlas_exists(atlas) then
        return style.default_decor_color
    end
    atlas = style and style.atlas_colors and style.atlas_colors[DEFAULT_DECOR_COLOR_KEY]
    if atlas and atlas_exists(atlas) then
        return DEFAULT_DECOR_COLOR_KEY
    end
    return DEFAULT_DECOR_COLOR_KEY
end

local function is_valid_decor_style(style)
    return style and atlas_exists(style.atlas)
end

local function get_bar_style(db)
    local defaults = get_defaults()
    local key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    local style = BAR_STYLES[key]
    if is_valid_style(style) then
        return key, style
    end
    return DEFAULT_STYLE_KEY, BAR_STYLES[DEFAULT_STYLE_KEY]
end

function M.get_valid_bar_style_key(key)
    if is_valid_style(BAR_STYLES[key]) then
        return key
    end
    return DEFAULT_STYLE_KEY
end

function M.bar_style_supports_node_color(style_key)
    local db = get_db()
    local defaults = get_defaults()
    style_key = M.get_valid_bar_style_key(style_key or (db and db.style) or defaults.style or DEFAULT_STYLE_KEY)
    local style = BAR_STYLES[style_key]
    if not style or not style.frame_colors then return false end

    for key, atlas in pairs(style.frame_colors) do
        if key ~= DEFAULT_NODE_COLOR_KEY and atlas_exists(atlas) then
            return true
        end
    end
    return false
end

function M.get_style_layout_default(style_key, field)
    local style = BAR_STYLES[style_key] or BAR_STYLES[DEFAULT_STYLE_KEY]
    if field == "scale" then
        return (get_defaults().scale or 1)
    elseif field == "node_color" then
        return get_valid_node_color_key(style, style and style.default_node_color or DEFAULT_NODE_COLOR_KEY)
    elseif field == "fill_color" then
        local color = style and style.fill_color or { r = 1, g = 1, b = 1, a = 1 }
        return { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = color.a or 1 }
    elseif field == "fill_add_alpha" then
        return style and style.fill_add_alpha or FILL_ADD_ALPHA
    end
    return nil
end

function M.get_style_layout_table(db, style_key, create, initial_scale)
    if not db then return nil end
    style_key = M.get_valid_bar_style_key(style_key or db.style or DEFAULT_STYLE_KEY)
    if create then
        db.style_layouts = db.style_layouts or {}
        db.style_layouts[style_key] = db.style_layouts[style_key] or {}
        local layout = db.style_layouts[style_key]
        if layout.scale == nil then
            layout.scale = initial_scale or M.get_style_layout_default(style_key, "scale")
        end
        if layout.fill_color == nil then
            layout.fill_color = M.get_style_layout_default(style_key, "fill_color")
        end
        if layout.fill_add_alpha == nil then
            layout.fill_add_alpha = M.get_style_layout_default(style_key, "fill_add_alpha")
        end
        layout.node_color = get_valid_node_color_key(BAR_STYLES[style_key], layout.node_color or M.get_style_layout_default(style_key, "node_color"))
        return layout
    end
    return db.style_layouts and db.style_layouts[style_key] or nil
end

local function get_style_layout_number(db, style_key, field)
    local layout = M.get_style_layout_table(db, style_key, false)
    local value = layout and tonumber(layout[field])
    if value == nil then
        value = M.get_style_layout_default(style_key, field)
    end
    return value
end

function M.get_style_fill_color_value(db, style_key)
    db = db or get_db()
    style_key = M.get_valid_bar_style_key(style_key or (db and db.style) or DEFAULT_STYLE_KEY)
    local layout = M.get_style_layout_table(db, style_key, true)
    local color = layout and layout.fill_color
    if not color then
        color = M.get_style_layout_default(style_key, "fill_color")
    end
    return color
end

local function fill_color_is_custom(color)
    if not color then return false end
    return abs((color.r or 1) - 1) > 0.001
        or abs((color.g or 1) - 1) > 0.001
        or abs((color.b or 1) - 1) > 0.001
end

local function apply_fill_texture_color(texture, color)
    if not texture then return end
    color = color or { r = 1, g = 1, b = 1, a = 1 }
    texture:SetDesaturated(fill_color_is_custom(color))
    texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function apply_fill_boost_texture_color(texture, color)
    if not texture then return end
    color = color or { r = 1, g = 1, b = 1, a = 1 }
    local add_alpha = M.get_style_fill_add_alpha and M.get_style_fill_add_alpha() or FILL_ADD_ALPHA
    texture:SetDesaturated(true)
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, (color.a or 1) * add_alpha)
end

function M.get_node_color()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    local style = BAR_STYLES[style_key] or BAR_STYLES[DEFAULT_STYLE_KEY]
    local layout = M.get_style_layout_table(db, style_key, true)
    return get_valid_node_color_key(style, layout and layout.node_color or M.get_style_layout_default(style_key, "node_color"))
end

function M.set_node_color(value)
    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local style = BAR_STYLES[style_key] or BAR_STYLES[DEFAULT_STYLE_KEY]
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.node_color = get_valid_node_color_key(style, value)
    if M.sync_node_color_controls then
        M.sync_node_color_controls()
    end
    M.refresh_layout()
end

local function get_frame_atlas(db, style_key, style)
    local layout = M.get_style_layout_table(db, style_key, true)
    local color_key = get_valid_node_color_key(style, layout and layout.node_color or nil)
    return style.frame_colors and style.frame_colors[color_key] or style.frame
end

function M.get_style_scale()
    local db = get_db()
    local defaults = get_defaults()
    if not db then return defaults.scale or 1 end
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    local value = layout and layout.scale
    if value == nil then
        value = M.get_style_layout_default(style_key, "scale")
    end
    return value or defaults.scale or 1
end

function M.set_style_scale(value)
    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local fallback = db.scale or defaults.scale or 1
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.scale = clamp_number(value, fallback, M.SETTING_SPECS and M.SETTING_SPECS.scale)
    db.scale = layout.scale
    M.refresh_layout()
end

function M.get_style_fill_color()
    local db = get_db()
    if not db then return { r = 1, g = 1, b = 1, a = 1 } end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    return M.get_style_fill_color_value(db, style_key) or { r = 1, g = 1, b = 1, a = 1 }
end

function M.get_style_fill_color_default()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    return M.get_style_layout_default(style_key, "fill_color") or { r = 1, g = 1, b = 1, a = 1 }
end

function M.set_style_fill_color(color)
    local db = get_db()
    if not db or type(color) ~= "table" then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.fill_color = {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        a = color.a or 1,
    }
    if M.apply_fill_color then
        M.apply_fill_color()
    elseif M.refresh then
        M.refresh()
    end
end

function M.get_style_fill_add_alpha()
    local db = get_db()
    if not db then return FILL_ADD_ALPHA end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    local value = layout and layout.fill_add_alpha
    if value == nil then
        value = M.get_style_layout_default(style_key, "fill_add_alpha")
    end
    return clamp_number(value, FILL_ADD_ALPHA, M.SETTING_SPECS and M.SETTING_SPECS.fill_add_alpha)
end

function M.get_style_fill_add_alpha_default()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.style or defaults.style or DEFAULT_STYLE_KEY
    return M.get_style_layout_default(style_key, "fill_add_alpha") or FILL_ADD_ALPHA
end

function M.set_style_fill_add_alpha(value)
    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.style or defaults.style or DEFAULT_STYLE_KEY
    local layout = M.get_style_layout_table(db, style_key, true)
    if not layout then return end

    layout.fill_add_alpha = clamp_number(value, M.get_style_fill_add_alpha_default(), M.SETTING_SPECS and M.SETTING_SPECS.fill_add_alpha)
    if M.apply_fill_color then
        M.apply_fill_color()
    elseif M.refresh then
        M.refresh()
    end
end

local function get_decor_style(db)
    local defaults = get_defaults()
    local key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local style = DECOR_STYLES[key]
    if is_valid_decor_style(style) then
        return key, style
    end
    return DEFAULT_DECOR_STYLE_KEY, DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
end

function M.get_valid_decor_style_key(key)
    if is_valid_decor_style(DECOR_STYLES[key]) then
        return key
    end
    return DEFAULT_DECOR_STYLE_KEY
end

function M.decor_style_supports_color(style_key)
    local db = get_db()
    local defaults = get_defaults()
    style_key = M.get_valid_decor_style_key(style_key or (db and db.decor_style) or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY)
    local style = DECOR_STYLES[style_key]
    if not style or not style.atlas_colors then return false end

    for key, atlas in pairs(style.atlas_colors) do
        if key ~= DEFAULT_DECOR_COLOR_KEY and atlas_exists(atlas) then
            return true
        end
    end
    return false
end

function M.get_decor_layout_default(style_key, field)
    local style = DECOR_STYLES[style_key] or DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
    if field == "decor_node_gap_x" then
        return style and style.decor_node_gap_x or 0
    elseif field == "offset_y" then
        return style and style.offset_y or 0
    elseif field == "scale" then
        return style and (style.scale or style.scale_x or WING_LAYOUT.scale_x) or 1
    elseif field == "decor_color" then
        return get_valid_decor_color_key(style, style and style.default_decor_color or DEFAULT_DECOR_COLOR_KEY)
    end
    return nil
end

function M.get_decor_layout_table(db, style_key, create)
    if not db then return nil end
    style_key = M.get_valid_decor_style_key(style_key or db.decor_style or DEFAULT_DECOR_STYLE_KEY)
    if create then
        db.decor_layouts = db.decor_layouts or {}
        db.decor_layouts[style_key] = db.decor_layouts[style_key] or {}
        local layout = db.decor_layouts[style_key]
        if layout.decor_node_gap_x == nil then
            layout.decor_node_gap_x = M.get_decor_layout_default(style_key, "decor_node_gap_x")
        end
        if layout.offset_y == nil then
            layout.offset_y = M.get_decor_layout_default(style_key, "offset_y")
        end
        if layout.scale == nil then
            layout.scale = M.get_decor_layout_default(style_key, "scale")
        end
        layout.decor_color = get_valid_decor_color_key(DECOR_STYLES[style_key], layout.decor_color or M.get_decor_layout_default(style_key, "decor_color"))
        return layout
    end
    return db.decor_layouts and db.decor_layouts[style_key] or nil
end

local function get_decor_layout_number(db, style_key, field)
    local layout = M.get_decor_layout_table(db, style_key, false)
    local value = layout and tonumber(layout[field])
    if value == nil then
        value = M.get_decor_layout_default(style_key, field)
    end
    return value
end

local function get_decor_position_field(axis)
    if axis == "x" then
        return "decor_node_gap_x", "decor_x_position"
    elseif axis == "y" then
        return "offset_y", "decor_y_position"
    end
    return nil
end

function M.get_decor_position_axis(axis)
    local field = get_decor_position_field(axis)
    if not field then return 0 end
    local db = get_db()
    if not db then return 0 end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local layout = M.get_decor_layout_table(db, style_key, true)
    local value = layout and layout[field]
    if value == nil then
        value = M.get_decor_layout_default(style_key, field)
    end
    return value or 0
end

function M.get_decor_position_default(axis)
    local field = get_decor_position_field(axis)
    if not field then return 0 end
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    return M.get_decor_layout_default(style_key, field) or 0
end

function M.set_decor_position_axis(axis, value)
    local field, spec_key = get_decor_position_field(axis)
    if not field then return end
    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local fallback = M.get_decor_layout_default(style_key, field) or 0
    local layout = M.get_decor_layout_table(db, style_key, true)
    if not layout then return end

    layout[field] = clamp_number(value, fallback, M.SETTING_SPECS and M.SETTING_SPECS[spec_key])
    M.refresh_layout()
end

function M.get_decor_scale()
    local db = get_db()
    if not db then return 1 end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local layout = M.get_decor_layout_table(db, style_key, true)
    local value = layout and layout.scale
    if value == nil then
        value = M.get_decor_layout_default(style_key, "scale")
    end
    return value or 1
end

function M.get_decor_scale_default()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    return M.get_decor_layout_default(style_key, "scale") or 1
end

function M.set_decor_scale(value)
    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local fallback = M.get_decor_layout_default(style_key, "scale") or 1
    local layout = M.get_decor_layout_table(db, style_key, true)
    if not layout then return end

    layout.scale = clamp_number(value, fallback, M.SETTING_SPECS and M.SETTING_SPECS.decor_scale)
    M.refresh_layout()
end

function M.get_decor_color()
    local db = get_db()
    local defaults = get_defaults()
    local style_key = db and db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local style = DECOR_STYLES[style_key] or DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
    local layout = M.get_decor_layout_table(db, style_key, true)
    return get_valid_decor_color_key(style, layout and layout.decor_color or M.get_decor_layout_default(style_key, "decor_color"))
end

function M.set_decor_color(value)
    local db = get_db()
    if not db then return end
    local defaults = get_defaults()
    local style_key = db.decor_style or defaults.decor_style or DEFAULT_DECOR_STYLE_KEY
    local style = DECOR_STYLES[style_key] or DECOR_STYLES[DEFAULT_DECOR_STYLE_KEY]
    local layout = M.get_decor_layout_table(db, style_key, true)
    if not layout then return end

    layout.decor_color = get_valid_decor_color_key(style, value)
    if M.sync_decor_color_controls then
        M.sync_decor_color_controls()
    end
    M.refresh_layout()
end

local function get_decor_atlas(db, style_key, style)
    local layout = M.get_decor_layout_table(db, style_key, true)
    local color_key = get_valid_decor_color_key(style, layout and layout.decor_color or nil)
    return style.atlas_colors and style.atlas_colors[color_key] or style.atlas
end

-- ============================================================================
-- POSITION HELPERS
-- ============================================================================

local function snap_value(value)
    return floor(((value or 0) / GRID_SIZE) + 0.5) * GRID_SIZE
end

local function set_center_position(frame, x, y)
    if not frame then return end
    x = x or 0
    y = y or 0
    if frame._center_x == x and frame._center_y == y then
        return
    end
    frame._center_x = x
    frame._center_y = y
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", frame._center_x, frame._center_y)
end

local function get_saved_center(db)
    local defaults = get_defaults()
    local pos = db and db.position or defaults.position or {}
    return pos.x or 0, pos.y or 0
end

-- ============================================================================
-- ATLAS SIZE HELPERS
-- ============================================================================

local function get_atlas_size(atlas)
    if C_Texture_GetAtlasInfo then
        local info = C_Texture_GetAtlasInfo(atlas)
        if info and info.width and info.height and info.width > 0 and info.height > 0 then
            return info.width, info.height
        end
    end
    error(addon_name .. ": missing atlas metadata for " .. tostring(atlas), 2)
end

local function get_node_size()
    local _, style = get_bar_style(get_db())
    local atlas = style.frame
    if M._node_size_atlas ~= atlas or not M._node_width or not M._node_height then
        M._node_width, M._node_height = get_atlas_size(atlas)
        M._node_size_atlas = atlas
    end
    return M._node_width, M._node_height
end

local function get_decor_size()
    local _, style = get_decor_style(get_db())
    local atlas = style.atlas
    if M._decor_size_atlas ~= atlas or not M._decor_width or not M._decor_height then
        M._decor_width, M._decor_height = get_atlas_size(atlas)
        M._decor_size_atlas = atlas
    end
    return M._decor_width, M._decor_height
end

local function get_fill_size()
    local width, height = get_node_size()
    return max(1, width * FILL_LAYOUT.scale_x), max(1, height * FILL_LAYOUT.scale_y)
end

local function get_background_size()
    local width, height = get_node_size()
    local _, style = get_bar_style(get_db())
    return max(1, width * (style.background_scale_x or BACKGROUND_LAYOUT.scale_x)),
        max(1, height * (style.background_scale_y or BACKGROUND_LAYOUT.scale_y))
end

local function get_frame_size()
    local width, height = get_node_size()
    return max(1, width * FRAME_LAYOUT.scale_x), max(1, height * FRAME_LAYOUT.scale_y)
end

local function get_frame_left_in_slot(node_width, frame_width)
    return ((node_width - frame_width) / 2) + FRAME_LAYOUT.offset_x
end

local function get_frame_edge_inset_x(frame_width)
    local _, style = get_bar_style(get_db())
    local inset = style.visible_edge_inset_x
    if inset == nil then
        inset = FRAME_LAYOUT.visible_edge_inset_x or 0
    end
    return min(max(0, inset), max(0, (frame_width - 1) / 2))
end

local function get_frame_edge_width(frame_width)
    local edge_inset_x = get_frame_edge_inset_x(frame_width)
    return max(1, frame_width - (edge_inset_x * 2))
end

local function get_spacing_pixels(db)
    local defaults = get_defaults()
    local default_spacing = defaults.spacing or 5
    local spacing_setting = db and db.spacing
    if spacing_setting == nil then
        spacing_setting = default_spacing
    end
    local _, style = get_bar_style(db)
    return spacing_setting + (style.spacing_offset or 0)
end

-- ============================================================================
-- DRAG HELPERS
-- ============================================================================

local function get_cursor_position()
    local scale = UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()
    return (x or 0) / scale, (y or 0) / scale
end

function M.snap_position()
    local db = get_db()
    local frame = M.frame
    if not db or not frame then return end

    local xOfs = frame._center_x
    local yOfs = frame._center_y
    if xOfs == nil or yOfs == nil then
        xOfs, yOfs = get_saved_center(db)
    end
    set_center_position(frame, snap_value(xOfs), snap_value(yOfs))
end

function M.save_position()
    local db = get_db()
    local frame = M.frame
    if not db or not frame then return end

    if db.snap_to_grid then
        M.snap_position()
    end

    local xOfs = frame._center_x
    local yOfs = frame._center_y
    if xOfs == nil or yOfs == nil then
        xOfs, yOfs = get_saved_center(db)
    end
    db.position = db.position or {}
    db.position.point = "CENTER"
    db.position.relativePoint = "CENTER"
    db.position.x = xOfs or 0
    db.position.y = yOfs or 0
    if M.sync_position_controls then
        M.sync_position_controls(db)
    end
end

function M.apply_position()
    local db = get_db()
    local frame = M.frame
    if not db or not frame then return end

    local xOfs, yOfs = get_saved_center(db)
    set_center_position(frame, xOfs, yOfs)
end

-- ============================================================================
-- SLOT RENDERING
-- ============================================================================

local function set_atlas_sized(texture, atlas, width, height)
    if not texture then return end
    texture:SetAtlas(atlas, false)
    texture:SetSize(width, height)
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1, 1)
end

local function apply_slot_static_atlases(slot)
    local db = get_db()
    local style_key, style = get_bar_style(db)
    local bg_width, bg_height = get_background_size()
    local frame_width, frame_height = get_frame_size()
    local frame_atlas = get_frame_atlas(db, style_key, style)

    if slot.background_frame and slot.cover_frame then
        if style.background_above_frame then
            slot.background_frame:SetFrameLevel(slot.cover_frame:GetFrameLevel() + 1)
        else
            slot.background_frame:SetFrameLevel(slot.cover_frame:GetFrameLevel() - 2)
        end
    end

    slot.background:ClearAllPoints()
    slot.background:SetPoint(
        "CENTER",
        slot,
        "CENTER",
        style.background_offset_x or BACKGROUND_LAYOUT.offset_x,
        style.background_offset_y or BACKGROUND_LAYOUT.offset_y
    )
    set_atlas_sized(slot.background, style.background, bg_width, bg_height)
    set_atlas_sized(slot.cover, frame_atlas, frame_width, frame_height)
    slot._static_style = style
    slot._frame_atlas = frame_atlas
end

local function set_bar_atlas(slot, atlas)
    local fill_width, fill_height = get_fill_size()
    slot.bar:SetStatusBarTexture(atlas)
    local texture = slot.bar:GetStatusBarTexture()
    local boost_texture
    if slot.fill_boost then
        slot.fill_boost:SetStatusBarTexture(atlas)
        boost_texture = slot.fill_boost:GetStatusBarTexture()
    end
    if texture then
        set_atlas_sized(texture, atlas, fill_width, fill_height)
        local color = M.get_style_fill_color_value(get_db())
        apply_fill_texture_color(texture, color)
        if boost_texture then
            set_atlas_sized(boost_texture, atlas, fill_width, fill_height)
            apply_fill_boost_texture_color(boost_texture, color)
            slot.fill_boost:SetShown(SHOW_FILL_LAYER and fill_color_is_custom(color) and M.get_style_fill_add_alpha() > 0)
        end
    end
end

function M.apply_fill_color()
    local color = M.get_style_fill_color_value(get_db())
    for i = 1, MAX_SLOTS do
        local slot = M.slots[i]
        local texture = slot and slot.bar and slot.bar:GetStatusBarTexture()
        if texture then
            apply_fill_texture_color(texture, color)
        end
        local boost_texture = slot and slot.fill_boost and slot.fill_boost:GetStatusBarTexture()
        if boost_texture then
            apply_fill_boost_texture_color(boost_texture, color)
            slot.fill_boost:SetShown(SHOW_FILL_LAYER and fill_color_is_custom(color) and M.get_style_fill_add_alpha() > 0)
        end
    end
end

local function set_slot_progress(slot, progress)
    progress = max(0, min(progress or 0, 1))

    local _, style = get_bar_style(get_db())
    if slot._bar_texture ~= style.fill then
        set_bar_atlas(slot, style.fill)
        slot._bar_texture = style.fill
    end
    slot.bar:SetValue(progress)
    if slot.fill_boost then
        slot.fill_boost:SetValue(progress)
    end
end

local function set_slot_fill_bounds(slot)
    if slot._fill_bounds_set then return end
    local fill_width, fill_height = get_fill_size()

    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.bar:SetSize(fill_width, fill_height)
    slot.bar:SetMinMaxValues(0, 1)
    if slot.fill_boost then
        slot.fill_boost:ClearAllPoints()
        slot.fill_boost:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
        slot.fill_boost:SetSize(fill_width, fill_height)
        slot.fill_boost:SetMinMaxValues(0, 1)
    end
    slot._fill_bounds_set = true
end

local function create_slot(parent, index)
    local width, height = get_node_size()
    local fill_width, fill_height = get_fill_size()
    local slot = CreateFrame("Frame", addon_name .. "SkyridingVigorSlot" .. index, parent)
    slot:SetSize(width, height)

    local base_level = slot:GetFrameLevel()
    local frame_level = base_level + 3
    local background_level = base_level + 1
    local fill_level = base_level + 2

    slot.background_frame = CreateFrame("Frame", nil, slot)
    slot.background_frame:ClearAllPoints()
    slot.background_frame:SetAllPoints(slot)
    slot.background_frame:SetFrameLevel(background_level)

    slot.background = slot.background_frame:CreateTexture(nil, "ARTWORK", nil, 0)
    slot.background:ClearAllPoints()
    slot.background:SetPoint("CENTER", slot, "CENTER", BACKGROUND_LAYOUT.offset_x, BACKGROUND_LAYOUT.offset_y)
    slot.background:SetShown(SHOW_BACKGROUND_LAYER)

    slot.bar = CreateFrame("StatusBar", nil, slot)
    slot.bar:SetOrientation("VERTICAL")
    slot.bar:ClearAllPoints()
    slot.bar:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.bar:SetSize(fill_width, fill_height)
    slot.bar:SetFrameLevel(fill_level)
    slot.bar:SetMinMaxValues(0, 1)
    slot.bar:SetValue(0)
    slot.bar:SetShown(SHOW_FILL_LAYER)
    slot._fill_bounds_set = true

    slot.fill_boost = CreateFrame("StatusBar", nil, slot)
    slot.fill_boost:SetOrientation("VERTICAL")
    slot.fill_boost:ClearAllPoints()
    slot.fill_boost:SetPoint("CENTER", slot, "CENTER", FILL_LAYOUT.offset_x, FILL_LAYOUT.offset_y)
    slot.fill_boost:SetSize(fill_width, fill_height)
    slot.fill_boost:SetFrameLevel(fill_level)
    slot.fill_boost:SetMinMaxValues(0, 1)
    slot.fill_boost:SetValue(0)
    slot.fill_boost:Hide()

    slot.cover_frame = CreateFrame("Frame", nil, slot)
    slot.cover_frame:ClearAllPoints()
    slot.cover_frame:SetAllPoints(slot)
    slot.cover_frame:SetFrameLevel(frame_level)

    slot.cover = slot.cover_frame:CreateTexture(nil, "OVERLAY", nil, 3)
    slot.cover:ClearAllPoints()
    slot.cover:SetPoint("CENTER", slot, "CENTER", FRAME_LAYOUT.offset_x, FRAME_LAYOUT.offset_y)
    slot.cover:SetDrawLayer("OVERLAY", 7)
    slot.cover:SetShown(SHOW_FRAME_LAYER)
    apply_slot_static_atlases(slot)
    local _, style = get_bar_style(get_db())
    set_bar_atlas(slot, style.fill)
    slot._bar_texture = style.fill

    return slot
end

function M.set_slot_state(index, state, progress)
    local slot = M.slots[index]
    if not slot then return end

    local effective_progress
    if state == "full" then
        effective_progress = 1
    elseif state == "filling" then
        effective_progress = max(0, min(progress or 0, 1))
    else
        effective_progress = 0
    end

    local db = get_db()
    local style_key, style = get_bar_style(db)
    local frame_atlas = get_frame_atlas(db, style_key, style)
    if slot._state == state and slot._static_style == style and slot._frame_atlas == frame_atlas
        and abs((slot._progress or -1) - effective_progress) < 0.001
    then
        return
    end

    if slot._static_style ~= style or slot._frame_atlas ~= frame_atlas then
        apply_slot_static_atlases(slot)
        slot._bar_texture = nil
        slot._fill_bounds_set = false
    end

    set_slot_fill_bounds(slot)
    if state == "full" then
        if slot._bar_texture ~= style.fill_full then
            set_bar_atlas(slot, style.fill_full)
            slot._bar_texture = style.fill_full
        end
        slot.bar:SetValue(effective_progress)
        slot.fill_boost:SetValue(effective_progress)
    elseif state == "filling" then
        set_slot_progress(slot, effective_progress)
    else
        if slot._bar_texture ~= style.fill then
            set_bar_atlas(slot, style.fill)
            slot._bar_texture = style.fill
        end
        slot.bar:SetValue(effective_progress)
        slot.fill_boost:SetValue(effective_progress)
    end
    slot._state = state
    slot._progress = effective_progress
end

-- ============================================================================
-- FRAME AND SLOT API
-- ============================================================================

function M.set_slot_visible(index, visible)
    local slot = M.slots[index]
    if not slot then return end

    if visible then
        if not slot:IsShown() then
            slot:Show()
        end
    else
        if slot:IsShown() then
            slot:Hide()
        end
    end
end

local function ensure_decor(parent)
    if M.decor_left_frame and M.decor_right_frame and M.decor_left and M.decor_right then return end

    M.decor_left_frame = CreateFrame("Frame", nil, parent)
    M.decor_right_frame = CreateFrame("Frame", nil, parent)

    M.decor_left = M.decor_left_frame:CreateTexture(nil, "ARTWORK", nil, -1)
    M.decor_left:SetAllPoints(M.decor_left_frame)
    M.decor_left:SetTexCoord(1, 0, 0, 1)

    M.decor_right = M.decor_right_frame:CreateTexture(nil, "ARTWORK", nil, -1)
    M.decor_right:SetAllPoints(M.decor_right_frame)
end

function M.ensure_frame()
    if M.frame then return M.frame end

    local frame = CreateFrame("Frame", addon_name .. "SkyridingVigor", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    local visual_frame = CreateFrame("Frame", nil, frame)
    visual_frame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    M.visual_frame = visual_frame
    ensure_decor(visual_frame)

    frame:SetScript("OnDragStart", function(self)
        local db = get_db()
        if not db or not db.move_mode or InCombatLockdown() then return end
        if self._is_dragging then return end
        self._is_dragging = true
        local cursor_x, cursor_y = get_cursor_position()
        local center_x = self._center_x
        local center_y = self._center_y
        if center_x == nil or center_y == nil then
            center_x, center_y = get_saved_center(db)
        end
        self._drag_start_cursor_x = cursor_x
        self._drag_start_cursor_y = cursor_y
        self._drag_start_center_x = center_x
        self._drag_start_center_y = center_y
        self:SetScript("OnUpdate", function(drag_frame)
            local current_x, current_y = get_cursor_position()
            set_center_position(
                drag_frame,
                drag_frame._drag_start_center_x + current_x - drag_frame._drag_start_cursor_x,
                drag_frame._drag_start_center_y + current_y - drag_frame._drag_start_cursor_y
            )
        end)
    end)

    frame:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self._is_dragging = false
        self._drag_start_cursor_x = nil
        self._drag_start_cursor_y = nil
        self._drag_start_center_x = nil
        self._drag_start_center_y = nil
        M.save_position()
    end)

    M.frame = frame
    M.invalidate_layout()
    for i = 1, MAX_SLOTS do
        M.slots[i] = create_slot(visual_frame, i)
    end

    M.apply_position()
    return frame
end

-- ============================================================================
-- LAYOUT
-- ============================================================================

function M.set_wing_layout(values)
    if not values then return end

    if values.scale_x ~= nil then WING_LAYOUT.scale_x = values.scale_x end
    if values.scale_y ~= nil then WING_LAYOUT.scale_y = values.scale_y end

    M.invalidate_layout()
    if M.frame and M.refresh then
        M.refresh()
    end
end

function M.invalidate_layout()
    M._layout_signature = nil
    M._layout_dirty = true
end

function M.apply_layout()
    if not M._layout_dirty and M._layout_signature then
        return
    end

    local db = get_db()
    local frame = M.ensure_frame()
    if not db or not frame then return end

    local defaults = get_defaults()
    local spacing = get_spacing_pixels(db)
    local style_key = get_bar_style(db)
    local scale = get_style_layout_number(db, style_key, "scale") or defaults.scale or 1
    local width, height = get_node_size()
    local frame_width, frame_height = get_frame_size()
    local decor_width, decor_height = get_decor_size()
    local decor_style_key, decor_style = get_decor_style(db)
    local decor_color = M.get_decor_color()
    local decor_atlas = get_decor_atlas(db, decor_style_key, decor_style)
    local decor_scale = get_decor_layout_number(db, decor_style_key, "scale") or 1
    local wing_scale_x = decor_scale * (decor_style.scale_x or WING_LAYOUT.scale_x)
    local wing_scale_y = decor_scale * (decor_style.scale_y or WING_LAYOUT.scale_y)
    local wing_node_gap_x = get_decor_layout_number(db, decor_style_key, "decor_node_gap_x")
    if wing_node_gap_x == nil then wing_node_gap_x = 0 end
    local wing_offset_y = get_decor_layout_number(db, decor_style_key, "offset_y")
    if wing_offset_y == nil then wing_offset_y = 0 end
    local wing_width = decor_width * wing_scale_x
    local wing_height = decor_height * wing_scale_y
    local frame_edge_inset_x = get_frame_edge_inset_x(frame_width)
    local frame_edge_width = get_frame_edge_width(frame_width)
    local nodes_width = (frame_edge_width * MAX_SLOTS) + (spacing * (MAX_SLOTS - 1))
    local first_frame_edge_x = wing_width + wing_node_gap_x
    local frame_edge_left_in_slot = get_frame_left_in_slot(width, frame_width) + frame_edge_inset_x
    local first_slot_x = first_frame_edge_x - frame_edge_left_in_slot
    local node_step = frame_edge_width + spacing
    local right_decor_x = first_frame_edge_x + nodes_width + wing_node_gap_x
    local total_width = right_decor_x + wing_width
    local total_height = max(height, frame_height, wing_height)
    local visual_frame = M.visual_frame
    local center_x = frame._center_x
    local center_y = frame._center_y
    if center_x == nil or center_y == nil then
        center_x, center_y = get_saved_center(db)
    end
    if frame._center_x == nil or frame._center_y == nil then
        set_center_position(frame, center_x, center_y)
    end

    local node_color = M.get_node_color()
    local layout_signature = spacing .. ":" .. scale .. ":" .. total_width .. ":" .. total_height .. ":"
        .. first_slot_x .. ":" .. first_frame_edge_x .. ":" .. right_decor_x .. ":"
        .. node_step .. ":" .. frame_width .. ":" .. frame_height .. ":" .. frame_edge_width .. ":"
        .. frame_edge_inset_x .. ":" .. wing_node_gap_x .. ":"
        .. wing_scale_x .. ":" .. wing_scale_y .. ":"
        .. wing_offset_y .. ":" .. style_key .. ":" .. node_color .. ":" .. decor_style_key .. ":" .. decor_color
    if M._layout_signature == layout_signature then
        M._layout_dirty = false
        return
    end
    M._layout_signature = layout_signature
    M._layout_dirty = false

    frame:SetSize(total_width * scale, total_height * scale)
    frame:SetScale(1)
    if visual_frame then
        visual_frame:SetSize(total_width, total_height)
        visual_frame:SetScale(scale)
        visual_frame:ClearAllPoints()
        visual_frame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
    set_center_position(frame, center_x, center_y)

    for i = 1, MAX_SLOTS do
        local slot = M.slots[i]
        slot:ClearAllPoints()
        slot:SetSize(width, height)
        slot:SetPoint("LEFT", visual_frame or frame, "LEFT", first_slot_x + (node_step * (i - 1)), 0)
    end

    if M.decor_left_frame and M.decor_right_frame and M.slots[1] and M.slots[MAX_SLOTS] then
        if M.decor_left and M.decor_left._atlas ~= decor_atlas then
            M.decor_left:SetAtlas(decor_atlas, false)
            M.decor_left._atlas = decor_atlas
        end
        if M.decor_right and M.decor_right._atlas ~= decor_atlas then
            M.decor_right:SetAtlas(decor_atlas, false)
            M.decor_right._atlas = decor_atlas
        end
        M.decor_left_frame:ClearAllPoints()
        M.decor_right_frame:ClearAllPoints()
        M.decor_left_frame:SetSize(wing_width, wing_height)
        M.decor_right_frame:SetSize(wing_width, wing_height)
        M.decor_left_frame:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            wing_width / 2,
            wing_offset_y
        )
        M.decor_right_frame:SetPoint(
            "CENTER",
            visual_frame or frame,
            "LEFT",
            right_decor_x + (wing_width / 2),
            wing_offset_y
        )
    end
end

-- ============================================================================
-- INTERACTION STATE
-- ============================================================================

function M.set_move_mode(enabled)
    local frame = M.ensure_frame()
    local mouse_enabled = enabled and true or false
    if frame._mouse_enabled ~= mouse_enabled then
        frame:EnableMouse(mouse_enabled)
        frame._mouse_enabled = mouse_enabled
    end
    if enabled then
        if frame._sv_alpha ~= 1 then
            frame:SetAlpha(1)
            frame._sv_alpha = 1
        end
        if not frame:IsShown() then
            frame:Show()
        end
    end
end
