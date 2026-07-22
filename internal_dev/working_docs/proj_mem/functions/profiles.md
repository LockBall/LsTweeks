# Profiles Function Memory
Durable contracts for shared profile storage and Profiles-tab UI in `functions/profiles.lua`.


## Table of Contents
- [Ownership And API](#ownership-and-api)
- [Storage And Application Contract](#storage-and-application-contract)
- [Profiles Tab](#profiles-tab)
- [Module Boundary](#module-boundary)
- [Validation](#validation)


## Ownership And API
- `addon.CreateProfileManager(opts)` owns standard profile CRUD, selected-name tracking, defensive copies, and the combat load gate.
- Manager API: `get_profiles()`, `find(name)`, `get_selected_name()`, `set_selected_name(name)`, `save(name, overwrite)`, `delete(name)`, `rename(oldName, newName)`, and `load(name)`.
- `addon.BuildProfilesTab(parent, manager, opts)` owns the standard profile name input, saved-profile list, Save New/Overwrite/Load/Rename/Delete controls, confirmations, and status text. It returns a refresh closure that resynchronizes selection and rows from manager state.
- `test_profiles.lua` owns shared manager regression coverage; each module owns tests for its snapshot and runtime apply contract.


## Storage And Application Contract
- Resolve storage through `opts.get_db()` at operation time. Use a closure when TOC order means the provider function does not exist when the manager is constructed; capturing the current field can preserve `nil` permanently.
- Profiles live under `profiles_key` (`profiles` by default); selected UI state lives under `selected_name_key` (`last_profile_name` by default).
- `save()` trims names, rejects missing storage or invalid exports, refuses accidental overwrite, deep-copies exported data, records optional `saved_at`, and selects the saved profile.
- `load()` rejects combat, deep-copies saved data before `apply_data`, and updates selection only after a successful module apply. Saved and live tables must never share nested references.
- Delete selects the first remaining profile when deleting the active one; rename rejects blank/duplicate names and preserves active selection.
- Profile/default imports select fallback values only when a source key is `nil`; explicit `false` is saved data and must survive.
- The addon is unreleased: do not add schema-version or migration machinery. Replace incompatible local profiles instead.


## Profiles Tab
- Use `BuildProfilesTab()` instead of rebuilding CRUD controls in modules. Module GUI code stores the returned refresh closure and calls it after resets or other operations that replace/clear profile state.
- The shared tab consumes standard button and control-panel styling; their reusable contracts remain owned by `controls.md` and `functions/ui_helpers.lua`.
- Overwrite and delete require confirmation; ordinary validation failures return status messages without mutating storage.


## Module Boundary
- Modules own explicit snapshot contents, exclusions, defaults/fallback rules, and `apply_data` runtime refresh. Keep those contracts in each module's profile source and module memory.
- A module apply may replace nested DB tables. It must repair live DB references, cancel stale delayed work, synchronize controls/runtime/session flags, and remove orphan runtime/UI objects as appropriate before reporting success.
- Reset UI decides whether profiles are preserved. When reset clears `profiles` or `last_profile_name`, refresh the cached Profiles tab afterward.


## Validation
- Shared tests must prove independent deep copies, selected-name tracking, missing-storage rejection, invalid-export rejection, combat load rejection when modeled, and CRUD edge cases changed by a patch.
- Impacted module tests must prove explicit snapshot restoration, `false` preservation, and required post-load runtime/control refresh. Profile UI changes also require visual verification of selection, confirmation, and status behavior.
