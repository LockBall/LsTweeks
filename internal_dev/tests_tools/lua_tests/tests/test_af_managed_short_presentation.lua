-- Managed Short Buff native duration-filter and expiration-sort regression tests.
-- Runs under desktop Lua 5.1 against the wow_stub environment.
---@diagnostic disable: undefined-global


--#region FILE CONTENTS ======================================================

package.path = arg[0]:gsub("[\\/][^\\/]+$", "") .. "/../?.lua;" .. package.path
local fixture = require("af_managed_fixture")
local h = fixture.h

h.test("managed Short Buffs use native maximum duration and expiration ordering", function()
    local M = fixture.boot_managed_presets()
    local short_frame = M.frames.show_short
    local short_backend = short_frame and short_frame._managed_aura_backend

    h.ok(short_backend, "Short Buffs frame owns a managed backend")
    h.eq(short_frame.icons, nil, "Short Buffs create no legacy icon pool")
    h.eq(short_frame.__events.UNIT_AURA, nil, "Short Buffs do not register UNIT_AURA")

    for _, group_key in ipairs({ "short_buffs:bar", "short_buffs:icon" }) do
        local group = short_backend.container.__groups[group_key]
        h.ok(group, "Short Buffs create managed presentation group " .. group_key)
        h.eq(group.filter_string, "HELPFUL", "Short Buffs request helpful Auras")
        h.eq(group.options.candidateFilters.maxDuration, 300,
            "Short Buffs default to a five-minute maximum duration")
        h.eq(group.options.sortMethod, AuraContainerSortMethod.ExpirationOnly,
            "Short Buffs sort only by expiration")
        h.eq(group.options.sortDirection, AuraContainerSortDirection.Normal,
            "Short Buffs put the next expiration first")
    end
    h.ok(short_frame.move_handle.body:find("300 seconds", 1, true),
        "Short Buff mover tooltip reports its configured duration")

    M.db.short_threshold = 120
    M.update_auras(short_frame, "show_short", "move_short", "timer_short",
        "bg_short", "scale_short", "spacing_short", "HELPFUL")
    for _, group_key in ipairs({ "short_buffs:bar", "short_buffs:icon" }) do
        h.eq(short_backend.container.__groups[group_key].options.candidateFilters.maxDuration, 120,
            "Short Buff duration changes refresh native candidate filters")
    end
    h.ok(short_frame.move_handle.body:find("120 seconds", 1, true),
        "Short Buff mover tooltip follows duration changes")

    h.eq(M.get_managed_aura_backend("preset:short"), short_backend,
        "Short Buffs register one stable managed backend")
    M.set_managed_aura_runtime_enabled(false)
end)

h.run("af_managed_short_presentation")

--#endregion FILE CONTENTS ===================================================
