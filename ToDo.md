## Let's Do It !

### 1. Category Timer Behavior LUT

- [x] a) Centralize per-category timer behavior in a small LUT/helper.
  - Current behavior is split across files: `af_render.lua` decides short-frame decimal formatting, while `af_icon_layout.lua` separately hardcodes static timer suppression. A shared timer behavior helper would keep timer enable/format rules in one place.
  - Examine: `af_functions.lua:206, 213, 218`, `af_render.lua:57, 68`, `af_icon_layout.lua:154, 170, 175`
  - Implemented shape:
    ```lua
    local TIMER_BEHAVIOR = {
        static = { enabled = false, format = "none" },
        short  = { enabled = true,  format = "decimal" },
    }

    local DEFAULT_TIMER_BEHAVIOR = {
        enabled = true,
        format = "time",
    }
    ```
  - Keep a show-key normalization fallback for legacy calls such as `"show_short"`.
  - Keep timer text alignment as layout behavior, not category timer metadata. A layout helper can preserve the current `long = CENTER`, default `RIGHT` behavior now, and later account for frame side, growth direction, bar/icon mode, or a user setting.
  - Value: timer formatting runs on visible timer ticks. This is a moderate hot-path cleanup plus a single-source-of-truth improvement.



### Potential Future Features

- [ ] a) Brief guided tour on first install with an option to manually intiate.
- [ ] b) Portrait dim out of combat.
- [ ] c) Dungeon ready sound levels.
 
