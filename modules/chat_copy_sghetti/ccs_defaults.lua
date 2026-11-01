-- ChatCopySghetti owns chat export settings and bounded snapshot metadata.
local _, addon = ...

--#region MODULE DEFAULTS =====================================================
addon.chat_copy_sghetti = { controls = {}, buttons = {} }
local M = addon.chat_copy_sghetti
M.MODULE_KEY = "chat_copy_sghetti"
M.CATEGORY_NAME = "ChatCopySghetti"
M.MESSAGE_RANGE = { min = 25, max = 1000, step = 25 }
M.MAX_EXPORT_BYTES = 200000
M.WINDOW_MINIMUM = { width = 600, height = 300 }
M.defaults = { chat_copy_sghetti = {
    keep_brackets = true,
    max_messages = 250,
    background_color = { r = 0.08, g = 0.08, b = 0.08, a = 1 },
    window = { width = 720, height = 460, x = 0, y = 0 },
} }

function M.get_db()
    return Ls_Tweeks_DB.chat_copy_sghetti
end
--#endregion MODULE DEFAULTS ==================================================
