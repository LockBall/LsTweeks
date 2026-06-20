# Aura Frames Runtime Review

Date: 2026-06-06


## Per-Frame Aura Event Ownership

Aura Frames currently creates one runtime frame per preset/custom aura frame. Each
runtime frame registers aura-related events, and CDM frames additionally register
cooldown update events.

The current maximum normal shape is small:

- 8 preset runtime frames.

- Up to 4 custom runtime frames.

- Disabled frames return from `handle_aura_frame_event()` before aura-info merging,
  dirty/cache work, or deferred callbacks.
- Enabled frames still schedule their own deferred refresh, but the shared scan
  prevents repeated full aura scans in the same dirty batch.


## Decision

Do not centralize aura events into one dispatcher at this time.

Reasoning:

- The measured Aura Frames CPU profile did not show a runtime hotspot that justifies
  an invasive event ownership refactor.
- A central dispatcher would mostly reduce duplicate event callback entry overhead,
  while enabled frames still need their own render/update pass.
- The refactor risk is high because CDM refreshes, custom filters, profile loads,
  combat deferral, and per-frame update params all depend on the current frame-owned
  callback shape.

Revisit only if future profiling captures event-handler overhead as a material cost
or if the runtime frame count increases significantly.
