-- Aura Frames settings grid helper wrapper.
-- Shared grid implementation lives in functions/layout_grid.lua as addon.CreateSettingsGrid().
local addon_name, addon = ...

addon.aura_frames = addon.aura_frames or {}
local M = addon.aura_frames

function M.create_settings_grid(parent, opts)
    return addon.CreateSettingsGrid(parent, opts)
end
