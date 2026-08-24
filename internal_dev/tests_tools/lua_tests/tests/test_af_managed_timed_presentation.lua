-- Managed Timed Buff native duration-filter regression tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("managed Timed Buffs use Blizzard native permanent-aura exclusion", function()
    local M = fixture.boot_managed_presets()
    local timed_frame = M.frames.show_timed
    local timed_backend = timed_frame and timed_frame._managed_aura_backend

    h.ok(timed_backend, "Timed Buffs frame owns a managed backend")
    h.eq(#timed_frame.icons, 1, "Timed Buffs precreate one addon-owned preview visual")
    h.ok(not timed_frame.icons[1]:IsShown(), "Timed Buff preview visual starts hidden")
    h.eq(timed_frame.__events.UNIT_AURA, nil, "Timed Buffs do not register UNIT_AURA")

    for _, group_key in ipairs({ "timed_buffs:bar", "timed_buffs:icon" }) do
        local group = timed_backend.container.__groups[group_key]
        h.ok(group, "Timed Buffs create managed presentation group " .. group_key)
        h.eq(group.filter_string, "HELPFUL", "Timed Buffs request helpful Auras")
        h.eq(group.options.candidateFilters.maxDuration, math.huge,
            "Timed Buffs delegate permanent-aura exclusion to Blizzard")
    end
    for _, aura_button in ipairs(timed_backend.container.__groups["timed_buffs:bar"].buttons) do
        h.eq(aura_button.__duration_text_region:GetCalls("SetTextColor"), nil,
            "Timed Buff bar duration text inherits the managed timer font color")
    end

    h.eq(M.get_managed_aura_backend("preset:timed"), timed_backend,
        "Timed Buffs register one stable managed backend")
    M.set_managed_aura_runtime_enabled(false)
end)

h.run("af_managed_timed_presentation")

--#endregion FILE CONTENTS ===================================================
