-- ChatCopySghetti: readable retained-history collection with native chat colors.
local _, addon = ...
local M = addon.chat_copy_sghetti
local issecretvalue = issecretvalue
local StripHyperlinks = C_StringUtil.StripHyperlinks
local GenerateTextColorCode = C_ColorUtil.GenerateTextColorCode
local WrapTextInColorCode = C_ColorUtil.WrapTextInColorCode
local floor, min, max = math.floor, math.min, math.max
local concat = table.concat

--#region EXPORT SNAPSHOTS ====================================================
function M.normalize_text(text, keep_brackets)
    -- Reject secrets before type checks, string operations, or native formatting.
    if issecretvalue(text) or type(text) ~= "string" then return nil end
    -- Private-name escape payloads are not plain export text; never reconstruct them.
    if text:find("|K", 1, true) then return nil end
    local stripped = StripHyperlinks(text, true, keep_brackets, false, false, false)
    if issecretvalue(stripped) then return nil end
    -- Preserve intentional breaks; display wrapping is never used as input.
    return (stripped:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("|n", "\n"))
end

local function apply_message_color(text, r, g, b)
    -- RGB metadata is external and can be unavailable independently of the text.
    if issecretvalue(r) or issecretvalue(g) or issecretvalue(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return text
    end
    local code = GenerateTextColorCode({ r = max(0, min(1, r)), g = max(0, min(1, g)), b = max(0, min(1, b)) })
    -- Inline link/name colors end at their reset; resume the chat message's color.
    local body = text:gsub("|r", "|r|c" .. code)
    return WrapTextInColorCode(body, code)
end

function M.collect_snapshot(frame, options)
    local limit = max(M.MESSAGE_RANGE.min, min(M.MESSAGE_RANGE.max, floor(options.max_messages)))
    local count = frame:GetNumMessages()
    if issecretvalue(count) or type(count) ~= "number" then
        return "", { exported = 0, skipped = 0, unavailable = true }
    end
    local lines, bytes = {}, 0
    local report = { exported = 0, skipped = 0, unavailable = false }
    -- Traverse newest first so the output-size bound retains the most recent data.
    for index = count, max(1, count - limit + 1), -1 do
        local message, r, g, b = frame:GetMessageInfo(index)
        local text = M.normalize_text(message, options.keep_brackets)
        if text then
            text = apply_message_color(text, r, g, b)
            local addition = #text + (#lines > 0 and 1 or 0)
            if bytes + addition > M.MAX_EXPORT_BYTES then
                break -- Never split UTF-8, escape sequences, or an individual message.
            end
            lines[#lines + 1] = text
            bytes = bytes + addition
        end
    end
    local ordered = {}
    for index = #lines, 1, -1 do ordered[#ordered + 1] = lines[index] end
    report.exported = #ordered
    report.skipped = count - report.exported
    return concat(ordered, "\n"), report
end
--#endregion EXPORT SNAPSHOTS =================================================
