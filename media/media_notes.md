# Media Notes
## Blizzard UI Assets
- Native play button:
  - Normal texture: `Interface\Buttons\UI-SpellbookIcon-NextPage-Up`
  - Pressed texture: `Interface\Buttons\UI-SpellbookIcon-NextPage-Down`
  - Disabled texture: `Interface\Buttons\UI-SpellbookIcon-NextPage-Disabled`
  - Highlight texture: the button art itself with `ADD` blend (self-glow; gold regions brighten, dark plate stays dark). `UI-Common-MouseHilight` and `UI-Minimap-ZoomButton-Highlight` both render as blue glows and do not fit this art.
  - Pause texture: `Interface\TimeManager\PauseButton` tinted gold `0.84, 0.81, 0.52` (stopwatch pause glyph; same pairing retail AddonProfiler uses with the NextPage play art).
  - Current use: `addon.CreatePlayPauseButton()` in `functions/buttons.lua` swaps the whole normal/pushed/disabled texture set between play and pause states. Apply these directly to a plain `Button`; do not layer them inside a standard button template because the native play art already includes its own square surround.
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
