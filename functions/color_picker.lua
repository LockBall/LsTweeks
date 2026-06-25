-- Color picker widget that wraps the system ColorPickerFrame with an integrated reset button.
-- addon.CreateColorPicker(parent, db, key, has_alpha, label, defaults, cb) returns a 95×45 container;
-- the reset button restores the default color from the defaults table.
local addon_name, addon = ...

local control_gap = 5
local CONTAINER_W  = 95
local CONTAINER_H  = 45
local BTN_SIZE     = 18
local RESET_W      = 45
local RESET_H      = 16
local GROUP_W      = BTN_SIZE + control_gap + RESET_W

function addon.CreateColorPicker(parent, db_table, db_key, has_alpha, label_text, defaults_table, callback)
    local container = addon.CreateControlPanel(parent, CONTAINER_W, CONTAINER_H)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", container, "TOP", 0, -control_gap)
    label:SetJustifyH("CENTER")
    label:SetText(label_text)

    -- Group centers button + reset as a unit below the label
    local group = CreateFrame("Frame", nil, container)
    group:SetSize(GROUP_W, BTN_SIZE)
    group:SetPoint("TOP", label, "BOTTOM", 0, -control_gap)

    -- Color Picker Button
    local button = CreateFrame("Button", nil, group, "BackdropTemplate")
    button:SetSize(BTN_SIZE, BTN_SIZE)
    button:SetPoint("LEFT", group, "LEFT", 0, 0)
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameColorSwatch",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8
    })

    -- Reset Button
    local reset = CreateFrame("Button", nil, group, "UIPanelButtonTemplate")
    reset:SetSize(RESET_W, RESET_H)
    reset:SetText("Reset")
    if addon.ApplyStandardButtonStyle then
        addon.ApplyStandardButtonStyle(reset)
    end
    reset:SetPoint("LEFT", button, "RIGHT", control_gap, 0)

    -- Local update helper
    local function apply_and_refresh(r, g, b, a)
        button:SetBackdropColor(r, g, b, a or 1)
        if type(callback) == "function" then callback() end
    end

    -- Setup Initial Color
    local c = db_table[db_key]
    if c then button:SetBackdropColor(c.r, c.g, c.b, c.a or 1) end

    -- Reset Logic with Type Check
    reset:SetScript("OnClick", function()
        -- Defensive check to ensure defaults_table is actually a table
        if type(defaults_table) ~= "table" then 
            print("|cFFFF0000LsTweaks Error:|r Invalid defaults table in ColorPicker.")
            return 
        end

        local dc = defaults_table[db_key]
        if dc then
            db_table[db_key] = has_alpha and {r=dc.r, g=dc.g, b=dc.b, a=dc.a} or {r=dc.r, g=dc.g, b=dc.b}
            apply_and_refresh(dc.r, dc.g, dc.b, dc.a)
        end
    end)

    -- Color Picker Dialog
    button:SetScript("OnClick", function()
        local current = db_table[db_key]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = current.r, g = current.g, b = current.b,
            hasOpacity = has_alpha,
            opacity = current.a or 1,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = has_alpha and ColorPickerFrame:GetColorAlpha() or 1
                db_table[db_key] = has_alpha and {r=r, g=g, b=b, a=a} or {r=r, g=g, b=b}
                apply_and_refresh(r, g, b, a)
            end,
            cancelFunc = function()
                db_table[db_key] = current
                apply_and_refresh(current.r, current.g, current.b, current.a)
            end
        })
    end)

    container.SetValue = function(_, color)
        if color then
            button:SetBackdropColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
        end
    end

    container.GetValue = function()
        return db_table[db_key]
    end

    return container
end
