# Module Naming Conventions Review

## Scope
- Review file naming conventions across modules so future cleanups do not need to rediscover each module boundary.
- Focus on logic/runtime/controller/GUI file names and whether they communicate responsibility clearly.

## Audio Volumes Reference
- Audio Volumes now uses explicit logic naming:
  - `av_logic_main.lua`: main Audio Volumes runtime logic for replacement playback, mutes, previews, event cache, and lifecycle cleanup.
  - `av_logic_situations.lua`: Situations logic for Fishing, Combat, Quick Picks, custom situation data, previews, and temporary/manual CVar profile behavior.
  - `av_gui_situations.lua`: Situations settings tab UI only.
  - `av_main.lua`: module entrypoint/controller/bootstrap.
- This split was chosen over a broad `av_logic.lua` because broad logic files hide responsibility boundaries.

## Review Questions
1. [x] Do other modules use vague names such as `core`, `main`, `runtime`, or `functions` for files that would be clearer as `logic_*`, `*_control`, or feature-specific names?

2. [x] Are GUI files clearly separated from runtime/data logic files?

3. [x] Are controller/bootstrap files named consistently enough that a clean session can identify module entrypoints quickly?

4. [x] Where a module has multiple logic files, do the names describe the owned subsystem rather than just saying runtime or logic generically?


## Review Findings
- Entrypoints are consistent: module bootstrap/controller files use `<prefix>_main.lua` (`av_main.lua`, `af_main.lua`, `ob_main.lua`, `pf_main.lua`, `sv_main.lua`, `st_main.lua`). This is clear enough for clean-session read-in.
- Audio Volumes is the clearest current pattern for a larger module: `av_logic_main.lua` and `av_logic_situations.lua` split runtime responsibility, `av_gui*` files are UI-only, and `av_main.lua` stays the controller/bootstrap.
- Objectives file names are feature-specific and clear (`ob_auto_collapse.lua`, `ob_section_count.lua`, `ob_background.lua`). These files intentionally mix their feature runtime and GUI because each feature is small and self-contained; no rename needed unless the files grow further.
- Skyriding Vigor names are mostly subsystem-specific (`sv_bar.lua`, `sv_fade.lua`, `sv_state.lua`, `sv_styles.lua`, `sv_gui.lua`, `sv_main.lua`). No immediate rename needed.
- Player Frame is small enough that `pf_main.lua` plus `pf_fade.lua` is readable. If more Player Frame features are added, split `pf_main.lua` into feature-specific files before adding broad logic/runtime names.
- Aura Frames no longer has the vague `af_core.lua` ownership bucket. It was split into `af_logic_ticker.lua`, `af_logic_native_visibility.lua`, and `af_logic_main.lua` so the file names describe ticker work, Blizzard/native frame visibility suppression, and the main per-frame aura refresh pipeline.
  - `af_functions.lua` is a broad shared-helper bucket. Its current ownership includes CDM viewer lookup, frame positioning, custom frame setup, frame/category setting fallback resolution, aura cancellation, and timer behavior helpers. Prefer splitting future work by subsystem rather than adding more helpers here; possible future names are `af_frame_helpers.lua`, `af_settings_helpers.lua`, `af_cancel.lua`, and `af_timer_helpers.lua`.


## Recommended Follow-Up
- Treat `audio_volumes` as the naming reference for future large-module cleanup: `<prefix>_logic_<subsystem>.lua`, `<prefix>_gui_<view>.lua`, `<prefix>_defaults.lua`, and `<prefix>_main.lua`.
- Any future Aura Frames helper split should keep `LsTweeks.toc`, `code_map.md`, `proj_mem/modules/aura_frames.md`, and source/docs references aligned.
- Do not rename small self-contained feature files just to force the Audio Volumes pattern; use the pattern when a module has multiple runtime subsystems or a broad file starts hiding ownership.

## Fresh Session Search Commands
- Module file inventory:
  `rg --files modules`

- Likely vague file names:
  `rg --files modules | rg "(core|main|runtime|functions|logic)"`

- TOC module load order:
  `rg -n "modules\\\\" LsTweeks.toc`
