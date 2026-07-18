# Media Notes
## Blizzard UI Assets
- Native play button:
  - Normal texture: `Interface\Buttons\UI-SpellbookIcon-NextPage-Up`
  - Pressed texture: `Interface\Buttons\UI-SpellbookIcon-NextPage-Down`
  - Disabled texture: `Interface\Buttons\UI-SpellbookIcon-NextPage-Disabled`
  - Highlight texture: `Interface\Buttons\UI-Common-MouseHilight` with `ADD` blend mode.
  - Current use: `addon.CreatePlayPauseButton()` in `functions/buttons.lua`. Apply these directly to a plain `Button`; do not layer them inside a standard button template because the native play art already includes its own square surround.
- Dropdown hover arrow:
  - Texture: `Interface\ChatFrame\ChatFrameExpandArrow`
  - Current use: shared dropdown factory hover indicator in
    `functions/dropdown.lua`.
  - Presentation: `15x15`, anchored directly below the dropdown with `0` px
    vertical offset, rotated 90 degrees clockwise with 8-point
    `Texture:SetTexCoord()`.
  - Source reference: Blizzard uses this as a simple submenu expand arrow in
    `Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.xml`.
- Existing icon reference: `inv_misc_enggizmos_swissarmy`
