# Aura Frames CPU Profiles

Long-term capture for Aura Frames in-game profiling runs. Use
`internal_dev/tests_tools/aura_frames_duration_profile.lua` when collecting comparable
data.

## Current Decision

`C_UnitAuras.GetAuraDuration` is not a meaningful hotspot based on the collected
2026-06-06 data. Keep the defensive `GetAuraDuration` guards in `af_core.lua`,
`af_render.lua`, and `af_scan.lua`; do not restructure duration handling for CPU
reasons unless future profiling shows a material regression.

The safe ticker improvement remains: visible-icon updates reuse live
DurationObjects resolved during render before falling back to another
`GetAuraDuration` lookup.

## How To Collect

1. Temporarily load `internal_dev/tests_tools/aura_frames_duration_profile.lua` after
   `modules/aura_frames/af_main.lua` in `LsTweeks.toc`.
2. `/reload`.
3. Run `/lstafprofile start`.
4. Exercise normal aura/CDM gameplay for 1-3 minutes.
5. Run `/lstafprofile report`, copy the output here, then run `/lstafprofile stop`.
6. Remove the temporary TOC line and `/reload`.

## Runs

### 2026-06-06

Context: 77.6s normal Aura Frames and CDM use.

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `C_UnitAuras.GetAuraDuration` | 2673 | 10.330 | 0.0039 | 0.142 |
| `C_UnitAuras.GetUnitAuraInstanceIDs` | 311 | 6.750 | 0.0217 | 0.145 |
| `tick_visible_icons` | 722 | 116.671 | 0.1616 | 0.519 |
| `render_aura_map` | 1325 | 167.696 | 0.1266 | 0.768 |
| `unified_scan` | 109 | 72.540 | 0.6655 | 1.857 |
| `scan_custom_aura_map` | 101 | 6.667 | 0.0660 | 0.215 |
| `add_cooldown_viewer_category_entries` | 820 | 50.482 | 0.0616 | 0.387 |

Conclusion: `C_UnitAuras.GetAuraDuration` was not a meaningful hotspot in this
run. Keep the defensive guards and do not restructure duration handling for CPU
reasons based on this data.

