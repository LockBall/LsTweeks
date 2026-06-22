# Aura Frames CDM Mirroring Review

Completed: 2026-06-21

## Summary

Reviewed whether public `C_CooldownViewer` APIs can replace LsTweeks' Blizzard Cooldown Manager viewer child reads and `CooldownViewerItemDataMixin` hooks in `modules/aura_frames/af_scan.lua`.

They cannot. Public APIs expose category cooldown IDs, static cooldown metadata, layout data, availability, and alert types. They do not expose live rendered child order, active aura instance IDs, per-item active state, target/player aura association, or cooldown widget timing.

Retail 12.0.7 source shows live state is held on viewer item frames through methods such as `GetAuraSpellInstanceID()`, `GetCooldownID()`, `GetCooldownInfo()`, and `GetSpellID()`. LsTweeks still needs the live child frame path for active aura display and cooldown fallback behavior.

## Implementation Result

No replacement with `C_CooldownViewer` was made. `af_scan.lua` now prefers Blizzard child mixin methods before fallback field reads:

- `GetAuraSpellInstanceID()`
- `GetCooldownID()`
- `GetCooldownInfo()`
- `GetSpellID()`

`CooldownViewerItemDataMixin` hooks remain necessary to attach cooldown-frame hooks lazily and queue refreshes when Blizzard item identity changes.

## Durable Rule

Do not replace CDM viewer child reads/hooks with public `C_CooldownViewer` APIs unless Blizzard adds APIs for live rendered item state. Prefer child mixin methods over raw fields, and keep addon state in addon-owned weak tables.
