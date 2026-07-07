-- Headless WoW API stub for out-of-game tests: fakes frames, C_Timer, events, and common globals
-- with a manually advanced clock so runtime logic can be exercised deterministically under desktop Lua 5.1.
-- Runs under desktop Lua, not the WoW client; the workspace LuaLS profile is the WoW environment,
-- so desktop globals and intentional stub patterns are suppressed file-wide here.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

local stub = {}
stub.now = 0
stub.missing_globals = {}
stub.timers = {}
stub.frames = {}
stub.strict_missing = false

--#region clock and C_Timer

local timer_seq = 0

local function schedule(delay, callback, iterations)
    timer_seq = timer_seq + 1
    local t = {
        fires_at = stub.now + math.max(0, tonumber(delay) or 0),
        interval = delay,
        callback = callback,
        iterations = iterations, -- nil = one-shot, 0/false-y handled by caller, math.huge for tickers
        cancelled = false,
        seq = timer_seq,
    }
    t.Cancel = function(self) self.cancelled = true end
    t.IsCancelled = function(self) return self.cancelled end
    table.insert(stub.timers, t)
    return t
end

-- Advance the fake clock, firing due timers in chronological order.
-- Timers scheduled by fired callbacks are honored within the same advance.
function stub.Advance(dt)
    local target = stub.now + (tonumber(dt) or 0)
    while true do
        local next_timer = nil
        for _, t in ipairs(stub.timers) do
            if not t.cancelled and t.fires_at <= target then
                if not next_timer
                    or t.fires_at < next_timer.fires_at
                    or (t.fires_at == next_timer.fires_at and t.seq < next_timer.seq) then
                    next_timer = t
                end
            end
        end
        if not next_timer then break end

        stub.now = next_timer.fires_at
        if next_timer.iterations then
            next_timer.iterations = next_timer.iterations - 1
            if next_timer.iterations <= 0 then
                next_timer.cancelled = true
            else
                timer_seq = timer_seq + 1
                next_timer.seq = timer_seq
                next_timer.fires_at = stub.now + next_timer.interval
            end
        else
            next_timer.cancelled = true
        end
        next_timer.callback(next_timer)
    end
    stub.now = target
    -- prune dead timers
    for i = #stub.timers, 1, -1 do
        if stub.timers[i].cancelled then table.remove(stub.timers, i) end
    end
    -- pump OnUpdate once per advance for visible frames (elapsed = full dt),
    -- matching addon fades that compute progress from GetTime()
    for _, f in ipairs(stub.frames) do
        local on_update = f.__scripts and f.__scripts.OnUpdate
        if on_update and f:IsVisible() then
            on_update(f, dt)
        end
    end
end

function stub.ActiveTimerCount()
    local n = 0
    for _, t in ipairs(stub.timers) do
        if not t.cancelled then n = n + 1 end
    end
    return n
end

C_Timer = {
    After = function(delay, callback) schedule(delay, callback) end,
    NewTimer = function(delay, callback) return schedule(delay, callback) end,
    NewTicker = function(interval, callback, iterations)
        return schedule(interval, callback, iterations or math.huge)
    end,
}

function GetTime() return stub.now end
function GetTimePreciseSec() return stub.now end
function debugprofilestop() return stub.now * 1000 end

--#endregion clock and C_Timer


--#region frame and region mocks

local frame_methods = {}
local frame_meta = { __index = frame_methods }

local function new_region(kind, name, parent)
    local r = setmetatable({
        __kind = kind,
        __name = name,
        __parent = parent,
        __shown = true,
        __alpha = 1,
        __width = 0,
        __height = 0,
        __scripts = {},
        __events = {},
        __points = {},
        __children = {},
        __regions = {},
        __calls = {},
        __attributes = {},
        __text = nil,
        __value = 0,
    }, frame_meta)
    if name and name ~= "" then _G[name] = r end
    return r
end

-- record every method call for test assertions
local function record(self, method, ...)
    local calls = self.__calls[method]
    if not calls then
        calls = {}
        self.__calls[method] = calls
    end
    calls[#calls + 1] = { ... }
end

function frame_methods:GetCalls(method) return self.__calls[method] end

function frame_methods:GetLastCall(method)
    local calls = self.__calls[method]
    return calls and calls[#calls]
end

function frame_methods:Show()
    record(self, "Show")
    local was_shown = self.__shown
    self.__shown = true
    if not was_shown and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end

function frame_methods:Hide()
    record(self, "Hide")
    local was_shown = self.__shown
    self.__shown = false
    if was_shown and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end

function frame_methods:SetShown(shown)
    if shown then self:Show() else self:Hide() end
end

function frame_methods:IsShown() return self.__shown end

function frame_methods:IsVisible()
    local f = self
    while f do
        if not f.__shown then return false end
        f = f.__parent
    end
    return true
end

function frame_methods:SetAlpha(a) record(self, "SetAlpha", a); self.__alpha = a end
function frame_methods:GetAlpha() return self.__alpha end
function frame_methods:GetEffectiveAlpha() return self.__alpha end

function frame_methods:SetWidth(w) self.__width = w end
function frame_methods:SetHeight(h) self.__height = h end
function frame_methods:SetSize(w, h) self.__width, self.__height = w, h end
function frame_methods:GetWidth() return self.__width end
function frame_methods:GetHeight() return self.__height end
function frame_methods:GetSize() return self.__width, self.__height end

function frame_methods:SetPoint(...)
    record(self, "SetPoint", ...)
    self.__points[#self.__points + 1] = { ... }
end

function frame_methods:ClearAllPoints() self.__points = {} end
function frame_methods:GetNumPoints() return #self.__points end

function frame_methods:GetPoint(i)
    local p = self.__points[i or 1]
    if not p then return nil end
    return unpack(p)
end

function frame_methods:GetCenter() return self.__width / 2, self.__height / 2 end
function frame_methods:GetLeft() return 0 end
function frame_methods:GetRight() return self.__width end
function frame_methods:GetTop() return self.__height end
function frame_methods:GetBottom() return 0 end
function frame_methods:GetRect() return 0, 0, self.__width, self.__height end

function frame_methods:SetParent(p) self.__parent = p end
function frame_methods:GetParent() return self.__parent end
function frame_methods:GetName() return self.__name end
function frame_methods:GetObjectType() return self.__kind end
function frame_methods:IsObjectType(kind) return self.__kind == kind end

function frame_methods:SetScript(handler, fn)
    record(self, "SetScript", handler, fn)
    self.__scripts[handler] = fn
end

function frame_methods:GetScript(handler) return self.__scripts[handler] end

function frame_methods:HookScript(handler, fn)
    record(self, "HookScript", handler, fn)
    local existing = self.__scripts[handler]
    if existing then
        self.__scripts[handler] = function(...)
            existing(...)
            fn(...)
        end
    else
        self.__scripts[handler] = fn
    end
end

function frame_methods:RegisterEvent(event) self.__events[event] = true end
function frame_methods:RegisterUnitEvent(event) self.__events[event] = true end
function frame_methods:UnregisterEvent(event) self.__events[event] = nil end
function frame_methods:UnregisterAllEvents() self.__events = {} end
function frame_methods:IsEventRegistered(event) return self.__events[event] == true end

function frame_methods:CreateTexture(name, _layer)
    local t = new_region("Texture", name, self)
    self.__regions[#self.__regions + 1] = t
    return t
end

function frame_methods:CreateFontString(name, _layer, _template)
    local fs = new_region("FontString", name, self)
    self.__regions[#self.__regions + 1] = fs
    return fs
end

function frame_methods:CreateMaskTexture(name)
    return new_region("MaskTexture", name, self)
end

function frame_methods:CreateAnimationGroup(name)
    local group = new_region("AnimationGroup", name, self)
    group.CreateAnimation = function(g, kind)
        return new_region(kind or "Animation", nil, g)
    end
    group.Play = function(g) record(g, "Play") end
    group.Stop = function(g) record(g, "Stop") end
    group.IsPlaying = function() return false end
    return group
end

function frame_methods:GetChildren() return unpack(self.__children) end
function frame_methods:GetNumChildren() return #self.__children end
function frame_methods:GetRegions() return unpack(self.__regions) end

-- FontString / text widgets
function frame_methods:SetText(text) record(self, "SetText", text); self.__text = text end
function frame_methods:GetText() return self.__text end
function frame_methods:SetFormattedText(fmt, ...) self.__text = string.format(fmt, ...) end
function frame_methods:GetStringWidth() return (self.__text and #tostring(self.__text) or 0) * 7 end
function frame_methods:GetStringHeight() return 12 end
function frame_methods:SetFontObject() end
function frame_methods:GetFontObject() return nil end
function frame_methods:SetFont() end
function frame_methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function frame_methods:SetTextColor(...) record(self, "SetTextColor", ...) end
function frame_methods:SetJustifyH() end
function frame_methods:SetJustifyV() end
function frame_methods:SetWordWrap() end
function frame_methods:SetNonSpaceWrap() end
function frame_methods:SetMaxLines() end
function frame_methods:SetShadowOffset() end
function frame_methods:SetShadowColor() end
function frame_methods:SetTextScale() end

-- Texture widgets
function frame_methods:SetTexture(...) record(self, "SetTexture", ...) end
function frame_methods:GetTexture() return nil end
function frame_methods:SetAtlas(...) record(self, "SetAtlas", ...) end
function frame_methods:SetTexCoord(...) record(self, "SetTexCoord", ...) end
function frame_methods:SetColorTexture(...) record(self, "SetColorTexture", ...) end
function frame_methods:SetVertexColor(...) record(self, "SetVertexColor", ...) end
function frame_methods:GetVertexColor() return 1, 1, 1, 1 end
function frame_methods:SetDesaturated() end
function frame_methods:SetRotation() end
function frame_methods:SetBlendMode() end
function frame_methods:SetGradient() end
function frame_methods:SetDrawLayer() end
function frame_methods:GetDrawLayer() return "ARTWORK", 0 end
function frame_methods:AddMaskTexture() end
function frame_methods:SetMask() end
function frame_methods:SetSnapToPixelGrid() end
function frame_methods:SetTexelSnappingBias() end

-- Slider / StatusBar widgets
function frame_methods:SetValue(v) record(self, "SetValue", v); self.__value = v end
function frame_methods:GetValue() return self.__value end
function frame_methods:SetMinMaxValues(lo, hi) self.__min, self.__max = lo, hi end
function frame_methods:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function frame_methods:SetValueStep(step) self.__step = step end
function frame_methods:GetValueStep() return self.__step or 1 end
function frame_methods:SetObeyStepOnDrag() end
function frame_methods:SetOrientation() end
function frame_methods:SetStatusBarTexture() end
function frame_methods:GetStatusBarTexture() return new_region("Texture", nil, self) end
function frame_methods:SetStatusBarColor(...) record(self, "SetStatusBarColor", ...) end
function frame_methods:SetThumbTexture() end
function frame_methods:GetThumbTexture() return new_region("Texture", nil, self) end
function frame_methods:SetFillStyle() end
function frame_methods:SetReverseFill() end

-- EditBox widgets
function frame_methods:SetNumber(n) self.__text = tostring(n) end
function frame_methods:GetNumber() return tonumber(self.__text) or 0 end
function frame_methods:SetAutoFocus() end
function frame_methods:ClearFocus() end
function frame_methods:SetFocus() end
function frame_methods:HasFocus() return false end
function frame_methods:SetCursorPosition() end
function frame_methods:HighlightText() end
function frame_methods:SetNumeric() end
function frame_methods:SetMaxLetters() end
function frame_methods:SetTextInsets() end

-- Button widgets
function frame_methods:SetNormalTexture() end
function frame_methods:SetPushedTexture() end
function frame_methods:SetHighlightTexture() end
function frame_methods:SetDisabledTexture() end
function frame_methods:GetNormalTexture() return new_region("Texture", nil, self) end
function frame_methods:GetPushedTexture() return new_region("Texture", nil, self) end
function frame_methods:GetHighlightTexture() return new_region("Texture", nil, self) end
function frame_methods:SetNormalFontObject() end
function frame_methods:SetHighlightFontObject() end
function frame_methods:SetDisabledFontObject() end
function frame_methods:GetFontString()
    if not self.__fontstring then
        self.__fontstring = new_region("FontString", nil, self)
    end
    return self.__fontstring
end
function frame_methods:SetEnabled(enabled) self.__enabled = enabled ~= false end
function frame_methods:Enable() self.__enabled = true end
function frame_methods:Disable() self.__enabled = false end
function frame_methods:IsEnabled() return self.__enabled ~= false end
function frame_methods:RegisterForClicks() end
function frame_methods:RegisterForDrag() end
function frame_methods:Click()
    if self.__scripts.OnClick then self.__scripts.OnClick(self, "LeftButton") end
end
function frame_methods:SetChecked(checked) record(self, "SetChecked", checked); self.__checked = checked and true or false end
function frame_methods:GetChecked() return self.__checked == true end

-- CheckButton textures
function frame_methods:SetCheckedTexture() end
function frame_methods:GetCheckedTexture() return new_region("Texture", nil, self) end
function frame_methods:SetDisabledCheckedTexture() end

-- misc frame behavior
function frame_methods:SetScale() end
function frame_methods:GetScale() return 1 end
function frame_methods:GetEffectiveScale() return 1 end
function frame_methods:SetFrameStrata(s) self.__strata = s end
function frame_methods:GetFrameStrata() return self.__strata or "MEDIUM" end
function frame_methods:SetFrameLevel(l) self.__level = l end
function frame_methods:GetFrameLevel() return self.__level or 0 end
function frame_methods:SetToplevel() end
function frame_methods:Raise() end
function frame_methods:Lower() end
function frame_methods:EnableMouse() end
function frame_methods:EnableMouseWheel() end
function frame_methods:EnableKeyboard() end
function frame_methods:IsMouseOver() return false end
function frame_methods:IsMouseEnabled() return false end
function frame_methods:SetMovable() end
function frame_methods:IsMovable() return false end
function frame_methods:SetResizable() end
function frame_methods:SetUserPlaced() end
function frame_methods:StartMoving() end
function frame_methods:StartSizing() end
function frame_methods:StopMovingOrSizing() end
function frame_methods:SetClampedToScreen() end
function frame_methods:SetClampRectInsets() end
function frame_methods:SetHitRectInsets() end
function frame_methods:SetResizeBounds() end
function frame_methods:SetMinResize() end
function frame_methods:SetMaxResize() end
function frame_methods:SetPropagateMouseClicks() end
function frame_methods:SetPropagateMouseMotion() end
function frame_methods:SetPropagateKeyboardInput() end
function frame_methods:SetIgnoreParentAlpha() end
function frame_methods:SetIgnoreParentScale() end
function frame_methods:SetAttribute(k, v) self.__attributes[k] = v end
function frame_methods:GetAttribute(k) return self.__attributes[k] end
function frame_methods:SetID(id) self.__id = id end
function frame_methods:GetID() return self.__id or 0 end
function frame_methods:SetBackdrop() end
function frame_methods:SetBackdropColor(...) record(self, "SetBackdropColor", ...) end
function frame_methods:SetBackdropBorderColor(...) record(self, "SetBackdropBorderColor", ...) end
function frame_methods:GetBackdrop() return nil end
function frame_methods:ApplyBackdrop() end
function frame_methods:SetClipsChildren() end
function frame_methods:SetMouseClickEnabled() end
function frame_methods:SetMouseMotionEnabled() end
function frame_methods:SetFlattensRenderLayers() end
function frame_methods:DesaturateHierarchy() end
function frame_methods:SetDontSavePosition() end
function frame_methods:SetFixedFrameStrata() end
function frame_methods:SetFixedFrameLevel() end
function frame_methods:SetHyperlinksEnabled() end
function frame_methods:SetDrawLayerEnabled() end
function frame_methods:UpdateScrollChildRect() end
function frame_methods:SetScrollChild(child) self.__scroll_child = child end
function frame_methods:GetScrollChild() return self.__scroll_child end
function frame_methods:SetVerticalScroll() end
function frame_methods:GetVerticalScroll() return 0 end
function frame_methods:GetVerticalScrollRange() return 0 end
function frame_methods:SetHorizontalScroll() end

-- Cooldown widgets
function frame_methods:SetCooldown() end
function frame_methods:Clear() end
function frame_methods:SetReverse() end
function frame_methods:SetHideCountdownNumbers() end
function frame_methods:SetSwipeColor() end
function frame_methods:SetDrawEdge() end
function frame_methods:SetDrawBling() end
function frame_methods:SetDrawSwipe() end

-- GameTooltip methods
function frame_methods:SetOwner(owner, anchor) record(self, "SetOwner", owner, anchor) end
function frame_methods:GetOwner() return nil end
function frame_methods:IsOwned() return false end
function frame_methods:AddLine(...) record(self, "AddLine", ...) end
function frame_methods:AddDoubleLine(...) record(self, "AddDoubleLine", ...) end
function frame_methods:ClearLines() record(self, "ClearLines") end
function frame_methods:SetUnitAura() end
function frame_methods:SetUnitBuff() end
function frame_methods:SetUnitDebuff() end
function frame_methods:SetSpellByID() end
function frame_methods:SetAnchorType() end
function frame_methods:NumLines() return 0 end
function frame_methods:FadeOut() record(self, "FadeOut") end

-- Unknown methods become recorded no-ops so template-provided or niche
-- widget APIs do not crash logic under test. Getters not modeled above
-- should be added explicitly when a test needs a real return value.
local METHOD_VERB_PREFIXES = {
    "Set", "Get", "Is", "Has", "Can", "Enable", "Disable", "Register", "Unregister",
    "Create", "Add", "Clear", "Show", "Hide", "Start", "Stop", "Play", "Pause",
    "Apply", "Update", "Refresh", "Lock", "Unlock", "Raise", "Lower", "Fade",
    "Anchor", "Adjust", "Reset", "Select", "Toggle", "Init",
}

local function looks_like_method(key)
    for _, prefix in ipairs(METHOD_VERB_PREFIXES) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

setmetatable(frame_methods, {
    __index = function(_, key)
        -- Only verb-prefixed keys become no-op methods; everything else (data
        -- fields, Blizzard sub-frame keys like .NineSlice) reads as nil like in-game.
        if type(key) ~= "string" or not looks_like_method(key) then return nil end
        local fn = function(self, ...)
            if type(self) == "table" and self.__calls then record(self, key, ...) end
            return nil
        end
        rawset(frame_methods, key, fn)
        return fn
    end,
})

function CreateFrame(kind, name, parent, template)
    local f = new_region(kind or "Frame", name, parent)
    f.__template = template
    if parent and parent.__children then
        parent.__children[#parent.__children + 1] = f
    end
    stub.frames[#stub.frames + 1] = f
    -- minimal template affordances used by shared factories
    if template and template:find("UIPanelScrollFrameTemplate") then
        f.ScrollBar = new_region("Slider", name and (name .. "ScrollBar") or nil, f)
    end
    if template and template:find("MinimalSliderWithSteppersTemplate") then
        f.Slider = new_region("Slider", nil, f)
        f.Back = new_region("Button", nil, f)
        f.Forward = new_region("Button", nil, f)
    end
    if kind == "GameTooltip" or (template and template:find("GameTooltipTemplate")) then
        f.TextLeft1 = new_region("FontString", name and (name .. "TextLeft1") or nil, f)
    end
    return f
end

stub.NewRegion = new_region
stub.FrameMethods = frame_methods

-- Fire an event to every stub frame registered for it, mirroring the client.
function stub.FireEvent(event, ...)
    for _, f in ipairs(stub.frames) do
        if f.__events[event] and f.__scripts.OnEvent then
            f.__scripts.OnEvent(f, event, ...)
        end
    end
end

--#endregion frame and region mocks


--#region common globals

-- Lua library aliases WoW exposes
strmatch, strfind, strsub, strlower, strupper, strrep, strlen = string.match, string.find, string.sub, string.lower, string.upper, string.rep, string.len
format, gsub, gmatch, strbyte, strchar = string.format, string.gsub, string.gmatch, string.byte, string.char
tinsert, tremove, sort, wipe = table.insert, table.remove, table.sort, function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
table.wipe = wipe
floor, ceil, abs, min, max, sqrt = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt
mod = math.fmod
math.huge = math.huge

function strsplit(sep, str)
    if not str then return end
    local results = {}
    local pattern = "([^" .. sep .. "]+)"
    for piece in string.gmatch(str, pattern) do
        results[#results + 1] = piece
    end
    return unpack(results)
end

function strjoin(sep, ...) return table.concat({ ... }, sep) end
function strtrim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
function tContains(t, item)
    for _, v in pairs(t) do
        if v == item then return true end
    end
    return false
end
function tIndexOf(t, item)
    for i, v in ipairs(t) do
        if v == item then return i end
    end
    return nil
end
function CopyTable(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and CopyTable(v) or v
    end
    return copy
end
function Mixin(target, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        for k, v in pairs(mixin) do target[k] = v end
    end
    return target
end
function CreateFromMixins(...) return Mixin({}, ...) end
function Clamp(value, lo, hi) return math.min(hi, math.max(lo, value)) end
function Saturate(value) return Clamp(value, 0, 1) end
function Lerp(a, b, t) return a + (b - a) * t end
function Round(v) return math.floor(v + 0.5) end
function GetValueOrCallFunction(v, ...) if type(v) == "function" then return v(...) end return v end
function securecall(fn, ...) if type(fn) == "function" then return fn(...) end end
function issecure() return false end
function issecurevariable() return false end
function geterrorhandler() return function(err) error(err, 2) end end
function seterrorhandler() end
function debugstack() return debug.traceback() end
function getglobal(name) return _G[name] end
function setglobal(name, value) _G[name] = value end
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.0.7", "99999", "Jan 1 2026", 120007 end
function IsLoggedIn() return true end
function IsAddOnLoaded() return false end
function InCombatLockdown() return stub.in_combat == true end
function UnitAffectingCombat(_unit) return stub.in_combat == true end

stub.in_combat = false
stub.hooked_functions = {}

function hooksecurefunc(table_or_name, name_or_fn, maybe_fn)
    local owner, fn_name, hook
    if type(table_or_name) == "table" then
        owner, fn_name, hook = table_or_name, name_or_fn, maybe_fn
    else
        owner, fn_name, hook = _G, table_or_name, name_or_fn
    end
    local original = owner[fn_name]
    stub.hooked_functions[fn_name] = hook
    if type(original) == "function" then
        owner[fn_name] = function(...)
            local result = original(...)
            hook(...)
            return result
        end
    end
end

RAID_CLASS_COLORS = setmetatable({}, {
    __index = function()
        return { r = 1, g = 1, b = 1, colorStr = "ffffffff", GetRGB = function() return 1, 1, 1 end }
    end,
})

function CreateColor(r, g, b, a)
    return {
        r = r, g = g, b = b, a = a,
        GetRGB = function() return r, g, b end,
        GetRGBA = function() return r, g, b, a end,
        GenerateHexColor = function() return "ffffffff" end,
        WrapTextInColorCode = function(_, text) return text end,
    }
end

NORMAL_FONT_COLOR = CreateColor(1, 0.82, 0)
HIGHLIGHT_FONT_COLOR = CreateColor(1, 1, 1)
RED_FONT_COLOR = CreateColor(1, 0.1, 0.1)
GREEN_FONT_COLOR = CreateColor(0.1, 1, 0.1)
GRAY_FONT_COLOR = CreateColor(0.5, 0.5, 0.5)
WHITE_FONT_COLOR = CreateColor(1, 1, 1)

SlashCmdList = {}
MinimalSliderWithSteppersMixin = {
    Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 },
    Event = { OnValueChanged = "OnValueChanged" },
}
function CreateMinimalSliderFormatter() return {} end
function PanelTemplates_TabResize() end
function PanelTemplates_SetTab() end
function PanelTemplates_SelectTab() end
function PanelTemplates_DeselectTab() end
function PanelTemplates_SetNumTabs() end
function PanelTemplates_UpdateTabs() end
SOUNDKIT = setmetatable({}, { __index = function() return 0 end })
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
GameFontNormal, GameFontHighlight, GameFontHighlightSmall, GameFontNormalSmall, GameFontNormalLarge, GameFontDisable, GameFontDisableSmall =
    {}, {}, {}, {}, {}, {}, {}

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
WorldFrame = CreateFrame("Frame", "WorldFrame")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
PlayerFrame = CreateFrame("Frame", "PlayerFrame", UIParent)
PlayerFrame.PlayerFrameContent = CreateFrame("Frame", nil, PlayerFrame)
PlayerFrame.PlayerFrameContent.PlayerFrameContentMain = CreateFrame("Frame", nil, PlayerFrame.PlayerFrameContent)
PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator = CreateFrame("Frame", nil, PlayerFrame.PlayerFrameContent.PlayerFrameContentMain)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
ObjectiveTrackerFrame.NineSlice = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
ObjectiveTrackerFrame.Header = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
ObjectiveTrackerFrame.Header.Text = ObjectiveTrackerFrame.Header:CreateFontString()
ObjectiveTrackerFrame.Header.MinimizeButton = CreateFrame("Button", nil, ObjectiveTrackerFrame.Header)

--#endregion common globals


--#region C_* namespaces and unit API

C_AddOns = {
    GetAddOnMetadata = function(_name, field)
        if field == "Version" then return "00.00.test" end
        return nil
    end,
    IsAddOnLoaded = function() return false end,
    LoadAddOn = function() return false end,
}

C_Spell = {
    GetSpellInfo = function(spell_id)
        return { name = "TestSpell" .. tostring(spell_id), spellID = spell_id, iconID = 134400 }
    end,
    GetSpellTexture = function() return 134400 end,
    GetSpellName = function(spell_id) return "TestSpell" .. tostring(spell_id) end,
    -- reads stub.spell_charges[spell_id] = { currentCharges, maxCharges, cooldownStartTime, cooldownDuration }
    GetSpellCharges = function(spell_id)
        return stub.spell_charges and stub.spell_charges[spell_id] or nil
    end,
}

-- Aura scans read from stub.auras[unit].buffs / .debuffs (arrays of aura-data tables).
stub.auras = {}

local function aura_at(unit, kind, index)
    local unit_auras = stub.auras[unit]
    local list = unit_auras and unit_auras[kind]
    return list and list[index] or nil
end

C_UnitAuras = {
    GetBuffDataByIndex = function(unit, index) return aura_at(unit, "buffs", index) end,
    GetDebuffDataByIndex = function(unit, index) return aura_at(unit, "debuffs", index) end,
    GetAuraDataByIndex = function(unit, index) return aura_at(unit, "buffs", index) end,
    GetAuraDataByAuraInstanceID = function(unit, instance_id)
        local unit_auras = stub.auras[unit]
        for _, kind in ipairs({ "buffs", "debuffs" }) do
            for _, aura in ipairs(unit_auras and unit_auras[kind] or {}) do
                if aura.auraInstanceID == instance_id then return aura end
            end
        end
        return nil
    end,
    GetUnitAuraInstanceIDs = function(unit)
        local ids = {}
        local unit_auras = stub.auras[unit]
        for _, kind in ipairs({ "buffs", "debuffs" }) do
            for _, aura in ipairs(unit_auras and unit_auras[kind] or {}) do
                ids[#ids + 1] = aura.auraInstanceID
            end
        end
        return ids
    end,
    GetAuraDuration = function(unit, instance_id)
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instance_id)
        if not aura or not aura.duration or aura.duration <= 0 then return nil end
        return {
            GetTotalDuration = function() return aura.duration end,
            GetRemainingDuration = function()
                return math.max(0, (aura.expirationTime or 0) - stub.now)
            end,
            IsInfinite = function() return false end,
        }
    end,
    GetAuraApplicationDisplayCount = function(unit, instance_id)
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instance_id)
        return aura and aura.applications or 0
    end,
    DoesAuraHaveExpirationTime = function(unit, instance_id)
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instance_id)
        return (aura and aura.expirationTime or 0) > 0
    end,
    GetPlayerAuraBySpellID = function() return nil end,
}

C_CVar = {
    GetCVar = function(name) return stub.cvars and stub.cvars[name] or nil end,
    SetCVar = function(name, value)
        stub.cvars = stub.cvars or {}
        stub.cvars[name] = tostring(value)
        return true
    end,
    GetCVarBool = function(name)
        local v = stub.cvars and stub.cvars[name]
        return v == "1" or v == "true"
    end,
    GetCVarDefault = function() return "1" end,
}
function GetCVar(name) return C_CVar.GetCVar(name) end
function SetCVar(name, value) return C_CVar.SetCVar(name, value) end
function GetCVarBool(name) return C_CVar.GetCVarBool(name) end

-- Linear-interpolating curve fake matching the C_CurveUtil surface pf_fade uses.
C_CurveUtil = {
    CreateCurve = function()
        local curve = { points = {} }
        function curve:SetType() end
        function curve:ClearPoints() self.points = {} end
        function curve:AddPoint(x, y) self.points[#self.points + 1] = { x = x, y = y } end
        function curve:Evaluate(x)
            local pts = self.points
            if #pts == 0 then return 0 end
            if x <= pts[1].x then return pts[1].y end
            for i = 2, #pts do
                if x <= pts[i].x then
                    local a, b = pts[i - 1], pts[i]
                    if b.x == a.x then return b.y end
                    return a.y + ((b.y - a.y) * ((x - a.x) / (b.x - a.x)))
                end
            end
            return pts[#pts].y
        end
        return curve
    end,
}

Enum = setmetatable({}, {
    __index = function(t, key)
        local e = setmetatable({}, { __index = function() return 0 end })
        rawset(t, key, e)
        return e
    end,
})

stub.player_health_percent = 1

function UnitHealthPercent(_unit, _use_curve, curve)
    local pct = stub.player_health_percent
    if curve and curve.Evaluate then return curve:Evaluate(pct) end
    return pct * 100
end

function UnitHealth() return math.floor(stub.player_health_percent * 100000) end
function UnitHealthMax() return 100000 end
function UnitExists(unit) return unit == "player" end
function UnitIsUnit(a, b) return a == b end
function UnitName() return "TestPlayer" end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitLevel() return 80 end
function UnitIsDeadOrGhost() return false end
function UnitOnTaxi() return false end
function UnitIsPlayer(unit) return unit == "player" end
function UnitGUID() return "Player-0000-00000001" end
function IsMounted() return false end
function IsFlying() return false end
function IsFalling() return false end
function IsIndoors() return false end
function IsResting() return false end
function IsInInstance() return false, "none" end
function GetInstanceInfo() return "TestZone", "none", 0, "", 0, 0, false, 0, 0 end
function GetShapeshiftFormID() return nil end
function PlaySound() end
function PlaySoundFile() end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetPhysicalScreenSize() return 1920, 1080 end
function GetCursorPosition() return 0, 0 end
function GetMouseFoci() return {} end

WOW_PROJECT_ID = 1
WOW_PROJECT_MAINLINE = 1
function securecallfunction(fn, ...) return fn(...) end
function issecrettable() return false end
function issecretvalue() return false end
function MuteSoundFile() end
function UnmuteSoundFile() end
function StopSound() end
-- Unit power reads from stub.power[power_type] = { current = n, max = n };
-- unset power types report 0/0 like a character without that resource.
stub.power = {}
stub.power_display_mod = 1
function UnitPower(_unit, power_type)
    local p = stub.power[power_type]
    return p and p.current or 0
end
function UnitPowerMax(_unit, power_type)
    local p = stub.power[power_type]
    return p and p.max or 0
end
function UnitPowerDisplayMod() return stub.power_display_mod end
function UnitInVehicle() return false end
function UnitInVehicleControlSeat() return false end
function IsAdvancedFlyableArea() return false end

C_Sound = { PlayVocalErrorSound = function() end }
C_Texture = {
    GetAtlasInfo = function(atlas)
        return {
            width = 64, height = 64,
            leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1,
            tilesHorizontally = false, tilesVertically = false,
            file = 123456, filename = tostring(atlas),
        }
    end,
}
C_Item = {}
C_PlayerInfo = { GetGlidingInfo = function() return false, false, 0 end }

--#endregion C_* namespaces and unit API


--#region missing-global tracking

-- Unknown global reads return nil (matching a missing API in-game) but are
-- logged so tests can surface stub gaps. Set stub.strict_missing = true to
-- error instead.
setmetatable(_G, {
    __index = function(_, key)
        if not stub.missing_globals[key] then
            stub.missing_globals[key] = 0
        end
        stub.missing_globals[key] = stub.missing_globals[key] + 1
        if stub.strict_missing then
            error("missing global: " .. tostring(key), 2)
        end
        return nil
    end,
})

--#endregion missing-global tracking

return stub

--#endregion FILE CONTENTS ===================================================
