# Changelog
Key changes to L's Tweeks, newest version first.


## 00.23.01 - 2026-10-30
- Added WoW Retail 12.1.5 compatibility metadata (interface 120105), retaining the existing interface declarations.
- Reviewed Blizzard API and UI changes against WoW 12.1.5.70575. No runtime code changes were required by the source review.
- Passed all 27 automated Lua test suites, full LuaLS analysis with refreshed API annotations, and release package verification. In-game acceptance remains pending, especially combat cooldowns, Aura-to-cooldown handoff, and delayed taint errors.
