# CPU Profiles

Long-term capture for LsTweeks in-game CPU profiling runs. Keep new runs in the most specific file available.

## Files

- `addon_cpu_profiles.md`: broad profiles with multiple profiler targets enabled.

- `af_cpu_profiles.md`: Aura Frames focused profiles, including the whole-addon profiler's Aura-only runs and the Aura duration probe.

- `sv_cpu_profiles.md`: Skyriding Vigor focused profiles and before/after render-path comparisons.

## In-Game Commands

Whole-addon profiler, from `internal_dev/tests_tools/addon_cpu_profile.lua`:

- `/lstprofile status`: print whether profiling is running, enabled targets, combat time, and Skyriding active time.

- `/lstprofile reset`: clear captured timings and segment counters.

- `/lstprofile start`: reset and start profiling.

- `/lstprofile report [limit]`: print the current report. `limit` is optional and controls how many rows are shown.

- `/lstprofile stop`: stop profiling and print the final report.

Typical flow:

```text
/reload
/lstprofile status
/lstprofile reset
/lstprofile start
/lstprofile report 40
/lstprofile stop
```

Aura duration probe, from `internal_dev/tests_tools/aura_frames_duration_profile.lua`:

- `/lstafprofile start`: start the focused Aura Frames duration probe.

- `/lstafprofile report`: print the focused duration report.

- `/lstafprofile stop`: stop the focused duration probe.

## Generic Report Template

Context:

| Metric | Calls | Total ms | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| `example.metric` | 0 | 0.000 | 0.0000 | 0.000 |

Conclusion:
