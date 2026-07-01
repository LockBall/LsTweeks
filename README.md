# L's Tweeks
L's Tweeks is a modular World of Warcraft Retail UI addon for configurable player aura frames, player frame adjustments, small interface adjustments, and quieter replacement sounds.

Slash command: `/lst`


## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Use Notes](#use-notes)
- [Aura Frames](#aura-frames)
- [Audio Volumes](#audio-volumes)
- [Embedded Libraries](#embedded-libraries)
- [License](#license)
- [Credits](#credits)
- [Sources](#sources)


## Features
### Aura Frames
- Configurable player aura frames for buffs, debuffs, and WoW Cooldown Manager groups.
- Preset frames for static buffs, short buffs, long buffs, debuffs, essential cooldowns, utility cooldowns, tracked buffs, and tracked bars.
- Custom filtered frames using AuraFilters such as `HELPFUL|IMPORTANT`.
- Icon and bar presentation modes with configurable growth direction, spacing, width, colors, timers, tooltips, and test-aura previews.
- Optional modifier-right-click cancellation for eligible player buffs.
- Profiles for saving and loading complete aura-frame setups across characters.
- Optional hiding of Blizzard buff and debuff frames.


### Player Frame
- Optional hiding of Player Frame portrait combat text.
- Optional out-of-combat Player Frame fade controls.


### Objectives
- Separate **Position** controls for moving the All Objectives tracker, including snap-to-grid offsets.
- Separate controls for Blizzard's Objective Tracker background and LsTweeks' custom color background.
- Optional **Auto-Collapse** group to start All Objectives, Campaign, Quests, and Achievements collapsed while preserving normal manual expand/collapse behavior.
- Optional **Section Count** checkboxes for quest log and tracked achievement counters, with per-counter **On Hover** display options.
- Keeps the All Objectives background sized to the visible tracker sections when Objectives module behavior is active.


### Skyriding Vigor
- Restores a compact player vigor display using Blizzard UI assets.
- Adjustable position, size, spacing, node style/color, fill color, end-decoration style/color, fade behavior, and optional separate race profile.


### Audio Volumes
- Quieter addon replacement sounds for supported targets, currently including Achievement test and Ready Check.
- Per-target Original behavior and replacement volume controls.
- Temporary channel controls for normal game volumes, fishing volumes, combat volumes, and manual Quick Picks.


### Settings
- Optional minimap button.
- Open-on-reload setting.
- Main panel transparency control.


## Installation
1. Download or clone the addon.
2. Ensure the addon folder is named `LsTweeks`.
3. Place the folder here:

```text
World of Warcraft/_retail_/Interface/AddOns/LsTweeks
```

4. Launch or reload the game.
5. Enable **L's Tweeks** in the AddOns menu.

For CurseForge/manual zip installs, the archive should extract to a single top-level `LsTweeks` folder.


## Use Notes
- Open the settings panel with `/lst` or the minimap button.
- Use `/lst status` for all module diagnostics, or `/lst status <module>` for one module such as `/lst status objectives`.
- Open **Buffs & Debuffs** for aura frame settings.
- Use **Buffs & Debuffs > Profiles** to save or load complete Aura Frames setups.
- Open **Settings** for minimap, open-on-reload, interface transparency, and module enable toggles.
- Open **Objectives** for Auto-Collapse and Section Count options.
- Open **Skyriding Vigor** to enable the restored vigor display and adjust its position, size, spacing, node style/color, fill color, end decorations, fade behavior, and optional race profile.
- Open **Audio Volumes** to configure quieter replacement sounds, keep the original Blizzard sound, or use temporary Fishing/Combat sound profiles.
- Some Aura Frame pool-size changes require `/reload` because icon pools are created at load time.


## Aura Frames
Aura Frames replace and extend the default player buff and debuff display. The module includes preset player-aura frames, WoW Cooldown Manager-backed frames, and custom filtered frames.


### Preset Frames
- `Static`: permanent player buffs.
- `Short`: timed player buffs at or below the short-buff threshold.
- `Long`: timed player buffs above the short-buff threshold.
- `Debuffs`: harmful player auras.


### WoW Cooldown Manager Frames
Cooldown Manager-backed frames read live Blizzard Cooldown Manager viewer state:

- `Essential`
- `Utility`
- `Tracked Buffs`
- `Tracked Bars`

WoW Cooldown Manager must stay enabled for these frames to populate. When an LsTweeks CDM-backed frame is enabled, the matching WoW Edit Mode Cooldown Manager frame is kept set to **Always Visible** so it continues producing live viewer state. If **Hide WoW ...** is checked, LsTweeks hides the Blizzard viewer with alpha and mouse settings, not `Hide()`, because hidden viewers stop providing useful child state. Use **Sync to CDM** after manually reordering icons inside the same CDM group if the addon frame has not refreshed yet.


### Custom Filtered Frames
Custom frames scan player auras directly with a selected AuraFilters string. Example:

```lua
C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|IMPORTANT")
```

The `IMPORTANT` AuraFilter was added in WoW 12.0.1 and is described as spells that pass `C_Spell.IsSpellImportant()`.


### Profiles
Profiles save the full Aura Frames setup, including preset frame settings, Cooldown Manager-backed frame presentation, positions, colors, timer styling, and custom filtered frames. Loading a profile replaces the current Aura Frames setup and recreates missing custom frames. Profile loading is blocked during combat.

The Aura Frames reset panel includes a checked **Keep Profiles** option so saved profiles can survive a module reset.


## Audio Volumes
WoW does not expose true per-sound volume control or custom sound channels. This addon mutes known original Blizzard FileDataIDs where configured, then optionally plays addon-owned replacement files at the selected level.

Current sound targets:

- `Achievement`: local test target for slider and preview behavior.
- `Ready Check`: replacement control for ready check and LFG proposal sounds.

Replacement volume is shown as `0-100%` in 5% steps. `0%` is off. The **Original** checkbox keeps Blizzard's original sound and dims the replacement slider until the slider is moved.

The **Situations** tab always shows Normal Volumes for the user's regular Master, Music, Effects, Ambience, and Dialog channel volumes. A situation list selects one editable built-in situation row below it: Fishing or Combat. Fishing and Combat have title-bar enable checkboxes for automatic activation. Combat starts use `PLAYER_REGEN_DISABLED`, combat ends use `PLAYER_REGEN_ENABLED`, and entering combat exits the Fishing profile.

The **Quick Picks** tab stores manual sound-channel profiles, including Quiet Custom and user-created custom Quick Picks. Quick Picks do not auto-trigger because there is no user-facing trigger builder. Fishing and Combat temporarily override an enabled Quick Pick, then the Quick Pick resumes afterward. The Play buttons preview the selected profile with the Fishing Bobber splash sound. Exact Fishing Bobber bite-sound replacement is not available because the bite timing is not exposed through the tested Lua hooks/APIs.

Sound target details are tracked in `modules/sound_levels/sounds/sound_reference.md`.


## Embedded Libraries
Embedded libraries are stored in `libs/` and credited in `sources.md`. They are vendored third-party files and are kept unmodified.

- CallbackHandler-1.0
- LibDBIcon-1.0
- LibDataBroker-1.1
- LibStub


## License
- This project is released under the MIT License.
- Embedded libraries retain their original licenses as listed in `sources.md`.
- See `LICENSE` for full details.
- Copyright (c) 2026 **LockBall**.


## Credits
- LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0 by their respective authors on WowAce / CurseForge.
- Inspired by the WoW addon community, including Elkano's BuffBars, BetterCooldownManager, ArcUI, and Angleur.
- Fishing Focus was informed by Angleur's Ultra Focus audio-profile approach.
- Skyriding Vigor was informed by DragonRider's restored vigor-display concept; this addon uses its own implementation and Blizzard UI assets.
- Addon design and implementation by **LockBall**.
- Special thanks to **DiscoMouse**.
- Portions of this addon were developed with assistance from generative tools.


## Sources
Public credits and embedded library sources are tracked in `sources.md`.
