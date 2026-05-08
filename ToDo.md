## Remaining Work

### Aura Frames

- [ ] Consolidate remaining Aura Frames duplication.

  1. **Reassess row assembly after position controls.**

     The row order is mostly shared, but a single large builder may be less readable than the current source-specific sections.

     Current shared row shape:

     - Row 1: move mode, X position, Y position, width, Snap to Grid, Move Reset
     - Row 2: enable frame, test aura, frame background, frame background color, source-specific controls
     - Row 3: bar mode, bar color, bar text color, bar background color, growth direction
     - Row 4: timer text, timer bold, timer font, timer font size, timer color
     - Row 5: scale, spacing, max icons

     Only consolidate row assembly if the remaining duplication is clearly mechanical and the visible GUI stays unchanged.

  2. **Keep legitimate source-specific sections separate.**

     These are real source/capability differences and should not be forced into one generic path unless doing so makes the code clearer:

     - CDM controls
     - custom frame naming
     - custom filter child panels
     - static timer-control hiding
     - current label differences

### Nice To Have

- [ ] Brief guided tour.
- [ ] Portrait dim out of combat.
- [ ] Dungeon ready sound levels.
- [ ] Saves.
