-- Player Frame health diagnostics. This is test-only output for evaluating Retail health APIs.
local _, addon = ...
addon.player_frame = addon.player_frame or { controls = {}, frames = {} }

local M = addon.player_frame
local P = M.health_probe or {}
M.health_probe = P

local function get_defaults()
    return M.FADE_DEFAULTS or {}
end

local function get_clamped_db(db, key, lo, hi)
    local defaults = get_defaults()
    local v = tonumber(db and db[key]) or defaults[key]
    return math.max(lo, math.min(hi, v))
end

local function get_threshold(db)
    return get_clamped_db(db, "health_visible_threshold", 0, 100)
end

local function get_fade_alpha(db)
    return get_clamped_db(db, "fade_alpha", 0.1, 1.0)
end

local function safe_tostring(value)
    if issecretvalue then
        local ok_secret, is_secret = pcall(issecretvalue, value)
        if ok_secret and is_secret then return "<secret>" end
    end

    local ok, result = pcall(tostring, value)
    if ok then return result end
    return "ERR:" .. tostring(result)
end

local function safe_type(value)
    if issecretvalue then
        local ok_secret, is_secret = pcall(issecretvalue, value)
        if ok_secret and is_secret then return "secret" end
    end

    local ok, result = pcall(type, value)
    if ok then return result end
    return "ERR:" .. tostring(result)
end

local function secret_state(value)
    if not issecretvalue then return "n/a" end
    local ok, result = pcall(issecretvalue, value)
    if ok then return tostring(result) end
    return "ERR:" .. tostring(result)
end

local function op(label, fn)
    local ok, result = pcall(fn)
    if ok then return label .. "=" .. safe_tostring(result) end
    return label .. "=ERR:" .. tostring(result)
end

local function append_value_probe(lines, label, call_fn)
    local ok, value = pcall(call_fn)
    if not ok then
        lines[#lines + 1] = label .. ": call=ERR:" .. tostring(value)
        return nil
    end

    local line = label .. ": call=ok"
        .. " | type=" .. safe_type(value)
        .. " | secret=" .. secret_state(value)
        .. " | tostring=" .. safe_tostring(value)
        .. " | " .. op("tonumber", function() return tonumber(value) end)
        .. " | " .. op("cmp_gt0", function() return value > 0 end)
        .. " | " .. op("arith_add0", function() return value + 0 end)
    lines[#lines + 1] = line
    return value
end

local function append_call_probe(lines, label, call_fn)
    local ok, a, b, c = pcall(call_fn)
    if ok then
        lines[#lines + 1] = label .. ": ok | " .. safe_tostring(a) .. " | " .. safe_tostring(b) .. " | " .. safe_tostring(c)
    else
        lines[#lines + 1] = label .. ": ERR:" .. tostring(a)
    end
end

local function create_probe_curve(curve_type, points)
    if not (curve_type and C_CurveUtil and C_CurveUtil.CreateCurve) then return nil end
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(curve_type)
    for _, point in ipairs(points) do
        curve:AddPoint(point[1], point[2])
    end
    return curve
end

local function append_statusbar_probe(lines, label, bar)
    if not bar then
        lines[#lines + 1] = label .. ": missing"
        return
    end
    append_value_probe(lines, label .. ":GetValue", function() return bar:GetValue() end)
    append_call_probe(lines, label .. ":GetMinMaxValues", function() return bar:GetMinMaxValues() end)
end

local function append_playerframe_statusbar_scan(lines)
    if not PlayerFrame then
        lines[#lines + 1] = "PlayerFrame statusbar scan: missing PlayerFrame"
        return
    end

    local seen = 0
    local function scan(frame, depth)
        if seen >= 12 or depth > 5 or not frame then return end

        local ok_type, object_type = pcall(frame.GetObjectType, frame)
        if ok_type and object_type == "StatusBar" then
            seen = seen + 1
            local name = op("name", function() return frame:GetDebugName() end)
            append_statusbar_probe(lines, "scan[" .. seen .. "] " .. name, frame)
        end

        local ok_children, children = pcall(function() return { frame:GetChildren() } end)
        if not ok_children then return end
        for _, child in ipairs(children) do
            scan(child, depth + 1)
            if seen >= 12 then return end
        end
    end

    scan(PlayerFrame, 0)
    if seen == 0 then
        lines[#lines + 1] = "PlayerFrame statusbar scan: none found"
    end
end

local function append_playerframe_health_name_scan(lines)
    if not PlayerFrame then return end

    local seen = 0
    local function scan(frame, depth)
        if seen >= 24 or depth > 6 or not frame then return end

        local name = nil
        local ok_name, debug_name = pcall(frame.GetDebugName, frame)
        if ok_name then name = debug_name end
        if name and string.find(string.lower(name), "health", 1, true) then
            seen = seen + 1
            local ok_type, object_type = pcall(frame.GetObjectType, frame)
            lines[#lines + 1] = "health-name[" .. seen .. "]: " .. name .. " | type=" .. (ok_type and object_type or "ERR")
        end

        local ok_children, children = pcall(function() return { frame:GetChildren() } end)
        if not ok_children then return end
        for _, child in ipairs(children) do
            scan(child, depth + 1)
            if seen >= 24 then return end
        end
    end

    scan(PlayerFrame, 0)
    if seen == 0 then
        lines[#lines + 1] = "PlayerFrame health-name scan: none found"
    end
end

function P.run(db)
    local fade_state, fade_combat = "n/a", "n/a"
    if M.fade and M.fade.get_debug_state then
        fade_state, fade_combat = M.fade.get_debug_state()
    end

    local lines = {
        "=== LsTweeks PlayerFrame Health Probe ===",
        "fade_state=" .. tostring(fade_state)
            .. " | fade_playerInCombat=" .. tostring(fade_combat)
            .. " | " .. op("InCombatLockdown", function() return InCombatLockdown and InCombatLockdown() end)
            .. " | " .. op("UnitAffectingCombat", function() return UnitAffectingCombat and UnitAffectingCombat("player") end),
        "threshold=" .. tostring(get_threshold(db)) .. " | fade_alpha=" .. tostring(get_fade_alpha(db)),
    }

    append_value_probe(lines, "UnitHealth(player)", function() return UnitHealth("player") end)
    append_value_probe(lines, "UnitHealth(player,true)", function() return UnitHealth("player", true) end)
    append_value_probe(lines, "UnitHealthMax(player)", function() return UnitHealthMax("player") end)
    append_value_probe(lines, "UnitHealthPercent(player,true)", function() return UnitHealthPercent("player", true) end)
    append_call_probe(lines, "UnitHealth/Max ratio", function() return UnitHealth("player") / UnitHealthMax("player") end)
    append_call_probe(lines, "UnitHealth < UnitHealthMax", function() return UnitHealth("player") < UnitHealthMax("player") end)

    if CurveConstants and CurveConstants.ScaleTo100 then
        append_value_probe(lines, "UnitHealthPercent ScaleTo100", function()
            return UnitHealthPercent("player", true, CurveConstants.ScaleTo100)
        end)
    else
        lines[#lines + 1] = "CurveConstants.ScaleTo100: missing"
    end

    local threshold = get_threshold(db) / 100
    local step_curve = create_probe_curve(Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step, {
        { 0, 111 },
        { math.max(0, threshold - 0.001), 111 },
        { threshold, 999 },
        { 1, 999 },
    })
    if step_curve then
        append_value_probe(lines, "UnitHealthPercent custom step 111low/999high", function()
            return UnitHealthPercent("player", true, step_curve)
        end)
    else
        lines[#lines + 1] = "custom step curve: unavailable"
    end

    local linear_curve = create_probe_curve(Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear, {
        { 0, 0 },
        { 1, 100 },
    })
    if linear_curve then
        append_value_probe(lines, "UnitHealthPercent custom linear 0-100", function()
            return UnitHealthPercent("player", true, linear_curve)
        end)
    else
        lines[#lines + 1] = "custom linear curve: unavailable"
    end

    append_call_probe(lines, "issecretvalue(UnitHealth)", function() return issecretvalue and issecretvalue(UnitHealth("player")) end)
    append_call_probe(lines, "C_Secrets.ShouldUnitHealthBeSecret", function()
        return C_Secrets and C_Secrets.ShouldUnitHealthBeSecret and C_Secrets.ShouldUnitHealthBeSecret("player")
    end)
    append_call_probe(lines, "C_Secrets.ShouldUnitHealthMaxBeSecret", function()
        return C_Secrets and C_Secrets.ShouldUnitHealthMaxBeSecret and C_Secrets.ShouldUnitHealthMaxBeSecret("player")
    end)
    append_call_probe(lines, "HasSecretValues(PlayerFrame)", function() return HasSecretValues and HasSecretValues(PlayerFrame) end)

    append_call_probe(lines, "UnitExists", function() return UnitExists("player") end)
    append_call_probe(lines, "UnitIsConnected", function() return UnitIsConnected("player") end)
    append_call_probe(lines, "UnitIsDead", function() return UnitIsDead("player") end)
    append_call_probe(lines, "UnitIsGhost", function() return UnitIsGhost("player") end)
    append_call_probe(lines, "UnitIsDeadOrGhost", function() return UnitIsDeadOrGhost("player") end)
    append_call_probe(lines, "UnitIsUnconscious", function() return UnitIsUnconscious and UnitIsUnconscious("player") end)
    append_call_probe(lines, "UnitIsFeignDeath", function() return UnitIsFeignDeath and UnitIsFeignDeath("player") end)

    append_statusbar_probe(lines, "PlayerFrame.healthbar", PlayerFrame and PlayerFrame.healthbar)
    append_statusbar_probe(lines, "PlayerFrame.HealthBar", PlayerFrame and PlayerFrame.HealthBar)
    append_statusbar_probe(lines, "PFContentMain.HealthBar", PlayerFrame
        and PlayerFrame.PlayerFrameContent
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBar)
    append_statusbar_probe(lines, "PFContentMain.HealthBarArea", PlayerFrame
        and PlayerFrame.PlayerFrameContent
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarArea)
    append_playerframe_statusbar_scan(lines)
    append_playerframe_health_name_scan(lines)

    lines[#lines + 1] = "=== End Health Probe ==="
    for _, line in ipairs(lines) do
        print("|cff33ff99LsTweeks Probe:|r " .. line)
    end
end
