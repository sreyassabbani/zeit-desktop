# Agent Notes

## Product intent

Zeit is a macOS-first personal calendar for people whose calendar needs to help allocate attention, not merely mirror provider data. The immediate quality bar is the density, directness, scrolling, and week/month clarity of Notion Calendar. The differentiator begins with explicit rules for which events surface in menu-bar and desktop widgets.

Desktop UI, interaction quality, and performance come first. Do not add mobile, login, provider sync, a backend, React, or a WebView unless the task explicitly calls for it. The current app is native-rendered Native SDK markup over a TypeScript core that compiles ahead of time to Zig; no JavaScript runtime ships in the app.

## Environment

- Glance at `flake.nix` once at the start of work so the pinned environment is understood before running project commands.
- Enter the pinned shell with `direnv allow` or `nix develop`.
- Bun, Node, Zig, and the Native SDK CLI are pinned by `flake.lock` and `bun.lock`. Do not install host-global tooling.
- Run project commands through Bun so `node_modules/.bin` resolves consistently: `bun run dev`, `bun run check`, `bun run test`, and `bun run build`.
- `NATIVE_SDK_SKILLS_ROOT` is set in `flake.nix` because the npm platform wrapper otherwise cannot find the CLI's version-matched skill data.

## Native SDK workflow

Native SDK is pre-1.0 and its checked-out examples can drift from the installed CLI. Before changing an unfamiliar SDK surface, load the installed 0.5.1 guidance rather than guessing:

```sh
bun run skills:native:core
bun run skills:native:ts
bun run skills:native:ui
bun run skills:native:automation
```

The repository discovery skill lives at `.agents/skills/native-sdk/SKILL.md`. Prefer zero-config app ownership (`app.zon` + `src/`) until a feature genuinely requires a custom `build.zig`. A live, model-derived menu-bar status item is one likely reason to graduate to owned Zig wiring later.

After changing the Model or Msg shape, run `bun run test:native` before trusting markup errors from `native check`; the typed markup validator reads the last generated model contract. Run both `native test` and `native build` because Zig's lazy analysis can expose different paths.

## Architecture boundaries

- `src/domain/` owns provider-independent calendar types, provider wire contracts, and surface-ranking policy.
- `src/layout/` owns pure calendar geometry. Keep timestamps and recurrence data out of pixels; project occurrences into local layout data first.
- `src/fixtures.ts` is deterministic sample data, not a mock provider embedded in UI code.
- `src/core.ts` is the Native SDK entry contract: Model, Msg, update, host-event channels, and exported view bindings.
- `src/app.native` is presentation. It may bind derived helpers but must not implement calendar policy or provider normalization.
- Provider adapters must normalize into domain records at an effect boundary. Google, Microsoft, CalDAV, and local-store response shapes must never appear in the UI model.
- Derive view data instead of storing it twice. Use stable numeric ids, readonly records, tagged unions, and exhaustive message switches.
- Keep unbounded collections virtualized and respect Native SDK's fixed arena/model capacities and 1,024-node view budget.

## Interaction and design guardrails

- The calendar grid is the primary visual object. Avoid dashboard cards, ornamental gradients, oversized headings, and stacked containers.
- Use the system typeface, the Geist native theme, a 4-point spacing rhythm, native focus behavior, and OS appearance/reduced-motion channels.
- Preserve native scrolling: do not replace the SDK scroll region or attach per-wheel update logic without evidence.
- Every pointer action needs a keyboard path before it is called complete. Do not encode meaning with color alone.
- Motion must clarify navigation, selection, dragging, or resizing. Prefer 100–150 ms feedback and 200–300 ms state changes; reduced motion must remain functional.

## Verification and collaboration

- Unit-test ranking and layout rules in `tests/`; run `bun run verify` before handoff.
- Use Native SDK automation snapshots, screenshots, interaction commands, and frame profiling for UI changes. Check `dispatch_errors=0`, node count, scroll state, and frame-stage timings.
- If subagents are used, run no more than three at once. Give each one a bounded file or verification objective plus a deterministic stop condition, and point it to the relevant installed Native SDK skill first.
- Preserve unrelated user changes and never rewrite generated lockfiles by hand.

Use Hunk for code review. Start with `hunk diff`, or attach to a live review with `hunk session review --repo . --json`.

## Git

- Commit regularly at coherent, verified checkpoints.
- Prefer subsystem-first subjects such as `cli:`, `state:`, `tui:`, `api:`, `docs:`, `nix:`, `test:`, or a narrower module people would search for later.
- Do not default to Conventional Commit subjects such as `feat(...)`, `fix(...)`, or `chore(...)`.
- Keep messages compact. A small commit may contain only a subject line.
- Add a body only when the reason, tradeoff, or implementation detail matters; explain why or how rather than repeating the subject.
- Use backticks for paths, commands, package names, settings, and other literal identifiers when they improve scanability.
- Do not force a fixed number of body bullets.
