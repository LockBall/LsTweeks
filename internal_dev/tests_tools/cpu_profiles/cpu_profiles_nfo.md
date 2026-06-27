# CPU Profiles
Long-term capture for LsTweeks in-game CPU profiling runs. Keep new runs in the most specific file available.


## Table of Contents
- [Files](#files)
- [Analysis Scripts](#analysis-scripts)
- [In-Game Commands for `/lstprofile <option>`](#in-game-commands-for-lstprofile-option)
- [Generic Report Template](#generic-report-template)


## Files
- `addon_cpu_profiles.md`: broad profiles with multiple profiler targets enabled.
- `af_cpu_profiles.md`: Aura Frames focused profiles, including the whole-addon profiler's Aura-only runs and the Aura duration probe.
- `sv_cpu_profiles.md`: Skyriding Vigor focused profiles and before/after render-path comparisons.


## Analysis Scripts
- `analyze_af_cpu_profiles.ps1`: parses `af_cpu_profiles.md`, normalizes metrics
  by elapsed time, and normalizes `af.tick_visible_icons` to a reference ticker
  cadence so runs with different Timer Tick settings can be compared.

Aura Frames whole-addon runs should keep a metadata comment immediately below
the run heading:

```text
<!-- cpu-profile-run: elapsed=98.6 combat=97.5 timer_tick=0.15 -->
```

Use `timer_tick=unknown` when the value was not captured.


## In-Game Commands for `/lstprofile <option>`
Whole-addon profiler, from `../addon_cpu_profile.lua`

Where option is one of the following:

- `status` print whether profiling is running, enabled targets, combat time, and Skyriding active time.
- `reset`: clear captured timings and segment counters.
- `start`: reset captured timings and start profiling.
- `report [limit]`: print the current report. `limit` is optional and controls
  how many rows are shown.
- `stop`: stop profiling and print the final report.

Typical flow:

```text
/reload
/lstprofile status
/lstprofile start
/lstprofile report 40
/lstprofile stop
```

Aura duration probe, from `../aura_frames_duration_profile.lua`:

- `/lstafprofile start`: start the focused Aura Frames duration probe.
- `/lstafprofile report`: print the focused duration report.
- `/lstafprofile stop`: stop the focused duration probe.


## Generic Report Template
Context:

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `example.metric` | 0 | 0.000 | 0.0000 | 0.000 |

Conclusion:
