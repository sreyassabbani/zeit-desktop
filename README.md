# Zeit Desktop

Zeit is an experimental, macOS-first calendar built with Vercel Labs' Native SDK. Its UI is native-rendered markup over a strictly typed TypeScript core that is compiled ahead of time to Zig. The release binary ships no React, WebView, or JavaScript runtime.

The first pass establishes two real calendar layouts, deterministic fixture data, native scrolling, provider-neutral event contracts, overlap geometry, and a surface-ranking seam for future menu-bar and desktop widgets. Provider authentication and sync are intentionally not implemented yet.

## Start

```sh
direnv allow
bun install
bun run doctor
bun run dev
```

Use `nix develop` in environments without direnv. The flake pins Bun, Node, Zig, and the other command-line tools; the Bun lockfile pins Native SDK 0.5.1.

## Verify

```sh
bun run verify
```

`verify` runs TypeScript and Native SDK checks, pure unit tests, the generated native test suite, and a ReleaseFast build.

## Why this stack

- `.native` markup gives native controls, accessibility semantics, macOS `NSScrollView` momentum, and hot reload without React reconciliation.
- The Native SDK TypeScript core is a deterministic closed subset compiled to arena-backed Zig. Readonly domain records and discriminated messages remain pleasant to model without shipping a JS engine.
- Provider work stays outside the render model. Future adapters normalize Google, Microsoft, CalDAV, and local data into provider-independent records through an effects boundary.
- The project stays zero-config (`app.zon` + `src/`) for now. A custom Zig wiring layer is reserved for features that actually need it, notably a live model-derived menu-bar status item.

See [architecture.md](docs/architecture.md) for the seams that are already in place and [product-foundation.md](docs/product-foundation.md) for the first-pass scope and next proof points.
