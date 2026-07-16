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

The application core is pure and deterministic. `update(model, msg)` returns a new immutable model; time, files, network, and platform services enter as messages produced by Native SDK effects. The TypeScript core is compiled into native Zig with fixed frame and model arenas.

## Existing seams

- `domain/calendar.ts` defines canonical calendars, events, occurrences, participation, availability, and explicit surface overrides.
- `domain/provider.ts` defines provider accounts, cursors, normalized records, and mutation envelopes as data. It deliberately defines no OAuth client or network implementation.
- `domain/surface-ranking.ts` scores and ranks events per surface. A user pin is decisive, a hide is exclusionary, and policy can exclude declined or all-day events.
- `layout/overlap.ts` assigns stable horizontal lanes to overlapping intervals without any UI dependency.
- `fixtures.ts` is the only source of sample content.
- `core.ts` owns navigation and visibility state and exposes derived bindings to markup.

## Deliberate limits

The Native SDK TypeScript core cannot import arbitrary npm packages or run async functions; that is why provider adapters are an effect boundary instead of service objects in the Model. Simple HTTP can use `Cmd.fetch`, but OAuth windows, credential storage, and mature provider SDKs may justify owned Zig wiring or a narrow host command adapter later.

The first calendar grid uses bounded native markup. Dragging/resizing, dense overlap rendering, and a live menu-bar status item should be evaluated against a Zig builder or retained canvas only after profiling shows the markup path is the constraint. The domain and layout types do not depend on that rendering choice.
