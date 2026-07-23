# Background Color Synchronization

## Proposal
The feature would provide a shared background color policy that can synchronize backgrounds within one module or across all participating modules.

Use a non-destructive runtime override:
1. Each background retains its existing local color.
2. A module-level override makes every participating background in that module use one RGBA color.
3. A global override makes every participating module use one RGBA color.
4. Disabling an override reveals the original local colors again.

Color precedence:

`Global override -> Module override -> Existing local color`


## Initial Participation
- Aura Frames: frame backgrounds qualify. Bar backgrounds should be separately selectable because they serve a different visual purpose.
- Objectives: the custom center background qualifies. Blizzard's separate background-opacity control remains independent.
- Skyriding Vigor: exclude initially because its background is decorative atlas artwork rather than a flat color.
- Player Frame and Audio Volumes: no comparable runtime background currently exists.
- Addon settings-window backgrounds: exclude because they are interface chrome rather than module visuals.


## Suggested Settings
- `Use one color across all modules`
- Global RGBA color picker
- Preset selector composed from a left arrow, dropdown, and right arrow
- One entry for each participating module
- `Use one color for this module`
- Module RGBA color picker
- Aura Frames target choices: `Frame backgrounds` and `Bar backgrounds`


## Color Presets
Offer the same ordered preset selector beside each global or module color picker:

`Red -> Orange -> Yellow -> Green -> Blue -> Indigo -> Violet -> Black -> White -> Grey`

- Match WoW's native cycling-dropdown layout: a previous-page art button, a wide clickable dropdown that opens the full option list and retains its own hover arrow below, and a next-page art button.
- Use Blizzard's Spellbook previous/next page texture family. The existing shared play button already uses the next-page art; add a focused shared page-arrow button helper instead of using text glyphs or giving the selector play/pause semantics.
- The dropdown selects a preset directly.
- Left and right arrows cycle through the ordered list and wrap at either end.
- Presets replace RGB while preserving the current alpha.
- Manual color-picker edits that do not match a preset display as `Custom`.
- From `Custom`, the right arrow starts at Red and the left arrow starts at Grey.
- Preset selection changes only the active override color; it does not enable that override.


## Architecture
Calculate an effective runtime color instead of copying the selected color into every module setting. Bulk copying would destroy individually configured colors and complicate profiles and resets.

Expose a small shared color-resolution service. Aura Frames and Objectives should request their effective background color while retaining responsibility for applying it. Objectives must retain its combat-safe deferred update behavior, and Aura Frames must invalidate or refresh its runtime configuration cache when the effective color changes.

Synchronization changes color only. It must not enable a background that its owning module currently hides.


## Aura Frames Participation
Support frame backgrounds and bar-track backgrounds as separate target checkboxes.
