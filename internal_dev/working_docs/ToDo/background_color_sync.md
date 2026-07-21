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
- One entry for each participating module
- `Use one color for this module`
- Module RGBA color picker
- Aura Frames target choices: `Frame backgrounds` and `Bar backgrounds`


## Architecture
Calculate an effective runtime color instead of copying the selected color into every module setting. Bulk copying would destroy individually configured colors and complicate profiles and resets.

Expose a small shared color-resolution service. Aura Frames and Objectives should request their effective background color while retaining responsibility for applying it. Objectives must retain its combat-safe deferred update behavior, and Aura Frames must invalidate or refresh its runtime configuration cache when the effective color changes.


## Open Decision
Decide what `all backgrounds` means inside Aura Frames:
- Frame backgrounds only
- Frame backgrounds and bar-track backgrounds

Recommended: support both as separate target checkboxes.
