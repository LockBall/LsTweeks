# Core Settings Module Status Diagnostic
Completed: 2026-06-21


## Table of Contents
- [Summary](#summary)
- [Verified Disabled State](#verified-disabled-state)
- [Boundary Policy](#boundary-policy)


## Summary
`/lst status` was added as the in-game diagnostic for feature-module soft-disable behavior. It reports every `addon.FEATURE_MODULES` entry with the saved enabled flag plus module-owned runtime signals.

Use this command before reopening module-disable architecture questions. The current design is intentionally a soft-disable boundary: addon files remain loaded, but module-owned events, timers, tickers, preview handles, forced-hidden Blizzard frames, and visible module frames should stop when a module is disabled.


## Verified Disabled State
User in-game test after disabling all modules reported:

- Player Frame: `enabled=false`, `fade_events=false`, no fade timer/ticker/queued health timer, `hide_portrait_text=false`.
- Buffs & Debuffs: `enabled=false`, `runtime=false`, `shown=0`, `event_scripts=0`, `visible_icon_ticker=false`, `scan_pending=0`, `hover_tickers=0`, `cdm_forced_hidden=0`.
- Sound Levels: `enabled=false`, `registered_events=0`, `event_cache=0`, no preview handles/timers, no Fishing Focus active state/events.
- Skyriding Vigor: `enabled=false`, `runtime_events=false`, `frame_shown=false`, no progress `OnUpdate`, no fill test, no active progress slot.

Player Frame `loader_event_script=true` is expected. The bootstrap/dispatcher frame keeps its `OnEvent` script, but its runtime fade events are unregistered when disabled.


## Boundary Policy
Reopen lazy construction or LoadOnDemand child addon architecture only with an
explicit memory-footprint target in the review folder. The disabled-runtime
state is clean for current behavior.
