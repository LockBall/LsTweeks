# Scratchpad

## aura_frames LUT Candidates (reviewed 2026-05-10)

- [ ] 1) Move CDM-specific GUI capabilities into frame metadata if CDM options expand.
  - Valid maintainability candidate, but not a meaningful performance win.
  - `af_gui_frame_builders.lua` still special-cases which CDM categories expose Cooldown Mode.
  - Suggested shape: add something like `supports_cooldown_mode = true` to `M.FRAME_DEFS` only if more per-frame CDM capability rules are added.
