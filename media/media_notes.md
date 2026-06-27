# Media Notes

## Blizzard UI Assets

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
