1. Priority: High | Impact: Medium | Change Risk: Low - Add an in-game validation surface for module runtime state before relying on module-toggle testing. A lightweight diagnostic such as `/lst status` or a debug-only status panel should report each module's enabled flag plus observable runtime facts, for example registered events, tickers, and frame visibility where applicable.

2. Priority: High | Impact: High | Change Risk: High - After a runtime status surface exists, evaluate whether disabled modules should move beyond soft-disable gates. Compare current shutdown behavior against a lightweight core module manifest, lazy construction, or LoadOnDemand child addons if memory footprint must be minimized before a module is enabled.

3. Priority: Medium | Impact: Medium | Change Risk: Medium - After a runtime status surface exists, test toggling each module without reload and verify each module's `set_module_enabled()` path stops owned runtime work.
