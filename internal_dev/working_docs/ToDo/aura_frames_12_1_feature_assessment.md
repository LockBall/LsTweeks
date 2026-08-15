# Aura Frames 12.1 Feature Assessment

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

## Numbered feature assessment

### AF12-01 — Preset live Aura frames

**Features:** Static, Short, Long, Combined Buffs, and Debuffs.

**Assessment:** Partially migrated. Debuffs and the new, independent Combined
Buffs frame now use managed AuraContainers. Static, Short, and Long retain their
existing saved settings and implementations for later separation work, but
remain incompatible legacy paths and must not yet be used for combat validation.

`af_scan.lua` discovers player Auras with `GetBuffDataByIndex` and
`GetDebuffDataByIndex`. `af_render.lua` also requests and iterates Aura instance
IDs for sorting. These operations are no longer safe while Auras are secret.
The four captured errors are direct manifestations of this incompatibility.

**Direction:** Validate the unrestricted combined `HELPFUL` Buffs frame first.
Then separate supported categories through managed filters without restoring
addon AuraData inspection. The exact Static/Short split remains addressed
separately below.

### AF12-02 — Short frame threshold semantics

**Assessment:** The current behavior cannot be reproduced exactly with the
documented managed filters.

LsTweeks classifies an Aura as Short using its *remaining* time. A Long Aura is
therefore transferred into the Short frame when its countdown crosses the
configured threshold. Managed candidate filters support `maxDuration`, but that
means the Aura's total or maximum duration, not its current remaining time.

**Direction:** Redefine Short as “total duration at or below the threshold,” or
replace the Short/Long model with a different grouping. Do not silently retain
the setting with changed semantics; make the change explicit in UI text and
migration notes.

### AF12-03 — Long frame filtering

**Assessment:** No documented managed `minDuration` filter exists. A clean
“duration greater than the Short threshold” group therefore cannot currently be
created without inspecting protected Aura data.

Using an unrestricted timed group alongside a `maxDuration` Short group may
duplicate Short Auras, depending on group assignment behavior, and must not be
assumed safe without a focused in-game probe.

**Direction:** Preserve Long as its own feature. Use the separate Combined Buffs
frame, with its own saved settings and unrestricted managed `HELPFUL` filter,
as the safe baseline while investigating separation. Do not emulate Long with
addon-side Aura inspection.

### AF12-04 — Static-only buffs

**Assessment:** No documented “permanent Auras only” candidate filter exists.

A nonzero `maxDuration` excludes permanent Auras, but there is no documented
inverse that selects only permanent Auras. The old Static classification relies
on expiration data that addons can no longer examine safely.

**Direction:** Redesign or consolidate Static. Do not attempt to infer
permanence from secret timing values.

### AF12-05 — Debuff frame

**Assessment:** Fully preservable after a backend rewrite.

**Status:** Core transport and bar/icon presentation are verified in game. The
first live checks exposed two framework requirements: a shown `AuraContainer`
does not process Auras until `SetEnabled(true)` is also applied, and its
auto-sizing flow layout must be seeded from one corner rather than stretched
over the owner with `SetAllPoints`. The lifecycle now synchronizes engine
processing and visibility, and the Debuff capability explicitly owns its flow
axis, anchor, growth, wrap width, and group spacing. Regressions cover both
contracts. Debuffs now creates managed `HARMFUL` bar/icon groups with native
icon, duration, stack, spell-name, and duration-bar bindings; it owns no legacy
`UNIT_AURA` handler or indexed scan. Bar/icon switching, growth, spacing,
maximum count, width, position, OOC fade transitions, timer font/size/bold/color,
bar foreground color, native OOC tooltips, and resize refresh are implemented.
Synthetic previews, cancellation, cooldown swipe, custom timer formatting,
sorting parity, and full live color/background parity remain separate work.

The first visible managed result was an icon-only cell even though Debuffs was
configured for bar mode. Native tooltip verification proved that Blizzard had
matched Forbearance and bound its correct, unfamiliar-looking icon. AF12-05.2
now honors saved bar mode with the legacy 18px row geometry and native
`SetIcon`, `SetSpellName`, `SetDurationText`, `SetApplicationCount`, and
`SetDurationBar` sinks. The container uses vertical flow and the saved UP/DOWN
direction; every widget is created during `initializeFrame`. Native tooltips
remain enabled out of combat and hidden in combat.

The first native-bar combat check exposed a separate shell regression: the
bar retained its faded out-of-combat alpha after combat began. Removing all
legacy frame events had also removed the presentation-only combat transition.
Managed parent shells now register only `PLAYER_REGEN_DISABLED/ENABLED` and
route both through the existing OOC-fade helper with the explicit state carried
by the event. The first attempt discarded that state and immediately queried
`InCombatLockdown()`, which passed the desktop test but left the live bar faded;
the regression now fires the transition events without pre-changing the stub's
combat flag. Managed shells still have no `UNIT_AURA` handler and perform no
Aura scan.

The existing Test Aura preview is still a legacy-icon capability and does not
render in the managed Debuff path. A managed-safe synthetic preview must be implemented as a
separate increment; its absence cannot be used to test live AuraContainer
discovery.

Live diagnostics must not inspect `AuraButton:IsShown()`: its result is a
secret boolean and even comparison from tainted addon execution errors. They
also must not attach visibility scripts to an AuraButton. Blizzard passes the
secret state into `AuraButton:SetShown()`, which rejects the write when addon
script handlers exist. Managed status therefore stops at non-secret creation
and accessibility facts and makes no claim about active state.

The first safe status record showed `frames=8, shown=0` while the managed
container was enabled, shown, and had created ten accessible AuraButtons. This
proved discovery was not the immediate blocker: removing the legacy events had
also removed the Debuff shell's only initial update. Managed runtime startup now
explicitly applies saved shell state after enabling the engine; native child
activation must never be assumed to show an addon-owned parent.

A managed Aura group can use the standard `HARMFUL` filter. Managed candidate
filters additionally support dispel types and several Blizzard-defined Aura
properties if they become useful later.

**Direction:** Keep Debuffs as the proven managed baseline. Add remaining
presentation features only through native bindings or accessible OOC updates;
never restore AuraData inspection.

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
cooldowns, duration text, and duration/status bars. Combined Buffs and Debuffs
now use native icon, stack, duration text, spell-name, and duration-bar sinks.
Icon cooldown swipe is not yet bound for these managed presets.

**Direction:** Add any cooldown swipe inside `initializeFrame` and bind it
natively. Migrated frames must remain independent of the manual live-Aura ticker
and protected-duration reads.

### AF12-08 — Bar mode, fonts, colors, and backgrounds

**Assessment:** Mostly preservable, with stricter lifecycle rules.

**Status:** Managed bar/icon switching, timer font/size/bold/color, bar
foreground color, shell backgrounds, and resizing are implemented. Bar
background and non-duration bar text are still initialized from settings and do
not yet have a complete accessible OOC refresh path.

Configured appearance can be applied while the AuraButton is initialized.
Static frame-level and group-level colors are safe because they come from addon
settings rather than protected Aura data. Per-Aura decisions requiring Aura
identity or live Aura fields are not safe.

AuraButton children cannot be freely reparented or restyled after protection is
applied. Some setting changes may need to update only accessible buttons, be
deferred, or rebuild/rebind managed groups at a safe time.

**Direction:** Split presentation into immutable initialization work and
safe/deferred configuration updates. Preserve existing profile fields where
their meaning remains valid.

### AF12-09 — Timer text formats

**Assessment:** Likely preservable, including compact custom formats.

**Status:** Managed duration text and its visibility/font styling are working,
but the native binding currently uses Blizzard's default formatter. LsTweeks'
legacy compact/decimal formatter behavior has not been translated to a native
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

**Status:** Combined Buffs and Debuffs implement maximum count, spacing,
UP/DOWN bar growth, four-way icon growth, wrapping, addon-owned positioning, and
width resizing. AuraContainer remains corner-anchored and owns its child flow;
the shell never reads managed content size or shown state.

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

**Status:** Combined Buffs and Debuffs use native AuraButton tooltips with mouse
motion enabled and combat tooltips hidden. Their managed path installs no addon
hover scripts and performs no Aura tooltip lookup or reconstruction.

AuraButtons provide engine-owned Aura tooltips, tooltip anchoring, and an option
to hide tooltips in combat. This avoids exposing protected Aura data and is the
community-standard safe path.

The existing instance-ID tooltip lookup, prewarm cache, reconstructed fallback
lines, and direct `GameTooltip:SetUnitAuraByAuraInstanceID` experiment should not
remain part of the managed live-Aura path.

**Direction:** Use native AuraButton tooltips exclusively for managed Auras.
Retain the shared addon-owned tooltip helper for ordinary LsTweeks controls and
non-Aura content.

### AF12-13 — Player-buff cancellation

**Assessment:** Basic native click-to-cancel is supported. Exact parity with the
current configurable modifier-plus-right-click behavior is uncertain.

The current implementation discovers a cancelable buff by scanning indexes and
then calls `CancelUnitBuff`. That discovery path is incompatible with Aura
secrecy. AuraButton now has an initialization-time API that assigns mouse clicks
used for native cancellation, but the available documentation does not confirm
support for LsTweeks' configurable Ctrl/Shift/Alt modifier requirement.

**Direction:** Prefer native right-click cancellation. Verify whether modifiers
are supported; if not, retire the modifier setting rather than recreating
cancellation through protected scans or addon click handlers.

### AF12-14 — Out-of-combat fade and hover restoration

**Assessment:** Whole-frame fading is preserved. Icon-hover restoration needs
redesign and may not be exactly preservable.

**Status:** Managed shells use addon-owned combat transitions and OOC fade state.
Move-border and resize-grip hover restore full alpha; managed AuraButton hover is
left native and is not polled by LsTweeks.

The current code polls visible icons with `IsShown()` and `IsMouseOver()` to
restore full alpha while hovered. Managed AuraButtons restrict shown-state and
focus/hover queries while protected, and addon-installed scripts on them may not
execute.

**Direction:** Keep fade state on an addon-owned outer frame. Investigate whether
an outer interaction layer can safely provide hover restoration without
blocking native AuraButton tooltips or clicks. If not, preserve OOC fade without
the icon-hover exception.

### AF12-15 — Test Aura previews

**Assessment:** Preservable as addon-owned mock visuals.

Test Auras use generated addon data rather than protected live Aura data. They
should not be injected into, or depend on, a managed live-Aura group.

**Direction:** Keep preview widgets separate from managed AuraButtons while
sharing presentation configuration and formatter definitions wherever safe.

### AF12-16 — Profiles, shared colors, move mode, and settings

**Assessment:** Preservable.

**Status:** Combined Buffs has independent saved settings, position, profile
fields, shared-color participation, four-way icon growth, vertical bar growth,
move border, and resize grip. OOC changes update container layout and accessible
presentation state without rebuilding managed groups. Fields tied to unfinished
sorting, preview, cancellation, or legacy Static/Short/Long semantics remain
subject to migration decisions.

These features manage addon-owned configuration and positioning. Saved fields
whose underlying feature changes meaning, especially the Short threshold,
Static, Long, modifier cancellation, and unsupported sorting choices, need an
explicit migration policy.

Some live appearance changes may need to be deferred while managed buttons are
forbidden. Profile loading is already blocked during combat, which is helpful
but is not a complete substitute for checking AuraButton accessibility.

**Direction:** Retain profile structure where possible and version the Aura
Frames schema when final category decisions are made.

### AF12-17 — Cooldown Manager-backed frames

**Features:** Essential, Utility, Tracked Buffs, and Tracked Bars.

**Assessment:** Not implicated directly by the four captured Lua errors, but
high-risk and not yet proven 12.1-safe.

These frames do not use the ordinary preset Aura scanner as their primary
source. They mirror Blizzard Cooldown Manager viewer children and hook their
state. Some child state, Aura-backed duration information, or frame access may
now become secret or forbidden during combat and encounters.

Cooldown-only entries are not equivalent to active Auras, so a managed
AuraContainer is not automatically a complete replacement for this backend.

**Direction:** Audit and test this path separately in combat. Verify Essential,
Utility, Tracked Buffs, and Tracked Bars in both active-Aura and cooldown phases,
including reload during an encounter. Decide from evidence whether to retain the
viewer bridge or migrate only its Aura-backed portions.

### AF12-18 — Hiding Blizzard Aura and Cooldown Manager frames

**Assessment:** BuffFrame and DebuffFrame now have a reversible, test-covered
hidden-parent path. Cooldown Manager suppression remains a separate concern.

BuffFrame and DebuffFrame inherit Blizzard's Aura Frame Edit Mode behavior, but
`UpdateSystemSettingValue` silently does nothing before the system has
`systemInfo`; the first native-setting attempt therefore passed headless tests
while the General-tab checkbox had no live effect. LsTweeks now places these
frames under one hidden addon-owned parent and restores their captured original
parents after combat. Blizzard shown state, events, scripts, and Aura processing
remain untouched, while rendering and descendant hitboxes are both suppressed.

**Direction:** In game, verify both Blizzard Aura enable toggles after reload and
after module disable, including parent restoration and the absence of invisible
Aura hitboxes. The approach is informed by BasicBuffHide's current maintained
implementation but is independently implemented here.
Continue avoiding `Hide()` for Cooldown Manager viewers where doing so stops the
viewer from producing state needed by LsTweeks.

### AF12-19 — Other LsTweeks modules

**Assessment:** No direct incompatibility found from the 12.1 Aura restrictions
or the specifically reviewed removed APIs.

Player Frame, Objectives, Audio Volumes, All the Colors, Skyriding Vigor, core
navigation, and ordinary settings tooltips do not use the indexed Aura APIs
identified in this failure.

**Direction:** Run the normal complete regression suite and targeted in-game
smoke checks after the Aura Frames rewrite. Do not broaden the migration into
unrelated modules without new evidence.

## Recommended review order

1. Keep Combined Buffs and Debuffs as the validated managed baseline while
   resolving the Static/Short/Long product model in AF12-02 through AF12-04.
2. Finish managed presentation gaps in AF12-07 through AF12-12: cooldown swipe,
   live color/background refresh parity, native timer formatting, and sorting.
3. Add managed-safe synthetic previews under AF12-15, then decide native buff
   cancellation and hover behavior under AF12-13 and AF12-14.
4. Migrate supported custom filters under AF12-06 without arbitrary AuraData
   predicates.
5. Audit CDM-backed frames independently under AF12-17, then complete the wider
   in-game regression checks in AF12-18 and AF12-19.
