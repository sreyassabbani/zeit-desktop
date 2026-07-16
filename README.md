# Zeit Desktop

Zeit is an experimental, macOS-first calendar built with Vercel Labs' Native SDK. Its UI is native-rendered markup over a strictly typed Zig core. The release binary ships no React, WebView, JavaScript runtime, or runtime markup parser.

The first pass establishes two real calendar layouts, deterministic fixture data, native scrolling, provider-neutral event contracts, overlap geometry, and a surface-ranking seam for future menu-bar and desktop widgets. Provider authentication and sync are intentionally not implemented yet.

## Start

```sh
direnv allow
native doctor
native dev
```

Use `nix develop` in environments without direnv. The flake pins Zig and builds the Native SDK 0.5.1 CLI directly from its pinned source; no package-manager install step is required.

## Verify

```sh
native test
native check
native build
```

The sequence runs pure Zig tests, typed markup/manifest validation, and a ReleaseFast build.

## Why this stack

- `.native` markup gives native controls, accessibility semantics, macOS `NSScrollView` momentum, and hot reload without React reconciliation.
- Zig tagged unions, enums, optionals, exhaustive switches, and explicit ownership keep the entire model statically typed without a transpilation layer or JavaScript engine.
- Provider work stays outside the render model. Future adapters normalize Google, Microsoft, CalDAV, and local data into provider-independent records through an effects boundary.
- The project stays on the SDK-owned build graph (`app.zon` + `src/`) with no custom `build.zig`. The Zig entry point already leaves room for a live model-derived menu-bar status item.

See [architecture.md](docs/architecture.md) for the seams that are already in place, [product-foundation.md](docs/product-foundation.md) for the first-pass scope, and [performance-baseline.md](docs/performance-baseline.md) for measured limits and the next profiling target.
