## L's Tweeks

L's Tweeks is a modular World of Warcraft Retail UI addon for configurable player aura frames, player frame adjustments, small interface adjustments, and quieter replacement sounds.

Supported client: Retail 12.0.5+  
TOC interface: `120005`  
Slash command: `/lst`

## Features

- Buffs & Debuffs module with configurable player aura frames.
- Preset aura frames for static buffs, short buffs, long buffs, debuffs, and WoW Cooldown Manager groups.
- Custom filtered aura frames using AuraFilters such as `HELPFUL|IMPORTANT`.
- Icon and bar presentation modes with configurable growth direction, spacing, width, colors, timers, and test-aura previews.
- Per-frame tooltip visibility.
- Optional modifier-right-click cancellation for eligible player buffs.
- Aura Frame Profiles for saving and loading complete aura-frame setups across characters.
- Optional hiding of Blizzard buff and debuff frames.
- Optional minimap button, open-on-reload setting, and main panel transparency.
- Player Frame module for portrait combat text and out-of-combat fade controls.
- Sound Levels panel for quieter addon replacement sounds, currently including Achievement test and Ready Check targets, plus Fishing Focus channel controls.

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
- Open **Buffs & Debuffs** for aura frame settings.
- Use **Buffs & Debuffs > Profiles** to save or load complete Aura Frames setups.
- Open **Settings** for minimap, open-on-reload, and interface transparency options.
- Open **Sound Levels** to configure quieter replacement sounds, keep the original Blizzard sound, or use Fishing Focus while fishing.
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

WoW Cooldown Manager must stay enabled for these frames to populate. CDM-backed Blizzard viewer frames are hidden with alpha and mouse settings, not `Hide()`, because hidden viewers stop providing useful child state. Use **Sync to CDM** after manually reordering icons inside the same CDM group if the addon frame has not refreshed yet.

### Custom Filtered Frames

Custom frames scan player auras directly with a selected AuraFilters string. Example:

```lua
C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|IMPORTANT")
```

The `IMPORTANT` AuraFilter was added in WoW 12.0.1 and is described as spells that pass `C_Spell.IsSpellImportant()`.

### Profiles

Profiles save the full Aura Frames setup, including preset frame settings, Cooldown Manager-backed frame presentation, positions, colors, timer styling, and custom filtered frames. Loading a profile replaces the current Aura Frames setup and recreates missing custom frames. Profile loading is blocked during combat.

The Aura Frames reset panel includes a checked **Keep Profiles** option so saved profiles can survive a module reset.

## Sound Levels

WoW does not expose true per-sound volume control or custom sound channels. This addon mutes known original Blizzard FileDataIDs where configured, then optionally plays addon-owned replacement files at the selected level.

Current sound targets:

- `Achievement`: local test target for slider and preview behavior.
- `Ready Check`: replacement control for ready check and LFG proposal sounds.

Replacement volume is shown as `0-100%` in 5% steps. `0%` is off. The **Original** checkbox keeps Blizzard's original sound and dims the replacement slider until the slider is moved.

Fishing Focus is available on the **Fishing** tab. It temporarily applies a separate Master, Music, Effects, Ambience, and Dialog channel profile while the player is channeling Fishing, then restores the normal channel volumes when fishing ends. The Fishing profile initializes from the user's normal channel volumes, with Effects set 25 percentage points higher, clamped to 100%. The tab includes Normal and Fishing profile preview buttons that play the Fishing Bobber splash sound for comparison. Exact Fishing Bobber bite-sound replacement is not available because the bite timing is not exposed through the tested Lua hooks/APIs.

Sound target details are tracked in `modules/sound_levels/sounds/sound_reference.md`.

## Embedded Libraries

Embedded libraries are stored in `libs/` and documented in `sources.md`. They are vendored third-party files and are kept unmodified.

- CallbackHandler-1.0
- LibDBIcon-1.0
- LibDataBroker-1.1
- LibStub

## License

- This project is released under the MIT License.
- Embedded libraries retain their original licenses as documented in `sources.md`.
- See `LICENSE` for full details.
- Copyright (c) 2026 **LockBall**.

## Credits

- LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0 by their respective authors on WowAce / CurseForge.
- Inspired by the WoW addon community, including Elkano's BuffBars, BetterCooldownManager, ArcUI, and Angleur.
- Fishing Focus was informed by Angleur's Ultra Focus audio-profile approach.
- Addon design and implementation by **LockBall**.
- Special thanks to **DiscoMouse**.
- Portions of this addon were developed with assistance from generative tools.

## Technical Notes

- Aura scans are deferred and batched at 0.1 seconds to avoid reading protected or secret aura fields inside event dispatch.
- Preset buff classification is derived from live aura timing data and scan-local fallback state; no learned spell lists are stored.
- Frame geometry updates are skipped during combat; timers and bars continue updating, and layout catches up after combat.
- CDM cooldown icon grey state is based on real spell cooldown data and intentionally ignores the global cooldown.
- Current client interface number can be checked in chat with:

```lua
/dump (select(4, GetBuildInfo()))
```

## Sources

Project references and embedded library sources are tracked in `sources.md`.
