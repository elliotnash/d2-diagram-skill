# Layout Engines: TALA, ELK, dagre

`scripts/render.sh --engine auto` (the default) lays out with **TALA**, and
re-renders with ELK only if the TALA render fails. This file explains the
trade-offs so you can override deliberately.

Since d2 0.9.0 (the minimum this skill supports), TALA is open source and
bundled inside d2 itself: no plugin, no licence key, no watermark, and it is
fine to use in CI.

## The three engines

| | dagre | ELK | TALA |
|---|---|---|---|
| Ships with d2 | yes (d2's CLI default) | yes | yes (0.9.0+), opt-in via `--layout tala` |
| Style | hierarchical, fast | layered, orthogonal edges | whiteboard-like, built for software architecture |
| `sql_table` FK edges | to the table | **to the exact row** | to the exact row |
| `direction` | global only | global only | global (as a hint) **and per-container** |
| `near: <shape-id>`, `top`/`left` pixel locking | no | no | **yes** |

**When TALA wins (the default):** architecture diagrams with containers — it
treats containers as first-class at every layout stage, routes orthogonally,
places edge labels to avoid collisions, and balances connection ports. If the
diagram looks like a whiteboard system sketch, TALA lays it out better.

**When ELK wins:** flowcharts, pipelines, long single-direction chains. TALA
treats root-level `direction` as a hint and will fold a long chain to balance
the aspect ratio; if the reader must see one unbroken left-to-right (or
top-to-bottom) flow and seed re-rolls don't deliver it, use `--engine elk`.

**dagre** is d2's CLI default but the weakest for our purposes — only use it
when reproducing someone's existing dagre-based output.

## Detection (what render.sh does)

- `d2 --version` must be ≥ 0.9.0, otherwise render.sh exits 3 (older
  releases need a separately installed, licensed TALA plugin, which this
  skill no longer handles). `setup.sh --check-only` reports the same.
- `d2 layout tala` lists TALA as `tala (bundled)` and its options.

## TALA seeds — the re-roll lever

Layout search is seeded; different seeds converge on genuinely different
layouts. By default TALA races seeds 1, 2, 3 and picks the best.

```bash
render.sh --seed 7 in.d2 out.svg                   # single seed
render.sh --seed 8,3,24 in.d2 out.svg              # race several
```

Seeds can also live in the source (`vars: {d2-config: {data: {tala-seeds:
[8; 3; 24]}}}`) or the `D2_TALA_SEEDS` env var; in-diagram seeds take
precedence over the flag. When a TALA layout is *almost* right, re-roll 2–3
seeds before restructuring the source — it's the cheapest fix in the loop.
`--seed` is ignored on ELK and dagre.

## Failure modes

- `d2 X is too old — this skill requires d2 >= 0.9.0` (exit 3) → upgrade d2:
  `brew upgrade d2`, or `curl -fsSL https://d2lang.com/install.sh | sh -s --`.
- `fallback: TALA render failed (...)` → TALA errored on this source and
  render.sh re-rendered with ELK. The SVG is fine to deliver; the first line
  of TALA's error is in the report if you want to work around it.
- A forced `--engine tala` that fails exits 1 — forced engines are never
  substituted.

## ELK tuning (rarely needed)

`--elk-nodeNodeBetweenLayers 70`, `--elk-padding "[top=50,left=50,bottom=50,right=50]"`,
`--elk-edgeNodeBetweenLayers 40` — try only when a specific spacing problem
survives the source-level fixes in SKILL.md Step 4. The render script passes
`--elk-*` flags through, so these work without bypassing the wrapper.
