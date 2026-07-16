# Performance baseline

This baseline prevents architecture changes from being justified by feel alone. It is intentionally small and should be repeated after calendar density, drag/resize, recurrence projection, or rendering strategy changes.

## July 16, 2026 — continuous native scrolling

This sample follows the adjacent-period refactor: three week pages share one horizontal AppKit scroll region, each timeline keeps its own vertical AppKit region, and three month pages share one vertical region. Scroll offsets stay in retained runtime state; ordinary wheel and momentum samples dispatch no model message and perform no view rebuild, layout, or reconcile work.

Environment:

- Native SDK 0.5.1 at published tag commit `f7aa92a`, with Zeit's pinned horizontal-scroll patch
- Zig 0.16.0, `ReleaseFast`, automation enabled
- macOS on Apple Silicon
- 1,710 × 1,073 logical-pixel window at 2× scale
- Six horizontal week steps and ten vertical timeline wheel steps after profile reset

View bounds and correctness:

- 469 / 1,024 widget nodes in week view
- 396 / 1,024 semantic nodes
- 274 canvas commands
- 0 dispatch errors and 0 dropped trace records
- Canvas command budget healthy; no present fallback
- First frame latency: 0.683 ms against the SDK's 150 ms startup budget

Frame-stage timings:

| Stage | p50 | p90 |
| --- | ---: | ---: |
| Model/view rebuild | 0 ms | 0 ms |
| Layout | 0 ms | 0 ms |
| Reconcile | 0 ms | 0 ms |
| Display-list emit | 0.727 ms | 1.325 ms |
| Encode | 0.073 ms | 0.138 ms |
| Host draw | 10.017 ms | 11.332 ms |
| Present | 10.478 ms | 11.796 ms |

The final sampled input latency was 15.081 ms against a 16.667 ms budget. File-driven automation produced a 29.445 ms frame-interval p90, so this is a regression guard rather than a physical-trackpad percentile. The actual render stages remained inside one 60 Hz frame.

## Interpretation

The per-tick Model/update/rebuild loop was the avoidable lag source. Native AppKit scroll drivers now own offsets and momentum, and the profiler records zero rebuild, layout, or reconcile samples across the scroll sequence. Host drawing still dominates, but its sampled p90 is now below the 16.667 ms frame budget despite mounting adjacent periods.

The next performance proof should replay physical-feeling momentum for several hundred frames, then add event dragging and resizing at representative 2× window sizes. Profile `ReleaseFast`; Debug builds intentionally include hot-reload/runtime-markup machinery and remain useful for iteration, not feel comparisons.
