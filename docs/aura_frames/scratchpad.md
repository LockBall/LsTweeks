
1. [todo] Aura frame tree node pooling
   `modules/aura_frames/af_gui.lua`: `rebuild_tree()` still calls `CreateFrame` on each expand/collapse. Pool tree rows or lazy-build and hide/reuse nodes instead.

2. [todo] Short-order render pass cleanup
   `modules/aura_frames/af_render.lua`: consider merging the pass that populates `_short_order_map` with the stale-key cleanup pass.

----

error was result of CLEU issue
on reload, a window is immediately displayed with a message and 2 buttons, disable, ignore

LsTweeks has been blocked from an action only available tot he Blizzard UI. You can disable this addon and relaod the UI.


