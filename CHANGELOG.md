# Changelog

All notable changes to this plugin are documented here. Versioning follows
[semver](https://semver.org): MAJOR for breaking changes, MINOR for features,
PATCH for fixes. The `version` in `.claude-plugin/plugin.json` is bumped on
every release — installed copies update only when it changes.

Release checklist: bump `plugin.json` **and** `skills/d2-diagrams/SKILL.md`
`metadata.version` together, add the entry below, run `tests/run-tests.sh`,
tag.

## [0.4.0] — 2026-10-21

TALA by default: d2 0.9.0 bundles TALA as open source, so the skill now
requires it and lays out with TALA unless told otherwise.

### Changed
- **Minimum d2 is now 0.9.0** (was 0.7.0). `render.sh` enforces it too
  (exit 3 with upgrade instructions), not just `setup.sh`. Version parsing
  now strips d2's leading `v` (previously `v0.x` compared as newer than any
  number, so the floor could never trip on real d2 output).
- `render.sh --engine auto` (the default) always uses the bundled TALA,
  falling back to ELK only if the TALA render fails; the report includes
  TALA's error.
- PNG previews use d2's built-in renderer — no headless browser download.
- CI renders every example with TALA; the non-blocking drift canary renders
  with ELK to match the committed gallery.

### Removed
- All TALA licence handling: `TSTRUCT_TOKEN`/auth-file detection, the
  post-render `UNLICENSED` watermark guard, and `--allow-watermark`.
- `setup.sh --with-tala` (TALA ships inside d2); `setup.sh` now reports
  `tala: ok (bundled)`.
- Watermark test fixtures; the release-time unlicensed-TALA smoke test.

## [0.3.0] — 2026-07-10

Hardening release: every finding from a cross-model adversarial review
(Claude + Codex, 19 findings) fixed or documented.

### Fixed
- **Multi-board sources** (`layers`/`scenarios`/`steps`): render.sh now
  detects the per-board output directory, reports it honestly
  (`svg: name/ (one SVG per board)`), scans **every** board for the TALA
  watermark, and writes PNG previews to a separate `name-preview/` directory
  — previously the reported SVG path didn't exist, the watermark guard
  silently scanned a nonexistent file, and `--png` destroyed the per-board
  SVGs.
- Forced `--engine tala` that renders a watermark now **fails** (removing the
  watermarked output) instead of being silently substituted with ELK —
  matching the documented forced-engine contract. Auto-selected TALA keeps
  the ELK fallback.
- `--png` failure now fails the run (the self-check loop depends on the
  preview); new `--preview-optional` restores best-effort behaviour.
- Input must be a `.d2` file — a D2 source named e.g. `diagram.png` can no
  longer be overwritten by its own preview.
- `--seed` validates its shape (`N` or `N,N,...`); degenerate values like
  `,,` are rejected.
- `setup.sh --with-tala` exits non-zero when the TALA install fails or can't
  be attempted.
- `setup.sh` no longer reports unverified credentials as "licensed".

### Added
- Wrapper flags: `--target`, `--no-xml-tag`, `--salt`, `--elk-*` pass-through
  — the reference docs recommended these but the wrapper rejected them.
- `--no-remote-assets`: scans the source and its local import graph and
  refuses to render if remote http(s) assets are found; all modes now surface
  fetched hosts via a `remote:` report line.
- d2 version floor: minimum 0.7.0, enforced by `setup.sh`
  (`--allow-unsupported` to override).
- `tests/run-tests.sh`: stub-engine test suite covering the watermark guard
  (positive + negative fixtures), forced-engine honesty, multi-board
  handling, preview semantics, validation, and the remote-asset scan. Runs in
  CI alongside renders on both minimum and latest d2.

### Docs
- README: headless-browser dependency of PNG self-checks stated in
  requirements; dark-mode wording corrected to opt-in; Windows (Git Bash)
  note.
- state-machine example now uses ovals, as its own pattern guide prescribes.

## [0.2.0] — 2026-07-06

- skills.sh listing: badge in README and `npx skills add khollingworth/d2-diagram-skill`
  install path (works across 17+ agents).
- Docs: install options clarified.

## [0.1.0] — 2026-07-03

Initial release.

- `d2-diagrams` skill: plan → write D2 → render → **self-check loop** (the
  agent views its own render and fixes layout defects before delivering).
- `scripts/render.sh`: SVG rendering with automatic layout-engine selection —
  TALA when installed **and** licensed, ELK otherwise; post-render watermark
  guard (never ships `UNLICENSED` output unless `--allow-watermark`);
  automatic ELK fallback on TALA version-skew failures; PNG previews;
  `--theme` / `--dark-theme` / `--sketch` / `--pad` / `--animate` / `--seed`.
- `scripts/setup.sh`: non-interactive toolchain check and guided install
  (`--check-only`, `--with-tala`).
- References: D2 language essentials with verified silent-pitfall list,
  layout-engine guide with exact TALA licensing facts, diagram patterns
  (architecture, sequence, ERD, C4, themes, dark mode, icons).
- Five self-checked example diagrams with sources.
