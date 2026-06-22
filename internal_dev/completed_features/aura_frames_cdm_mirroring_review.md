# Aura Frames CDM Mirroring Review

Completed: 2026-06-21


## Summary

Reviewed whether public `C_CooldownViewer` APIs can replace LsTweeks' Blizzard Cooldown Manager viewer child reads or `CooldownViewerItemDataMixin` hooks in `modules/aura_frames/af_scan.lua`.

They cannot fully replace the current runtime path. Ketho annotations for `C_CooldownViewer` expose:

- `GetCooldownViewerCategorySet(category, allowUnlearned)`

- `GetCooldownViewerCooldownInfo(cooldownID)`

- `GetLayoutData()` / `SetLayoutData(data)`

- `GetValidAlertTypes(cooldownID)`

- `IsCooldownViewerAvailable()`

The returned `CooldownViewerCooldown` metadata includes cooldown ID, spell IDs, flags, known state, and category. It does not expose the live rendered viewer child order, active aura instance IDs, per-item active state, target/player aura association chosen by Blizzard, or cooldown widget timing/duration objects.

Retail 12.0.7 `CooldownViewerItemDataMixin` and `CooldownViewerMixin` source show that live active aura state is maintained on item frames through methods like `GetAuraSpellInstanceID()`, `GetCooldownID()`, `GetCooldownInfo()`, and `GetSpellID()`, with viewer refresh/event logic updating item frames directly. LsTweeks still needs to mirror those live child frames for active aura display and cooldown fallback behavior.


## Implementation Result

No replacement with `C_CooldownViewer` was made. `af_scan.lua` now prefers Blizzard child mixin methods before fallback field reads:

- `GetAuraSpellInstanceID()` before `child.auraInstanceID`

- `GetCooldownID()` before `child.cooldownID`

- `GetCooldownInfo()` before `child.cooldownInfo`

- `GetSpellID()` before reading spell IDs from cooldown info

The `CooldownViewerItemDataMixin` hooks remain necessary to attach cooldown-frame hooks lazily and to queue refreshes when Blizzard item identity changes.


## Validation

- Shell: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File internal_dev/tests_tools/check_fast.ps1` passed Lua syntax and whitespace checks on 2026-06-21.


## Durable Rule

Do not replace CDM viewer child reads/hooks with public `C_CooldownViewer` APIs unless Blizzard adds APIs that expose live rendered item state: active aura instance IDs, rendered order, per-item active state, and cooldown widget timing. Prefer child mixin methods over raw fields where they exist, and keep addon state in addon-owned weak tables.
