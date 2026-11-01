-- ChatCopySghetti controller: module lifecycle, copy icons and status.
local addon_name, addon = ...
local M = addon.chat_copy_sghetti
local InCombatLockdown = InCombatLockdown
local InChatMessagingLockdown = C_ChatInfo.InChatMessagingLockdown
local loader = CreateFrame("Frame")
local hooks_installed = false


--#region EXPORT ACTION =======================================================
function M.open_export(frame)
    if not addon.is_module_enabled(M.MODULE_KEY) then return end
    if InCombatLockdown() or InChatMessagingLockdown() then
        print("ChatCopySghetti: export is unavailable during combat or chat messaging lockdown.")
        return
    end
    if not frame or frame == ChatFrame2 then
        print("ChatCopySghetti: select a regular chat tab first; the combat log is not supported.")
        return
    end
    local text, report = M.collect_snapshot(frame, M.get_db())
    M.show_export(text, report)
end
--#endregion EXPORT ACTION ====================================================

--#region CHAT COPY ICONS ======================================================
local function draw_copy_icon(button)
    -- Original two-page silhouette constructed from plain colored regions.
    for index = 1, 2 do
        local x, y = index == 1 and 6 or 10, index == 1 and -4 or -8
        for _, edge in ipairs({ {0, 0, 9, 1}, {0, -12, 9, 1}, {0, 0, 1, 13}, {8, 0, 1, 13} }) do
            local region = button:CreateTexture(nil, "OVERLAY")
            region:SetColorTexture(1, 0.82, 0, 1)
            region:SetSize(edge[3], edge[4])
            region:SetPoint("TOPLEFT", button, "TOPLEFT", x + edge[1], y + edge[2])
        end
    end
end

function M.refresh_buttons()
    if not addon.is_module_enabled(M.MODULE_KEY) then return end
    if InCombatLockdown() then return end -- Creation/placement waits for regen.
    for _, name in ipairs(CHAT_FRAMES) do
        local frame = _G[name]
        -- Temporary chat windows can be absent; the combat log has separate semantics.
        if frame and frame ~= ChatFrame2 then
            local button = M.buttons[frame]
            if not button then
                button = addon.CreateTextButton(frame, "", function() M.open_export(frame) end, {
                    width = 26, height = 26, fit_to_text = false,
                })
                button:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", -4, 4)
                draw_copy_icon(button)
                addon.AttachTooltip(button, "ChatCopySghetti", "Export this chat window for manual copying.")
                M.buttons[frame] = button
            end
            if not button:IsShown() then button:Show() end
        end
    end
end
--#endregion CHAT COPY ICONS ==================================================

--#region MODULE LIFECYCLE ====================================================
local function stop_runtime()
    loader:UnregisterEvent("PLAYER_REGEN_DISABLED")
    loader:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if M.popup then M.popup:Hide() end
    for _, button in pairs(M.buttons) do button:Hide() end
end

function M.set_module_enabled(enabled)
    if not enabled then stop_runtime(); return end
    loader:RegisterEvent("PLAYER_REGEN_DISABLED")
    loader:RegisterEvent("PLAYER_REGEN_ENABLED")
    if not hooks_installed then
        -- Hooks are permanent, but disabled/combat paths return before owned work.
        hooksecurefunc("FCF_OpenNewWindow", M.refresh_buttons)
        hooksecurefunc("FCF_OpenTemporaryWindow", M.refresh_buttons)
        hooks_installed = true
    end
    M.refresh_buttons()
end

function M.on_reset_complete()
    if M.popup then M.popup:Hide() end
    M.sync_controls()
    M.refresh_buttons()
end

addon.register_module_status(M.MODULE_KEY, function()
    local count = 0
    for _, button in pairs(M.buttons) do if button:IsShown() then count = count + 1 end end
    return {
        "copy_icons=" .. count,
        "export_open=" .. tostring(M.popup ~= nil and M.popup:IsShown()),
        "chat_hooks=" .. tostring(hooks_installed),
        "combat_events=" .. tostring(loader:IsEventRegistered("PLAYER_REGEN_ENABLED")),
    }
end)

loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addon_name then return end
        if Ls_Tweeks_DB.chat_copy_sghetti == nil then Ls_Tweeks_DB.chat_copy_sghetti = {} end
        addon.apply_defaults(M.defaults.chat_copy_sghetti, Ls_Tweeks_DB.chat_copy_sghetti)
        local color = M.get_db().background_color
        local default_color = M.defaults.chat_copy_sghetti.background_color
        for _, component in ipairs({ "r", "g", "b", "a" }) do
            color[component] = addon.clamp_number(color[component], default_color[component], { min = 0, max = 1 })
        end
        addon.register_category(M.CATEGORY_NAME, M.build_options_panel, { order = 650, module_key = M.MODULE_KEY })
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        M.set_module_enabled(addon.is_module_enabled(M.MODULE_KEY))
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_REGEN_DISABLED" then
        if M.popup then M.popup:Hide() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        M.refresh_buttons()
    end
end)
--#endregion MODULE LIFECYCLE ==================================================
