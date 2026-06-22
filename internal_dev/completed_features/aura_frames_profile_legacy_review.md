# Aura Frames Profile Legacy Review

Completed: 2026-06-21

## Summary

The remaining Aura Frames review item asked for testing profile load/reset behavior against saved profiles containing deleted or renamed custom frames.

Closed as not applicable for current project scope. The addon has a single user/developer workflow and there is no legacy saved-profile corpus to validate against. Do not block Aura Frames cleanup on hypothetical profile migration cases unless real saved variables are found or profile storage is intentionally changed.

## Durable Rule

The existing implementation rule remains valid: if reset or profile load replaces `custom_frames`, remove orphan runtime frames and stale controls, then rebuild the Frames tree/content if present. Future changes to profile storage should test that path with synthetic profiles created for the change.
