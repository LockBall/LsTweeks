# aura_frames module review — active follow-up, 2026-06-04

This temporary review file tracks only remaining aura_frames review items.

## 1. Higher-Risk Runtime Work

### 1.1 Per-frame aura event ownership
Every runtime aura frame still registers the same events in `af_main.lua`. The shared
scan prevents N full scans. Disabled frames now return from `handle_aura_frame_event()`
before aura-info merging, dirty/cache work, or deferred callbacks, but enabled frames
still use per-frame handlers.

Best options:
- Larger step: centralize aura events on one dispatcher frame and update only enabled
  runtime-active frames.

Risk: CDM refreshes, custom filters, profile loads, and combat deferral all rely on the
current per-frame update params.

### 1.2 Aura duration CPU profiling
Completed safe ticker improvement: visible-icon updates now reuse the live
DurationObject resolved during render before falling back to another
`C_UnitAuras.GetAuraDuration` lookup.

Deferred: `af_core.lua`, `af_render.lua`, and `af_scan.lua` still defensively wrap
`GetAuraDuration` calls. Keep those guards unless objective CPU profiling shows this
is still a meaningful hotspot and in-game testing confirms the API does not throw in
combat/secret-value cases.

TODO: run a more objective CPU usage profile for Aura Frames before removing more
defensive API guards or restructuring runtime aura events.
