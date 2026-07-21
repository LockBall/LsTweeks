# L's Tweeks
L's Tweeks is a modular World of Warcraft Retail UI addon for configurable player aura frames, player frame adjustments, small interface adjustments, and quieter replacement sounds.

Slash command: `/lst`


## Table of Contents
- [Modules](#modules)
  - [Aura Frames](#aura-frames)
  - [Player Frame](#player-frame)
  - [Objectives](#objectives)
  - [Skyriding Vigor](#skyriding-vigor)
  - [Audio Volumes](#audio-volumes)
  - [Settings](#settings)
- [Installation](#installation)
- [Use Notes](#use-notes)
- [Embedded Libraries](#embedded-libraries)
- [License](#license)
- [Credits](#credits)
- [Sources](#sources)


## Modules
- [Aura Frames](#aura-frames): configurable player aura frames for buffs, debuffs, and WoW Cooldown Manager groups.
- [Player Frame](#player-frame): optional Player Frame combat-text hiding and out-of-combat fade controls.
- [Objectives](#objectives): position, background, auto-collapse, and section-count controls for the Objective Tracker.
- [Skyriding Vigor](#skyriding-vigor): restored compact player vigor display with adjustable style and behavior.
- [Audio Volumes](#audio-volumes): quieter replacement sounds and temporary channel-volume situations.
- [Settings](#settings): minimap button, open-on-reload, and main panel transparency.


### Aura Frames
Aura Frames replace and extend the default player buff and debuff display. The module includes preset player-aura frames, WoW Cooldown Manager-backed frames, and custom filtered frames.


#### Preset Frames
- `Static`: permanent player buffs.
- `Short`: timed player buffs at or below the short-buff threshold.
- `Long`: timed player buffs above the short-buff threshold.
- `Debuffs`: harmful player auras.

#### Test Aura Preview
Use **Test Aura** to preview a frame. Its adjacent Play/Pause button controls the preview countdown; a saved active preview loads paused after reload until you select Play.


#### WoW Cooldown Manager Frames
Cooldown Manager-backed frames read live Blizzard Cooldown Manager viewer state:

- `Essential`
- `Utility`
- `Tracked Buffs`
- `Tracked Bars`

WoW Cooldown Manager must stay enabled for these frames to populate. When an LsTweeks CDM-backed frame is enabled, the matching WoW Edit Mode Cooldown Manager frame is kept set to **Always Visible** so it continues producing live viewer state. If **Hide WoW ...** is checked, LsTweeks hides the Blizzard viewer with alpha and mouse settings, not `Hide()`, because hidden viewers stop providing useful child state. Use **Sync to CDM** after manually reordering icons inside the same CDM group if the addon frame has not refreshed yet.


#### Custom Filtered Frames
Custom frames scan player auras directly with a selected AuraFilters string. Example:

```lua
C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|IMPORTANT")
```

The `IMPORTANT` AuraFilter was added in WoW 12.0.1 and is described as spells that pass `C_Spell.IsSpellImportant()`.


#### Profiles
Profiles save the full Aura Frames setup, including preset frame settings, Cooldown Manager-backed frame presentation, positions, colors, timer styling, and custom filtered frames. Loading a profile replaces the current Aura Frames setup and recreates missing custom frames. Profile loading is blocked during combat.

Aura Frames, Audio Volumes, Objectives, and Skyriding Vigor reset panels include a checked **Keep Profiles** option so saved profiles can survive a module reset.


### Player Frame
Player Frame adjustments are small, independent tweaks to the default Blizzard Player Frame; there is no dedicated presentation module beyond the toggles below.

- **Hide Portrait Combat Text**: hides the floating combat text that appears over the Player Frame portrait.
- **Out-of-Combat Fade**: fades the Player Frame when out of combat, restoring full opacity on combat start.


### Objectives
Objectives extends and restyles the Blizzard Objective Tracker (All Objectives, Campaign, Quests, Achievements) without replacing its underlying frames.

- **Position**: separate controls for moving the All Objectives tracker, including snap-to-grid offsets.
- **Background**: separate controls for Blizzard's Objective Tracker background and LsTweeks' custom color background, sized to the visible tracker sections when Objectives module behavior is active.
- **Auto-Collapse**: optional group to start All Objectives, Campaign, Quests, and Achievements collapsed while preserving normal manual expand/collapse behavior.
- **Section Count**: optional checkboxes for quest log and tracked achievement counters, with per-counter **On Hover** display options.
- **Profiles**: saving and loading complete Objective Tracker setups, plus a module reset that can preserve saved profiles.


### Skyriding Vigor
Skyriding Vigor restores a compact player vigor display using Blizzard UI assets, replacing the space left by the removed default vigor bar.

- Adjustable position, size, and spacing.
- Adjustable node style/color, fill color, and end-decoration style/color.
- Adjustable fade behavior.
- Optional separate profile per race.
- **Profiles**: saving and loading complete Vigor Bar setups, plus a module reset that can preserve saved profiles.


### Audio Volumes
WoW does not expose true per-sound volume control or custom sound channels. This addon mutes known original Blizzard FileDataIDs where configured, then optionally plays addon-owned replacement files at the selected level.

Current sound targets:

- `Achievement`: local test target for slider and preview behavior.
- `Ready Check`: replacement control for ready check and LFG proposal sounds.

Replacement volume is shown as `0-100%` in 5% steps. `0%` is off. The **Original** checkbox keeps Blizzard's original sound and dims the replacement slider until the slider is moved.

The **Situations** tab always shows Normal Volumes for the user's regular Master, Music, Effects, Ambience, and Dialog channel volumes. Its list has a Triggered group for Fishing and Combat plus a Quick Picks group for Quiet Custom and user-created custom Quick Picks. Fishing and Combat have title-bar enable checkboxes for automatic activation. Combat starts use `PLAYER_REGEN_DISABLED`, combat ends use `PLAYER_REGEN_ENABLED`, and entering combat exits the Fishing situation.

Quick Picks store manual sound-channel situations and do not auto-trigger because there is no user-facing trigger builder. Right-clicking the minimap button includes **Normal Volumes** to clear the active Quick Pick. Fishing and Combat temporarily override an enabled Quick Pick, then the Quick Pick resumes afterward. The Play buttons preview the selected situation with the Fishing Bobber splash sound. Exact Fishing Bobber bite-sound replacement is not available because the bite timing is not exposed through the tested Lua hooks/APIs.

Sound target details are tracked in `modules/audio_volumes/sounds/sound_reference.md`.


### Settings
Settings covers addon-wide behavior rather than a specific module's presentation.

- **Minimap Button**: optional minimap button, with a right-click menu for module-specific quick actions such as Audio Volumes' Normal Volumes.
- **Open On Reload**: optionally opens the settings panel automatically after a `/reload`.
- **Panel Transparency**: main settings panel transparency control.


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
- Open **Objectives** for Tracker settings, module reset, and saved profiles.
- Open **Skyriding Vigor** for General module controls, Vigor Bar appearance and behavior, and saved profiles.
- Open **Audio Volumes** to configure replacement sounds and temporary-volume situations, reset the module, or manage saved profiles.
- Some Aura Frame pool-size changes require `/reload` because icon pools are created at load time.


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
- Portions of this addon were developed with assistance from agentic tools.


## Sources
Public credits and embedded library sources are tracked in `sources.md`.
