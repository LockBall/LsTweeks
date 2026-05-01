-- Destructive-action button factory: addon.CreateClearButton(parent, label, cb).
-- Returns a UIPanelButtonTemplate button with red-tinted text; caller sets size and position.
local addon_name, addon = ...

function addon.CreateClearButton(parent, label_text, on_click_callback)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetText(label_text or "Clear")
    btn:GetFontString():SetTextColor(0.9, 0.5, 0.5)
    btn:SetScript("OnClick", function()
        if type(on_click_callback) == "function" then
            on_click_callback()
        end
    end)
    return btn
end
