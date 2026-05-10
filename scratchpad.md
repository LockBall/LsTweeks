# Scratchpad

CDM frames initial default position should check for the main gui location and appear outside the right border edge with a 32 pixel gap  

## LUT Candidates in aura_frames Module (2026-05-10)

- [ ] a) Add keyed lookup tables for timer font and custom AuraFilter modifier definitions.
  - Best low-risk runtime/clarity candidate. `af_main.lua` currently scans `M.NUMBER_FONT_OPTIONS` in `get_number_font_def()`, and `af_functions.lua` scans `M.CUSTOM_AURA_MODIFIERS` in `M.get_custom_modifier_def()`. Build `M.NUMBER_FONT_OPTIONS_BY_KEY` and `M.CUSTOM_AURA_MODIFIERS_BY_VALUE` when the source arrays are defined, keeping the arrays for dropdown order.

  - Examine: `af_main.lua:55 , 76`, `af_functions.lua:312`, `af_defaults.lua:160`



- [ ] d) Move CDM-specific GUI capabilities into frame metadata.
  - Maintainability candidate, not a meaningful performance win. `af_gui_frame_builders.lua` already uses a label LUT for CDM hide labels, but still special-cases `essential` and `utility` for Cooldown Mode. Add a `supports_cooldown_mode` or similar field to `M.FRAME_DEFS` if more CDM category capabilities are added.

  - Examine: `af_gui_frame_builders.lua:702, 738`, `af_defaults.lua:12, 107`


- [ ] e) Leave scan classification threshold logic as explicit conditionals.
  - Not a good LUT candidate. `af_scan.lua` classifies static/short/long/debuff from live timing, secret-field fallback, and replacement hints; converting that to a table would hide decision flow without removing meaningful work.

  - Examine: `af_scan.lua:150, 593, 645, 703`

#### 4. **Category → Default Position Table** `af_defaults.lua` (lines 400+)
**Current Pattern:** Individual `growth_static = "RIGHT"`, `growth_short = "DOWN"`, etc. entries.  
**LUT Benefit:** Consolidate into a keyed table indexed by category.
```lua
M.DEFAULT_GROWTH = {
    static = "RIGHT",
    short = "DOWN",
    long = "RIGHT",
    essential = "RIGHT",
    utility = "RIGHT",
    tracked_buffs = "RIGHT",
    tracked_bars = "DOWN",
    debuff = "UP",
}
```
**Impact:** Improves readability; avoids parallel lists drifting. Currently already well-structured via M.FRAME_DEFS, but hardcoded growth defaults could move into that table.

#### 5. **Category → Timer Text Alignment** `af_icon_layout.lua:139-140`
**Current Pattern:** `local timer_text_align = (category == "long") and "CENTER" or "RIGHT"`  
**LUT Benefit:** Replace ternary with lookup.
```lua
local TIMER_TEXT_ALIGN = {
    long = "CENTER",
    static = false, -- disabled
    ["default"] = "RIGHT",
}
```
**Impact:** Called once per setup_layout() call, but clearer intent.

### Lower Priority (Nice-to-Have)

#### 6. **Point String → Positional Check** `af_icon_layout.lua:99-101`
**Current Pattern:** `string.find(point, "TOP")` and `string.find(point, "BOTTOM")` patterns.  
**Alternative:** Precomputed point type classification via LUT.
```lua
local POINT_CARDINAL_FLAGS = {
    TOPLEFT = { top = true, left = true },
    TOPRIGHT = { top = true, right = true },
    BOTTOMLEFT = { bottom = true, left = true },
    BOTTOMRIGHT = { bottom = true, right = true },
    -- ... etc
}
```
**Impact:** Called once per set_height_for_growth() but string searching is already fast.

---

### Summary
**Quick Win:** Merge items #1 and #2 into af_icon_layout.lua. Replace the 4-branch growth checks in setup_layout() icon-mode loop with table lookups. Will reduce cognitive load and make it clearer what each growth mode does.  
**Next:** Item #3 (category → timer format) in af_render.lua — called frequently on ticks.  
**Refactor:** Item #4 — lift growth defaults into M.FRAME_DEFS to keep them alongside category metadata.

---

## Example: Replacing Nested `if` / `elseif` With a Lookup Table to improve performance

### Before

```lua
local function get_frame_label(category)
    if category == "static" then
        return "Static"
    elseif category == "short" then
        return "Short"
    elseif category == "long" then
        return "Long"
    elseif category == "debuff" then
        return "Debuffs"
    else
        return "Unknown"
    end
end
```

### After

```lua
local FRAME_LABELS = {
    static = "Static",
    short = "Short",
    long = "Long",
    debuff = "Debuffs",
}

local function get_frame_label(category)
    return FRAME_LABELS[category] or "Unknown"
end
```

The lookup table keeps the data in one obvious place. The function only owns the decision flow: read the mapped value, then fall back if the key is not known.
