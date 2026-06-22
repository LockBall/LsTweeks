# Aura Frames Runtime Review

Completed: 2026-06-06

## Decision

Do not centralize Aura Frames event handling into one dispatcher at this time.

## Reasoning

Aura Frames creates one runtime frame per preset/custom frame. The normal upper bound is small: 8 preset frames plus up to 4 custom frames. CDM frames add cooldown update events.

Disabled frames return from `handle_aura_frame_event()` before aura-info merging, dirty/cache work, or deferred callbacks. Enabled frames still need their own render/update pass, and the shared scan prevents repeated full aura scans in the same dirty batch.

The measured CPU profile did not show event-handler overhead as a hotspot. A central dispatcher would be invasive because CDM refreshes, custom filters, profile loads, combat deferral, and per-frame update params all depend on the current frame-owned callback shape.

## Revisit Only If

- Future profiling shows event-handler overhead is material.
- Runtime frame count increases significantly.
