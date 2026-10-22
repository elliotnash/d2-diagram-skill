---
name: d2-diagrams
description: >-
  Creates professional diagrams as code with D2 (d2lang.com) and renders them
  to SVG — architecture and system diagrams, flowcharts, sequence diagrams,
  database schemas/ERDs, network and cloud topologies, C4, state machines.
  Renders with the TALA layout engine bundled in d2 0.9.0+ (ELK as fallback),
  then views its own rendered output and fixes layout defects in a loop before
  delivering. Use whenever the user wants a diagram or asks to
  visualise, map, or sketch a system, workflow, architecture, pipeline,
  schema, or process — even if they don't say "diagram" — and whenever they
  mention D2, d2lang, TALA, or diagram-as-code. Does NOT cover data charts or
  graphs (bar/line/scatter — use a plotting library) or hand-drawn Excalidraw
  JSON files.
license: MIT
compatibility: Requires the d2 CLI, minimum 0.9.0 (guided install on first use) — the first release that bundles the open-source TALA layout engine and renders PNG natively. Nothing else to install.
metadata:
  author: khollingworth
  version: "0.4.0"
---

# D2 Diagrams

Write D2 source, render it to SVG, then **look at the render and fix what you
see** — in a loop, until the diagram is worth shipping. A diagram you haven't
seen is a diagram you haven't finished.

## Reference files — load on demand

| File | Read it when |
|---|---|
| `references/d2-language.md` | Writing any non-trivial D2 — syntax, shapes, containers, classes, vars, and the silent pitfalls that compile fine but render wrong |
| `references/layout-engines.md` | Choosing or debugging layout: TALA vs ELK vs dagre, seeds, per-engine behaviour differences |
| `references/diagram-patterns.md` | Picking a diagram type and structure — architecture, sequence, ERD, grid, C4; themes, icons, dark mode, GitHub embedding |

## Step 0 — Toolchain check

Run once per session before the first render (`scripts/` here means this
skill's own directory — in Claude Code `${CLAUDE_SKILL_DIR}` resolves to it):

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup.sh" --check-only
```

- `d2: ok` → proceed. `tala: ok (bundled)` follows automatically on 0.9.0+.
- `d2: MISSING` → tell the user, then run `scripts/setup.sh` (no flags) to
  install via Homebrew where available, or show them the printed install
  commands. Don't render blind — nothing else in this skill works without d2.
- `d2: UNSUPPORTED` → the installed d2 predates 0.9.0 (no bundled TALA).
  Ask the user to upgrade (`brew upgrade d2`, or rerun the install script);
  `render.sh` refuses to run on older versions.

## Step 1 — Plan before writing

Decide three things first:

1. **The message.** What should a reader conclude in five seconds? A diagram
   argues something — "requests fan out here", "this service is the
   bottleneck", "these two paths never touch". If you can't state the
   argument, you're about to draw a labelled box collection.
2. **The type.** Architecture/topology → plain shapes and containers.
   Interaction over time → `sequence_diagram`. Data model → `sql_table`.
   Rigid alignment (matrix, dashboard, legend-heavy) → grid. See
   `references/diagram-patterns.md` for structure guidance per type.
3. **The scale.** 5–15 nodes reads well; 15–25 needs containers to cluster;
   beyond ~25, split into multiple diagrams or use `layers`. Prefer a second
   diagram over a mural.

For technical diagrams of real systems, use real names — actual service
names, actual table names, actual event names from the user's codebase or
description. Grep the code if it's available. `Service A -> Service B` wastes
the reader's trust.

## Step 2 — Write the D2

Read `references/d2-language.md` before writing anything beyond a trivial
diagram. The rules that prevent 90% of broken output:

- **Connect keys, not labels.** After `api: API Gateway`, write `api -> db`,
  never `API Gateway -> db` — the latter silently creates a duplicate shape.
- **Quote labels containing `#` or `;`** — unquoted `#` starts a comment
  mid-label and unquoted `;` splits the line into two shapes, and both
  compile without error. Quoting any punctuated label is the safe habit.
- **Style through `classes:`, not per-node styles** — one definition, applied
  with `class:`. Avoid `style.fill` on individual nodes; hard-coded fills
  fight the theme and break dark-mode rendering.
- **Set `direction: right`** for most architecture flows (left-to-right reads
  naturally). TALA (the default) treats it as a hint, not a rule —
  check the render — and additionally supports per-container `direction`.
- Save the source as `{name}.d2` next to where the output belongs
  (default: `./diagrams/` in the project).

## Step 3 — Render

Always render through the bundled script — it lays out with TALA (falling
back to ELK if TALA fails), enforces the d2 version floor, and validates
first:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/render.sh" --png input.d2 output.svg
```

- `--png` also writes `output.png` — you need it for Step 4 (the Read tool
  views raster images, not SVG). A failed preview fails the run so you can't
  skip Step 4 silently; pass `--preview-optional` only when a preview is
  genuinely best-effort (then inspect the SVG another way).
- The script prints `engine:` (what actually rendered), `fallback:` (why, if
  TALA wasn't used), and `remote:` (hosts the render fetched icons/images
  from). Relay a one-line note to the user only when they asked about
  engines or a fallback happened.
- **Multi-board sources** (`layers`/`scenarios`/`steps`) render one SVG per
  board into a directory — the report says `svg: name/ (one SVG per board)`
  and previews land in `name-preview/`. Step 4 then applies to **every**
  board's PNG, and Step 5 delivers the directory.
- **If you did not write the `.d2` source yourself** (user-supplied file,
  repo checkout), render it with `--no-remote-assets` first: rendering
  fetches any remote icon/image URLs in the source and its imports, and an
  untrusted file should not trigger outbound requests. If it refuses, show
  the user the listed hosts and let them decide.
- Useful flags: `--theme N`, `--dark-theme 200` (SVG responds to the reader's
  colour scheme), `--sketch`, `--pad N`, `--seed N` (TALA re-roll),
  `--engine tala|elk|dagre` (force), `--target PATH` (one board of a multi-board source), `--no-xml-tag` +
  `--salt VALUE` (inline HTML embedding), `--elk-OPTION VALUE` (ELK spacing
  tuning, see `references/layout-engines.md`).
- On failure the script prints d2's compile error with `file:line:col` —
  fix the source at that location and re-run. If the error is unclear, check
  the pitfalls section of `references/d2-language.md`.

A forced `--engine` is never substituted: if it fails, the script fails.
Only the default (auto) mode falls back from TALA to ELK.

## Step 4 — Look at it, then fix it (not optional)

The `.d2` source says nothing about how the render actually landed — layout
is the engine's decision, not yours. Open the PNG with the Read tool and
audit it in two passes:

**Pass 1 — does it make the argument?**
- Does the eye enter where the story starts and exit where it ends?
- Is the flow direction consistent (not doubling back or reading bottom-up
  unintentionally)?
- Do the container groupings match the logical groupings you planned?
- Is the most important element visually prominent, or buried?

**Pass 2 — layout defects** (auto-layout engines produce all of these):
- Edge labels drifted far from their edge, or ambiguous about which edge
  they describe
- Edges overlapping in parallel runs, crossing through nodes or containers,
  or taking absurd detours
- Text truncated or colliding with shapes/icons
- One region cramped while another is empty; a container vastly larger than
  its contents
- Node so small its label dominates, or wildly inconsistent node sizes
- Anything you'd have to explain apologetically if you showed it to the user

**Fix with D2's levers, not pixel-pushing** (auto-layout means you change
inputs, not coordinates): change `direction`; group or regroup with
containers; shorten edge labels (long labels drift worst on ELK); merge
parallel edges into one labelled edge; move legends/titles out of flow with
`near`; split an overloaded diagram into `layers`; adjust `--pad`;
re-roll TALA with `--seed N` (try 2–3 seeds — layouts vary meaningfully); as
a last resort switch engine for this diagram's shape, e.g. `--engine elk` for
a strictly one-directional pipeline TALA keeps folding (see
`references/layout-engines.md`).

Re-render, re-view, repeat. Budget two to four render cycles — a first
render that survives both passes is rare. Done means: both passes clean, and
nothing in the image needs an apology or an explanation.

## Step 5 — Deliver

- Confirm the final `.svg` (and `.d2` source) paths — always give the user
  both; the `.d2` is the editable artefact.
- If the diagram will live in a GitHub README or docs site, offer a
  dark-mode-aware variant: re-render with `--dark-theme 200` (single SVG that
  follows the reader's colour scheme). Patterns for PNG/`<picture>` embedding
  are in `references/diagram-patterns.md`.
- If the user will iterate on the diagram themselves, mention
  `d2 --watch input.d2` for live preview in a browser.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `d2: command not found` | Run `scripts/setup.sh` (guided install) |
| `d2 X is too old — this skill requires d2 >= 0.9.0` | Upgrade d2 (`brew upgrade d2` or the install script) — older releases don't bundle TALA |
| `fallback: TALA render failed (...)` | TALA hit an error on this source; ELK rendered instead. Fine to deliver; if TALA matters, simplify the construct named in the error |
| PNG export fails, SVG fine | Re-run with `--preview-optional`, deliver the SVG, and inspect it by converting with any available SVG rasteriser |
| Icons missing from output | Icon URL returned 403/404 — remove the icon or pick another from icons.terrastruct.com; test icons early |
