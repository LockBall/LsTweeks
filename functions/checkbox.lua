-- Styled checkbox widget factory: addon.CreateCheckbox(parent, label, checked, cb).
-- Returns a container frame holding the checkbox and its label; container width adjusts to the label text.
-- Use the container API for routine state handling: GetChecked(), SetChecked(),
-- SetCheckedSilently(), SetEnabled(), Enable(), Disable(), and HookCheckedChanged().


local addon_name, addon = ...

--#region CHECKBOX FACTORY ====================================================

function addon.CreateCheckbox(parent, label_text, is_checked, on_click_callback)
    local theme = addon.UI_THEME

    -- Container frame (will be sized dynamically)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(24)

    -- Checkbox button
    local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("LEFT", container, "LEFT", 0, 0)
    checkbox:SetChecked(is_checked)

    -- Label
    local gap = 4
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", gap, 0)
    label:SetText(label_text)
    label:SetTextColor(1, 1, 1, 1)

    local function set_label_enabled(enabled)
        if enabled then
            label:SetTextColor(1, 1, 1, 1)
        else
            label:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    end

    -- Calculate dynamic width based on label text
    local label_width = label:GetStringWidth()
    local checkbox_width = 24
    local padding = 4
    local total_width = checkbox_width + gap + label_width + padding
    container:SetWidth(total_width)

    local suppress_callback = false

    -- Click handler
    checkbox:SetScript("OnClick", function(self)
        if not suppress_callback and type(on_click_callback) == "function" then
            on_click_callback(self:GetChecked())
        end
    end)

    local checkbox_set_enabled = checkbox.SetEnabled
    local checkbox_enable = checkbox.Enable
    local checkbox_disable = checkbox.Disable

    checkbox.SetEnabled = function(self, enabled)
        checkbox_set_enabled(self, enabled)
        set_label_enabled(enabled)
    end
    checkbox.Enable = function(self)
        checkbox_enable(self)
        set_label_enabled(true)
    end
    checkbox.Disable = function(self)
        checkbox_disable(self)
        set_label_enabled(false)
    end
    container.SetEnabled = function(_, enabled)
        checkbox:SetEnabled(enabled)
    end
    container.Enable = function()
        checkbox:Enable()
    end
    container.Disable = function()
        checkbox:Disable()
    end
    container.GetChecked = function()
        return checkbox:GetChecked()
    end
    container.SetChecked = function(_, checked)
        checkbox:SetChecked(checked)
    end
    container.SetCheckedSilently = function(_, checked)
        local was_suppressed = suppress_callback
        suppress_callback = true
        local ok, err = pcall(checkbox.SetChecked, checkbox, checked)
        suppress_callback = was_suppressed
        if not ok then error(err, 0) end
    end
    container.HookCheckedChanged = function(_, handler, opts)
        if type(handler) ~= "function" then return end
        opts = opts or {}
        checkbox:HookScript("OnClick", function()
            if suppress_callback and opts.run_when_silent ~= true then
                return
            end
            handler(container, checkbox:GetChecked())
        end)
    end
    container.checkbox = checkbox
    container.label = label

    return container, checkbox, label
end

--#endregion CHECKBOX FACTORY =================================================
