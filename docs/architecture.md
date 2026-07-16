# Architecture

## Runtime shape

```text
provider payloads (future)
        |
        v
effect/adapter boundary  ---> credentials and sync cursors
        |
        v
provider-neutral domain events
        |                    \
        v                     v
occurrence projection     surface ranking
        |                     |
        v                     v
week/month layout         menu bar / widget candidates
        \                    /
         v                  v
           Native SDK Model
                  |
                  v
            .native view tree
```

The application core is pure and deterministic. `update(model, msg)` mutates one owned model through an exhaustive tagged-union switch; time, files, network, and platform services enter as typed messages at Native SDK effect boundaries. Release markup compiles at comptime, while debug builds retain runtime parsing only for hot reload.

## Existing seams

- `domain/calendar.zig` defines canonical calendars, events, occurrences, participation, availability, and explicit surface overrides.
- `domain/provider.zig` defines provider accounts, cursors, normalized records, and mutation envelopes as data. It deliberately defines no OAuth client or network implementation.
- `domain/surface_ranking.zig` scores and ranks events per surface. A user pin is decisive, a hide is exclusionary, and policy can exclude declined or all-day events.
- `layout/overlap.zig` assigns stable horizontal lanes to overlapping intervals without any UI dependency.
- `fixtures.zig` is the only source of sample content.
- `main.zig` owns navigation and visibility state and exposes derived bindings to markup.

## Deliberate limits

Provider adapters remain an effect boundary instead of service objects in the Model so network responses, credentials, clocks, and provider failures cannot make rendering nondeterministic. OAuth windows and credential storage belong in narrow platform capabilities that normalize records before dispatching them into the core.

The first calendar grid uses bounded native markup. Dragging/resizing, dense overlap rendering, and a live menu-bar status item should be evaluated against a Zig builder or retained canvas only after profiling shows the markup path is the constraint. The domain and layout types do not depend on that rendering choice.
