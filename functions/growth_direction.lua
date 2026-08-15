-- Shared four-way growth-direction metadata and dropdown factory.
-- Consumers translate the canonical axis/anchor/direction values into their
-- own layout APIs instead of maintaining module-local direction tables.

local addon_name, addon = ...

--#region DIRECTION DEFINITIONS ===============================================

local DEFINITIONS = {
    RIGHT = {
        value = "RIGHT",
        text = "RIGHT",
        vertical = false,
        anchor = "TOPLEFT",
        horizontal = "RIGHT",
        vertical_direction = "DOWN",
        x_sign = 1,
        y_sign = -1,
    },
    LEFT = {
        value = "LEFT",
        text = "LEFT",
        vertical = false,
        anchor = "TOPRIGHT",
        horizontal = "LEFT",
        vertical_direction = "DOWN",
        x_sign = -1,
        y_sign = -1,
    },
    DOWN = {
        value = "DOWN",
        text = "DOWN",
        vertical = true,
        anchor = "TOPLEFT",
        horizontal = "RIGHT",
        vertical_direction = "DOWN",
        x_sign = 1,
        y_sign = -1,
    },
    UP = {
        value = "UP",
        text = "UP",
        vertical = true,
        grows_up = true,
        anchor = "BOTTOMLEFT",
        horizontal = "RIGHT",
        vertical_direction = "UP",
        x_sign = 1,
        y_sign = 1,
    },
}

local OPTIONS = {
    DEFINITIONS.RIGHT,
    DEFINITIONS.LEFT,
    DEFINITIONS.DOWN,
    DEFINITIONS.UP,
}

--#endregion DIRECTION DEFINITIONS ============================================

--#region PUBLIC FACTORY ======================================================

function addon.GetGrowthDirection(value)
    return DEFINITIONS[value] or DEFINITIONS.DOWN
end

function addon.CreateGrowthDirectionDropdown(name, parent, cfg)
    cfg = cfg or {}
    return addon.CreateDropdown(name, parent, cfg.label or "Growth Direction", OPTIONS, {
        width = cfg.width or 106,
        get_value = cfg.get_value,
        on_select = cfg.on_select,
        is_option_visible = function(option)
            local vertical_only = type(cfg.vertical_only) == "function"
                and cfg.vertical_only()
                or cfg.vertical_only == true
            return not vertical_only or option.vertical
        end,
    })
end

--#endregion PUBLIC FACTORY ===================================================
