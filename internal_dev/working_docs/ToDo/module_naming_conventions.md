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
1. [ ] Do other modules use vague names such as `core`, `main`, `runtime`, or `functions` for files that would be clearer as `logic_*`, `*_control`, or feature-specific names?

2. [ ] Are GUI files clearly separated from runtime/data logic files?

3. [ ] Are controller/bootstrap files named consistently enough that a clean session can identify module entrypoints quickly?

4. [ ] Where a module has multiple logic files, do the names describe the owned subsystem rather than just saying runtime or logic generically?

## Fresh Session Search Commands
- Module file inventory:
  `rg --files modules`

- Likely vague file names:
  `rg --files modules | rg "(core|main|runtime|functions|logic)"`

- TOC module load order:
  `rg -n "modules\\\\" LsTweeks.toc`
