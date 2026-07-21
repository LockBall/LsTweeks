# Native Tooltip Delegate Review
Final follow-up plan for commit 6fd4aab (rich Aura tooltips through shared native `GameTooltip` delegates in `functions/tooltip.lua`). The architecture is confirmed correct; preserve it unchanged while hardening tooltip ownership.

Hard boundary: do not reintroduce an addon-created `GameTooltip`, `GameTooltipTemplate`, `securecallfunction`, rendered-line inspection, or `NumLines` checks. Restricted Aura data continues through the shared native delegate; guarded cached/plain lines remain fallback-only.

Status 2026-07-20: implementation and automated validation are complete. Steps 1-5 passed; only the in-game session countdown and final closeout remain.


## Final Plan
1. **Completed: make the tooltip stub ownership-aware.** `SetOwner` now stores ownership, `GetOwner` returns it, and `IsOwned(owner)` compares it. Existing focused suites remained green after the stub-only change.
2. **Completed: add the ownership-transfer regression.** The real Aura callbacks now prove both cases: the current Aura owner hides normally, while frame A's stale `OnLeave` does not hide a tooltip transferred to frame B. The transfer case failed against 6fd4aab before the runtime fix.
3. **Completed: replace the boolean with explicit ownership.** `functions/tooltip.lua` now stores `native_tooltip_owner`, hides only when caller/stored/current owners match, clears stale ownership without hiding a replacement tooltip, and adds no global tooltip hook.
4. **Completed: thread the owner through Aura Frames.** The disabled-tooltip branch passes `obj`; icon `OnLeave` accepts and passes `self`. Scanning, rendering, combat behavior, delegates, and fallbacks are unchanged.
5. **Completed: run automated validation.** All 13 headless suites pass, including 28/28 Aura tests and 5/5 tooltip tests. LuaLS/Ketho reports no findings; fast, syntax, region, memory, whitespace, line-ending, and `git diff --check` validation pass.
6. **Continue the in-game regression smoke check.** For three clean sessions total, hover rich short buffs and debuffs outside and during combat, then hover delve entrances, world quests, and other map POIs with widget content. Cover at least one `/reload` and one fresh login across those sessions. The 2026-07-19 validation counts as session 1 of 3; record the remaining two results here. If a secret-value widget error recurs, compare its taint source and reproduction sequence with 6fd4aab first rather than assuming every Blizzard tooltip failure shares this cause.
   - Session 1: passed 2026-07-19.
   - Session 2: passed 2026-07-20 after `/reload`.
   - Session 3: passed 2026-07-20 after a fresh login.
7. **Close the temporary review after the exit criteria.** Once the ownership fix is committed and all three in-game sessions are clean, delete this ToDo note. The durable architecture rule and Aura→map POI release-smoke sequence already live in `project.md` and `modules/aura_frames.md`; do not duplicate the completed work elsewhere.

Optional diagnostics are explicitly out of scope for this plan. If silent native-delegate failures later become a real debugging problem, add only a debug-gated, rate-limited failure counter or guarded status field; do not print/stringify raw error payloads without first proving they are non-secret.
