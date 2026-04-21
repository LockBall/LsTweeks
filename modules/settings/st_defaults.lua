local addon_name, addon = ...

local M = {}

M.defaults = {
    minimap = { hide = false },
    open_on_reload = false,
    interface_alpha = 0.5,
}

addon.module_defaults = addon.module_defaults or {}
addon.module_defaults.st = M.defaults

return M
