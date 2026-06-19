# Core, Settings, And Shared UI Review - 2026 Jun

Rating format: `Priority` is review order, `Impact` is expected addon/user impact if the issue is real, and `Change Risk` is the risk of making changes in that area.

1. Priority: High | Impact: Medium | Change Risk: Low - Add an in-game validation surface for module runtime state before relying on module-toggle testing. A lightweight diagnostic such as `/lst status` or a debug-only status panel should report each module's enabled flag plus observable runtime facts, for example registered events/tickers/frame visibility where applicable.

2. Priority: High | Impact: High | Change Risk: High - Revisit disabled-module architecture. User expectation is that a disabled module consumes effectively zero runtime resources and exposes no settings interface beyond a greyed module button. Current modules are soft-disabled after their Lua files load; a stronger design needs a lightweight core module manifest plus lazy construction, and possibly LoadOnDemand child addons if memory footprint must be minimized before a module is enabled.

3. Priority: Medium | Impact: Medium | Change Risk: Medium - Module enable toggles call each module's `set_module_enabled()`, and disabled module pages remain visible but unselectable. This matches project memory; test toggling each module without reload after there is a visible status/debug path to verify runtime shutdown.

4. Priority: Medium | Impact: Medium | Change Risk: Low - `CreateModuleReset()` blocks reset during combat and calls module-owned `after_reset` hooks. Continue using it for module resets; avoid cross-module reset side effects.

5. Priority: Low | Impact: Medium | Change Risk: Low - `CreateSliderWithBox()` now runs reset callbacks even when the slider value already equals default. Keep that behavior for layout-affecting sliders.
