# Aura Frames 12.1 Feature Assessment Reference
Archived feature-level assessment for the Retail 12.1 managed-Aura migration. The
migration closeout completed on 2026-09-01; current runtime contracts live in
`internal_dev/working_docs/proj_mem/modules/aura_frames.md`, and intentionally
deferred design work lives in `internal_dev/working_docs/ToDo/aura_frames_deferred_features.md`.
The numbered sections below retain the original assessment context and are not
the current implementation status.

## Table of Contents
- [Purpose](#purpose)
- [Confirmed platform change](#confirmed-platform-change)
- [Scope conclusion](#scope-conclusion)
- [Closure summary](#closure-summary)
- [Numbered feature assessment](#numbered-feature-assessment)
- [Archival disposition](#archival-disposition)


## Purpose

Track the feature-level impact of World of Warcraft 12.1's Aura API restrictions
and provide stable item numbers for design, implementation, and in-game review.

This is an assessment, not an implementation plan. Each item should be resolved
deliberately before its status is changed.

## Confirmed platform change

While Auras are secret:

- Aura queries by index, slot, or Aura instance ID can Lua error when called by
  addons.
- The `UNIT_AURA` update payload is fully secret.
- `AuraData` structures cannot be inspected safely by addon code.
- Addons are expected to display protected Auras through managed
  `AuraContainer` and `AuraButton` objects. The container owns Aura discovery,
  filtering, sorting, assignment, and visibility; addon code controls only the
  supported presentation bindings.
- Managed AuraButtons can become forbidden. Their complete widget tree and
  presentation bindings must therefore be established in `initializeFrame`.
  Addon scripts cannot depend on later AuraButton visibility, focus, hover, or
  Aura identity inspection.

Primary references:

- Blizzard announcement:
  https://us.forums.blizzard.com/en/wow/t/addons-and-auras-in-curse-of-ula%E2%80%99tek/2317456
- Patch 12.1 API change record:
  https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes

Local community implementations inspected:

- TellMeWhen:
  `../TellMeWhen/Components/IconModules/IconModule_AuraContainer/AuraContainer.lua`
- TellMeWhen managed filter construction:
  `../TellMeWhen/Components/IconTypes/IconType_buffcontainer/buffcontainer.lua`
- ArcUI:
  `../ArcUI/CDM_Module/Arc_Auras/ArcUI_ArcAurasAuraIcons.lua`
  and `../ArcUI/CDM_Module/Arc_Auras/ArcUI_ArcAurasAuraGroups.lua`

Both addons use the same general pattern: create managed containers, completely
build and style each AuraButton during `initializeFrame`, bind native icon,
duration, stack, bar, and tooltip behavior, and do not inspect protected Aura
data afterward.

License and implementation boundary:

- TellMeWhen is GPLv3. It may be studied as a working public example, but no
  TellMeWhen code may be copied or adapted into the MIT-licensed LsTweeks code.
- The installed ArcUI distribution contains both a BSD-3-Clause `LICENSE` and a
  restrictive `LICENSE.txt` that permits study but requires prior permission to
  use portions. Treat the stricter terms as controlling: study behavior only and
  copy no ArcUI code.
- LsTweeks must derive its implementation independently from Blizzard's public
  API contract. Community addons are evidence that a supported API path works,
  not code sources or dependencies.

## Scope conclusion

The confirmed blast radius is concentrated in Aura Frames. Repository searches
found no use by other LsTweeks modules of the newly restricted indexed Aura
queries or the other specifically removed 12.1 APIs reviewed during this
assessment. Other modules still require normal regression testing after a game
patch, but there is currently no evidence that this Aura change requires their
redesign.


## Closure summary
- **Managed presets:** Short Buffs, Static / Long Buffs, Timed Buffs, and Debuffs passed Bar/Icon, combat, fade, tooltip, scale, background, shared-color, and profile acceptance.
- **Cooldown Manager:** Essential and Utility passed Aura/Cooldown Mode handoff, category moves, ordering, reload-in-combat, tooltips, and native-viewer suppression checks. Tracked Buffs and Tracked Bars passed their Aura-mode lifecycle checks.
- **Presentation:** native duration swipes, timer/stack/bar styling, empty and populated Frame BG geometry, Move Mode, resizing, and addon-owned Test Aura previews passed live acceptance.
- **Performance:** the accepted mode-aware CDM event predicate reduced `update_auras` from `10.56` to `6.30 calls/sec` and from `9.245` to `6.723ms/sec` combat-normalized. Broader record caching was rejected as unwarranted at the measured cost.
- **Validation:** the closeout passed all 27 headless suites available at the time, focused live matrices, Lua/static checks, region checks, whitespace checks, and line-ending checks.
- **Deferred by design:** AF12-06 custom-filter mapping, AF12-09 native timer formatters, and AF12-11 supported native sort mapping remain in `aura_frames_deferred_features.md`; they are not migration blockers.


## Numbered feature assessment

### AF12-01 — Preset live Aura frames

**Features:** Short Buffs, Static / Long Buffs, Timed Buffs, and Debuffs.

**Assessment:** Complete. All surviving preset frames use managed AuraContainers.
The obsolete Static and Long presets, shared live scanner, category buckets, and
threshold-transfer preview path were removed after Static / Long Buffs passed
in-game combat checks.

**Result:** Every managed preset passed combat acceptance. Static / Long learning
remains OOC-only; combat display stays entirely within Blizzard's managed
container.

### AF12-02 — Short frame threshold semantics

**Assessment:** Implemented with intentionally revised semantics.

The removed addon scanner classified an Aura as Short using its *remaining*
time and transferred Long Auras when their countdown crossed the threshold.
The managed replacement intentionally uses WoW's `maxDuration`, which measures
the Aura's total or maximum duration.

**Status:** Short Buffs uses managed `HELPFUL` groups with native
`candidateFilters.maxDuration = short_threshold`. The default is 300 seconds,
the setting lives in the Short Buffs panel, and its mover tooltip reports the
configured maximum. Both Bar and Icon groups use native `ExpirationOnly` normal
ordering so the next expiration appears first. There is deliberately no
Long-to-Short transfer and no migration handling; module reset is the clean
development recovery path.

### AF12-03 — Long frame filtering

**Assessment:** Implemented through learned native inclusion because no
documented managed `minDuration` filter exists.

While out of combat, `af_learned_buffs.lua` records the latest readable total
duration for each active helpful spell. Durations above `short_threshold` feed
the Static / Long Buffs native `includeSpellIDs` map; later readable Short
observations reclassify the spell. Unknown spells remain hidden until learned.

**Direction:** Keep learning, clearing, and filter refresh blocked in combat.
Do not inspect Aura data to maintain the list during combat.

### AF12-04 — Static-only buffs

**Assessment:** Implemented in the consolidated learned Static / Long frame; no
documented “permanent Auras only” candidate filter exists.

A readable OOC duration of zero adds the spell to the same persistent native
inclusion set as Long buffs. Static / Long Buffs is the sole built-in frame for
both learned classes.

**Direction:** Continue rejecting secret or malformed observations and leave
unknown spells absent until a readable OOC scan learns them.

### AF12-05 — Debuff frame

**Assessment:** Fully preservable after a backend rewrite.

**Status:** Complete for the managed Debuff baseline and verified in game.
Presentation capabilities shared with other managed frames remain tracked under
their own numbered items rather than keeping the Debuff transport item open.

Core transport and bar/icon presentation are verified in game. The
first live checks exposed two framework requirements: a shown `AuraContainer`
does not process Auras until `SetEnabled(true)` is also applied, and its
auto-sizing flow layout must be seeded from one corner rather than stretched
over the owner with `SetAllPoints`. The lifecycle now synchronizes engine
processing and visibility, and the Debuff capability explicitly owns its flow
axis, anchor, growth, wrap width, and group spacing. Regressions cover both
contracts. Debuffs now creates managed `HARMFUL` bar/icon groups with native
icon, duration, stack, spell-name, and duration-bar bindings; it owns no addon
`UNIT_AURA` handler or indexed scan. Bar/icon switching, growth, spacing,
the fixed internal safety limit, width, position, OOC fade transitions, timer font/size/bold/color,
bar foreground color, native tooltips, and resize refresh are implemented.
Native cancellation outside Static / Long Buffs remains intentionally unsupported.
Custom-filter mapping, native timer formatting, and native sorting parity remain
the separate deferred design work.

The first visible managed result was an icon-only cell even though Debuffs was
configured for bar mode. Native tooltip verification proved that Blizzard had
matched Forbearance and bound its correct, unfamiliar-looking icon. AF12-05.2
now honors saved bar mode with the existing 18px row geometry and native
`SetIcon`, `SetSpellName`, `SetDurationText`, `SetApplicationCount`, and
`SetDurationBar` sinks. The container uses vertical flow and the saved UP/DOWN
direction; every widget is created during `initializeFrame`. Native tooltips
remain enabled in and out of combat through Blizzard's owned AuraButton path.

The first native-bar combat check exposed a separate shell regression: the
bar retained its faded out-of-combat alpha after combat began. Removing all
addon-owned Aura events had also removed the presentation-only combat transition.
Managed parent shells now register only `PLAYER_REGEN_DISABLED/ENABLED` and
route both through the existing OOC-fade helper with the explicit state carried
by the event. The first attempt discarded that state and immediately queried
`InCombatLockdown()`, which passed the desktop test but left the live bar faded;
the regression now fires the transition events without pre-changing the stub's
combat flag. Managed shells still have no `UNIT_AURA` handler and perform no
Aura scan.

Test Aura preview uses one addon-owned mock outside the managed Debuff group and
shares the normal addon renderer, ticker, styling, and Play/Pause path without
participating in live AuraContainer discovery.

Live diagnostics must not inspect `AuraButton:IsShown()`: its result is a
secret boolean and even comparison from tainted addon execution errors. They
also must not attach visibility scripts to an AuraButton. Blizzard passes the
secret state into `AuraButton:SetShown()`, which rejects the write when addon
script handlers exist. Managed status therefore stops at non-secret creation
and accessibility facts and makes no claim about active state.

The first safe status record showed `frames=8, shown=0` while the managed
container was enabled, shown, and had created ten accessible AuraButtons. This
proved discovery was not the immediate blocker: removing the addon events had
also removed the Debuff shell's only initial update. Managed runtime startup now
explicitly applies saved shell state after enabling the engine; native child
activation must never be assumed to show an addon-owned parent.

A managed Aura group can use the standard `HARMFUL` filter. Managed candidate
filters additionally support dispel types and several Blizzard-defined Aura
properties if they become useful later.

**Result:** Debuffs remains the proven managed baseline. Presentation changes use
native bindings or accessible OOC updates and never restore AuraData inspection.

### AF12-06 — Custom Filtered Frames

**Assessment:** Preservable when the custom frame is defined by supported
standard AuraFilter strings and managed candidate filters.

Supported inputs include standard filters such as `HELPFUL`, `HARMFUL`,
`PLAYER`, `RAID`, `IMPORTANT`, and their supported negations. Candidate filters
can include or exclude spell IDs and dispel types and can filter several
Blizzard-defined boolean properties and maximum duration.

Arbitrary Lua predicates that require reading an Aura's name, identity, timing,
or other protected data cannot be supported.

**Direction:** Map current custom-filter settings directly to managed group
filters. Validate every filter option accepted by the current UI against the
live 12.1 API before keeping it enabled.

### AF12-07 — Icon, stack, cooldown swipe, and duration-bar presentation

**Assessment:** Preservable through native AuraButton bindings.

AuraButton supports engine-driven icon textures, application counts, duration
cooldowns, duration text, and duration/status bars. The managed presets
use native icon, stack, duration text, spell-name, duration-bar, and icon
duration-swipe sinks.

**Result:** The duration swipe is created during `initializeFrame` and bound
natively. Migrated live Auras remain independent of the addon ticker and
protected-duration reads.

### AF12-08 — Bar mode, fonts, colors, and backgrounds

**Assessment:** Mostly preservable, with stricter lifecycle rules.

**Status:** Complete. Managed bar/icon switching, timer and Stack font/size/bold/color,
black outlines, fractional font sizes, bar foreground color, and resizing are
implemented. Frame BG now uses a shared texture-backed controller on the
addon-owned frame shell and consumes the same local, Shared BG Colors, and All
the Colors policy pipeline as addon-rendered frames. It keeps one configured-width row
visible when empty and extends through non-overlapping regions whose visibility
is inherited from native AuraButtons. The complete Bar/Icon, empty/populated,
combat, shared-color, Bar BG, and non-duration bar-text matrix passed live
acceptance, including immediate accessible OOC refreshes.

Configured appearance can be applied while the AuraButton is initialized.
Static frame-level and group-level colors are safe because they come from addon
settings rather than protected Aura data. Per-Aura decisions requiring Aura
identity or live Aura fields are not safe.

AuraButton children cannot be freely reparented or restyled after protection is
applied. Some setting changes may need to update only accessible buttons, be
deferred, or rebuild/rebind managed groups at a safe time.

**Result:** Immutable bindings stay in initialization; accessible OOC updates
refresh mutable presentation settings while retaining valid profile fields.

### AF12-09 — Timer text formats

**Assessment:** Likely preservable, including compact custom formats.

**Status:** Managed duration text and its visibility/font styling are working,
but the native binding currently uses Blizzard's default formatter. LsTweeks'
addon compact/decimal formatter behavior has not been translated to a native
numeric rule formatter.

The managed duration-text binding accepts Blizzard numeric rule formatters.
TellMeWhen already uses `C_StringUtil.CreateNumericRuleFormatter()` to format a
secret duration without reading it. LsTweeks' current duration ranges and
suffixes should be expressible as numeric formatter breakpoints and components.

**Direction:** Build native numeric formatters corresponding to the current
compact and decimal timer modes. Verify rounding and all boundary transitions
with headless formatter tests and in-game secret Aura testing.

### AF12-10 — Maximum icons, growth, spacing, columns, and positioning

**Assessment:** Preservable through managed Aura group layout.

**Status:** Complete for the managed presets. They use one fixed internal
safety limit rather than a user-adjustable maximum, and implement spacing,
UP/DOWN bar growth, independent four-way icon growth, wrapping, addon-owned
positioning, and width resizing. AuraContainer remains corner-anchored and owns
its child flow; the shell never reads managed content size or shown state.

Managed groups support maximum frame count, direction, spacing, columns, and
group ordering. Containers resize themselves around their Aura groups.

Addon `OnSizeChanged` handlers and size reads tied to managed Aura content are
restricted. Current manual display-count sizing and unused-icon hiding should
not be carried forward.

**Direction:** Let the managed container own child layout and bounds. Keep an
addon-owned outer shell for positioning and decoration only where it can be
anchored safely without observing protected children.

### AF12-11 — Aura sorting

**Assessment:** Partially preservable.

Expiration/time-left ordering and direction are supported by the managed sort
API. Aura-instance ordering is also documented. Name sorting must be checked
against the final live `AuraContainerSortMethod` enum before it is promised.
Addon-defined comparators are impossible because protected Aura fields cannot be
read.

**Direction:** Map only to supported engine sort methods. Remove or migrate any
sort choice that cannot be represented by the live enum.

### AF12-12 — Aura tooltips

**Assessment:** Native detailed tooltips are preservable and should replace the
custom Aura tooltip stack.

**Status:** Complete for managed frames. They use native AuraButton tooltips
with mouse motion enabled in and out of combat. Their
managed path installs no addon hover scripts and performs no Aura tooltip lookup
or reconstruction.

AuraButtons provide engine-owned Aura tooltips, tooltip anchoring, and native
restricted-data handling in combat. Keeping combat tooltips enabled avoids
exposing protected Aura data to addon code and is the supported safe path.

The existing instance-ID tooltip lookup, prewarm cache, reconstructed fallback
lines, and direct `GameTooltip:SetUnitAuraByAuraInstanceID` experiment should not
remain part of the managed live-Aura path.

**Direction:** Use native AuraButton tooltips exclusively for managed Auras.
Retain the shared addon-owned tooltip helper for ordinary LsTweeks controls and
non-Aura content.

### AF12-13 — Player-buff cancellation

**Assessment:** Complete for Static / Long Buffs and custom frames.

Static / Long Buffs configures `RightButtonUp` through the AuraButton
initialization-time `SetCancelAuraButtons()` API. Blizzard's intrinsic secure
handler cancels by Aura instance ID without exposing Aura data to addon code.
Custom frames retain their out-of-combat indexed cancellation path, now on the
same plain right-click gesture. The obsolete configurable modifier was removed
from defaults, settings, and profiles.

### AF12-14 — Out-of-combat fade and hover restoration

**Assessment:** Complete with native AuraButton hover intentionally left
Blizzard-owned.

**Status:** Managed shells use addon-owned combat transitions and OOC fade state.
Move-border and resize-grip hover restore full alpha; managed AuraButton hover is
left native and is not polled by LsTweeks. Frame-specific **Fade OOC** now clears
the global **Disable OOC Fade** policy and synchronizes both linked controls;
the fade alpha is also applied directly to the aggregate managed AuraContainer
because its constrained AuraButtons did not visually inherit shell alpha. This
container-alpha path passed the complete combat/fade/Move Mode live recheck.

Managed AuraButtons restrict shown-state and focus/hover queries while protected,
so LsTweeks intentionally does not poll them or install hover scripts.

**Result:** Fade state stays on addon-owned shell/container layers. Move controls
restore full alpha; native AuraButton interaction remains unobstructed.

### AF12-15 — Test Aura previews

**Assessment:** Preservable as addon-owned mock visuals.

**Status:** Complete. Every Aura frame uses the shared addon preview builder,
renderer, ticker, and Play/Pause clock. Managed presets and CDM Aura-mode frames
place one shell-owned mock on the side opposite native growth without injecting
synthetic data into Blizzard groups; CDM Cooldown Mode keeps the preview in its
normal addon-rendered sequence.

Test Auras use generated addon data rather than protected live Aura data. They
should not be injected into, or depend on, a managed live-Aura group.

**Result:** Preview widgets remain separate from managed AuraButtons while using
the shared addon presentation and formatter paths.

### AF12-16 — Profiles, shared colors, move mode, and settings

**Assessment:** Preservable.

**Status:** Complete for the current managed presets. They have independent
saved settings, positions, profile fields, shared-color
participation, four-way icon growth, vertical bar growth, move borders, and
resize grips. OOC changes update container layout and accessible presentation
state without rebuilding managed groups. Addon-owned previews are supported
without entering managed groups; native cancellation is intentionally limited
to Static / Long Buffs.

These features manage addon-owned configuration and positioning. This project
has one developer/user and does not carry migration code: obsolete fields are
removed directly, while module reset remains the clean recovery path.

Some live appearance changes may need to be deferred while managed buttons are
forbidden. Profile loading is already blocked during combat, which is helpful
but is not a complete substitute for checking AuraButton accessibility.

**Direction:** Retain the current profile structure where its capabilities
remain valid. Obsolete fields are removed directly and reset/default behavior
remains authoritative.

### AF12-17 — Cooldown Manager-backed frames

**Features:** Essential, Utility, Tracked Buffs, and Tracked Bars.

**Assessment:** Complete for the intended category modes.

Active Aura transport now uses Blizzard's new managed AuraGroup/AuraSlot APIs.
Aura mode creates compact per-cooldown groups; cooldown mode overlays stable
per-cooldown slots over the surviving addon cooldown layer. The managed filters
come from CDM base/override/linked spell metadata and never read child Aura IDs
or `AuraData`.

Cooldown-only entries now use `C_CooldownViewer.GetCooldownViewerCategorySet()`
and `GetCooldownViewerCooldownInfo()` for ordered identity, plus
`C_Spell.GetSpellCooldownDuration()` / `GetSpellChargeDuration()` for duration
objects. Neither mode reads, hooks, prepares, or forces visibility on Blizzard
Cooldown Viewer item frames.

**Status:** Essential and Utility passed Aura/Cooldown Mode, active-to-cooldown
slot handoff, category moves, native tooltips, order, bar/icon presentation, and
reload during an encounter. Tracked Buffs and Tracked Bars intentionally expose
Aura mode only and passed active-Aura lifecycle and ordering checks.

### AF12-18 — Hiding Blizzard Aura and Cooldown Manager frames

**Assessment:** BuffFrame and DebuffFrame now have a reversible, test-covered
hidden-parent path. Cooldown Manager suppression is presentation-only.

**Status:** Complete for the intended suppression scope. The General-tab Blizzard Buff/Debuff toggles work in
game, and automated coverage verifies deferred changes plus module-disable
restoration. The 2026-08-15 in-game matrix passed checkbox changes, reload,
combat deferral, module-disable restoration, and hidden-hitbox checks. Cooldown
Manager suppression no longer participates in CDM data transport.

BuffFrame and DebuffFrame inherit Blizzard's Aura Frame Edit Mode behavior, but
`UpdateSystemSettingValue` silently does nothing before the system has
`systemInfo`; the first native-setting attempt therefore passed headless tests
while the General-tab checkbox had no live effect. LsTweeks now places these
frames under one hidden addon-owned parent and restores their captured original
parents after combat. Blizzard shown state, events, scripts, and Aura processing
remain untouched, while rendering and descendant hitboxes are both suppressed.

**Direction:** BuffFrame/DebuffFrame suppression is complete. Cooldown Manager
hide settings may change alpha and mouse state only; do not hook viewer scripts,
drive Edit Mode visibility, or call viewer update methods.

### AF12-19 — Other LsTweeks modules

**Assessment:** No direct incompatibility found from the 12.1 Aura restrictions
or the specifically reviewed removed APIs.

**Status:** Complete for the current patch review. The full automated suite
passes, and extended in-game use has not produced another unresolved 12.1
regression outside Aura Frames.

Player Frame, Objectives, Audio Volumes, All the Colors, Skyriding Vigor, core
navigation, and ordinary settings tooltips do not use the indexed Aura APIs
identified in this failure.

**Direction:** Run the normal complete regression suite and targeted in-game
smoke checks after the Aura Frames rewrite. Do not broaden the migration into
unrelated modules without new evidence.

## Archival disposition
- Current behavior and safety contracts were promoted to `aura_frames.md`.
- Repeatable CDM acceptance remains in `internal_dev/tests_tools/aura_frames_cdm_regression.md`.
- Raw and normalized performance evidence remains in `internal_dev/tests_tools/cpu_profiles/af_cpu_profiles.md`.
- Only the explicitly deferred feature-design items remain active in `aura_frames_deferred_features.md`.
