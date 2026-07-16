# Performance baseline

This baseline prevents architecture changes from being justified by feel alone. It is intentionally small and should be repeated after calendar density, drag/resize, recurrence projection, or rendering strategy changes.

## July 16, 2026

Environment:

- Native SDK 0.5.1 at published tag commit `f7aa92a`
- Zig 0.16.0, `ReleaseFast`, automation enabled
- macOS on Apple Silicon
- 1,710 × 1,073 logical-pixel window at 2× scale
- Seven structural interactions: week/month changes, period navigation, timeline wheel input, and two sidebar toggles

View bounds and correctness:

- 221 / 1,024 widget nodes in week view
- 194 / 1,024 semantic nodes
- 172 canvas commands
- 0 dispatch errors and 0 dropped trace records
- Canvas command budget healthy; no present fallback
- First frame latency: 0.769 ms against the SDK's 150 ms startup budget

Frame-stage timings:

| Stage | p50 | p90 |
| --- | ---: | ---: |
| Model/view rebuild | 0.140 ms | 0.223 ms |
| Layout | 0.658 ms | 1.360 ms |
| Reconcile | 0.955 ms | 1.766 ms |
| Encode | 0.114 ms | 0.144 ms |
| Host draw | 11.794 ms | 25.819 ms |
| Present | 12.226 ms | 26.485 ms |

The final sampled input latency was 15.755 ms against a 16.667 ms budget. This is a feasibility signal, not a parity claim: seven interactions are too few for a stable percentile, and the host-draw p90 exceeds one 60 Hz frame.

## Interpretation

The typed Zig core, rebuild, layout, and reconciliation stages are not the current bottleneck. Host drawing dominates this scene. There is no evidence yet that replacing `.native` markup, native scroll behavior, or the SDK-owned build graph would improve the product enough to justify the complexity.

The next performance proof should drive continuous wheel scrolling and event dragging for several hundred frames at representative 2× window sizes, then compare host-draw and end-to-end input-latency percentiles. Profile `ReleaseFast`; debug builds intentionally include hot-reload/runtime-markup machinery and produced a misleading 46.5 ms input sample in this pass.
