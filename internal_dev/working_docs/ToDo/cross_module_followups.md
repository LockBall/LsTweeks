# Cross-Module Followups
Unresolved addon-wide checks discovered while closing module review findings. Add an item here when a resolved finding's cause or fix pattern can recur outside its module; remove items once verified or promoted to a durable rule in `project.md`.


## Open Items
### CHAT-01 — Formatted chat export module
- **Goal:** Build an LsTweeks chat copy/export module with a distinct user-facing name instead of depending on the current third-party chat copy/paste addon.
- **UX:** Preserve intentional line breaks, offer readable formatting controls, and expose selected output through an addon-owned text box for manual Ctrl+C.
- **Safety boundary:** Never call restricted `CopyToClipboard` from addon code; Retail blocks it as a Blizzard-UI-only action.
- **Current decision:** Deferred. Continue using the existing chat copy/paste addon and tolerate its formatting limitations until this module is intentionally designed and authorized.
