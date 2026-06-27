# Aura Frames Performance Review

## Open Follow-Ups

1. [ ] Review whether `update_auras()` can skip stable work per frame. Use focused
Aura CPU profiles, not broad addon runs, before making changes.

2. [ ] Review whether `render_aura_map()` can avoid redundant visual setters.
Apply the addon-wide hot-path lesson: move stable setup out of high-frequency
paths only after identifying the invalidation boundary.

3. [ ] Review custom scan reuse or CDM/custom routing before revisiting preset
bucket copying. Focused profiling showed preset bucket copying was below the
report cutoff; scan/map cost was dominated by `unified_scan`,
`add_cooldown_viewer_category_entries`, and `scan_custom_aura_map`.

## Notes

- Do not use `addon_cpu_profiles.md` for helper-level Aura decisions. Broad runs
choose the module target; `af_cpu_profiles.md` captures detailed Aura timings.

- Avoid central dispatcher or invasive CDM rewrites unless a focused profile shows
a material regression or a concrete behavior issue gives a narrower target.
