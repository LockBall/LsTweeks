# Dropdown Hover Arrow
## Completed 2026-06-27
- Shared dropdown hover indicators are owned by `functions/dropdown.lua` through
  `addon.CreateDropdown()`, so every shared dropdown gets the same behavior.
- Accepted asset: `Interface\ChatFrame\ChatFrameExpandArrow`.
- Presentation: `15x15`, anchored directly below the dropdown with `0` px
  vertical offset, rotated 90 degrees clockwise with 8-point
  `Texture:SetTexCoord()`.
- Reusable asset details are also recorded in `media/media_notes.md`.
- Rejected attempts:
  - Text glyphs rendered as an empty box.
  - `Interface\Buttons\UI-SortArrow` was too thin and barely visible.
  - `Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up` and
    `Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down` render as a small gold
    arrow inside button-frame art, so they are too button-like for the dropdown
    hover indicator.
