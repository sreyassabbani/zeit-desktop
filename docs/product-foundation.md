# Product foundation

## What this pass proves

- A desktop calendar can be native-rendered without React or a WebView.
- Week and month are distinct layouts rather than one responsive grid.
- macOS owns scroll momentum while the app keeps a deterministic scroll offset.
- Calendar visibility is model state shared by the week layout and ranked compact surfaces; the provider-backed month projection is the next consumer.
- Event priority for compact surfaces is a first-class policy, not a hard-coded “next event” query.
- Provider and recurrence work can be added without changing UI-facing event identity.

## Next proof points

1. Replace the week fixture projection with real date/time-zone math and recurrence expansion while preserving the canonical event contract.
2. Add direct event creation, selection, drag, resize, keyboard navigation, and undo; profile the native markup path before introducing custom canvas rendering.
3. Graduate to owned Zig wiring for a live menu-bar status item that consumes the existing surface-ranking output.
4. Add a local encrypted store and one provider adapter behind the effect boundary. Google Calendar is the likely first adapter; keep OAuth and vendor wire types outside the core model.
5. Build a rule editor around explicit `pin`, `hide`, horizon, participation, calendar, and event-kind inputs, with an explanation for every ranked result.

Mobile remains a later consumer of the same normalized event and surface-policy vocabulary. It is not part of the current performance/UI proof.
