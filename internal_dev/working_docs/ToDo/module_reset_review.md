# Module Reset Review
Focused follow-up for reset behavior across modules that use `addon.CreateModuleReset()`.


## Table of Contents
- [Scope](#scope)
- [Review Items](#review-items)


## Scope
- Check modules with ARM reset panels: Settings, Audio Volumes, Skyriding Vigor, and Aura Frames.
- Objectives intentionally has no module reset panel.
- Look for stale GUI closures bound to pre-reset DB subtables, session-only flags that survive reset, runtime state that keeps running after defaults restore, and `after_reset` hooks that can leave runtime/controls stale.


## Review Items
1. Audio Volumes reset binding audit: existing `audio_volumes_review.md` Potential Bug 1 says reset replaces nested DB subtables while GUI closures keep writing old subtables. Verify and fix before treating Audio Volumes reset as reliable.
2. Skyriding Vigor reset state audit: existing `skyriding_vigor_review.md` Potential Bug 2 and Latent Trap 5 say Fill Test / Race Test flags can survive reset and the second flight-lock guard can desync runtime after DB reset. Verify and fix together.
3. Aura Frames reset audit: confirm current reset flow removes orphan custom frames, relinks custom entries, rebuilds frame settings/tree state, stops stale tickers/timers, and preserves profile options exactly as intended.
4. Settings reset audit: confirm general settings reset resyncs live UI state without stale control bindings.
