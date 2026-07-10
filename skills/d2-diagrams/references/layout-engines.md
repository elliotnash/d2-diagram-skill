# Layout Engines: TALA, ELK, dagre

`scripts/render.sh --engine auto` (the default) already implements the right
policy: **TALA if installed and licensed, otherwise ELK**. This file explains
the trade-offs so you can override deliberately.

## The three engines

| | dagre | ELK | TALA |
|---|---|---|---|
| Ships with d2 | yes (default) | yes | no — separate proprietary install |
| Style | hierarchical, fast | layered, orthogonal edges | whiteboard-like, built for software architecture |
| `sql_table` FK edges | to the table | **to the exact row** | to the exact row |
| `direction` | global only | global only | global **and per-container** |
| `near: <shape-id>`, `top`/`left` pixel locking | no | no | **yes** |
| Cost | free (MPL-2.0 d2) | free (bundled) | paid licence; free eval renders a watermark |

**When ELK wins:** flowcharts, pipelines, anything with a strong single
direction; CI (no licence needed); deterministic output.

**When TALA wins:** architecture diagrams with containers — it treats
containers as first-class at every layout stage, routes orthogonally, places
edge labels to avoid collisions, and balances connection ports. If the
diagram looks like a whiteboard system sketch, TALA will lay it out better.

**dagre** is the d2 default but the weakest for our purposes — only use it
when reproducing someone's existing dagre-based output.

## TALA licensing — the facts

- Free to **evaluate**; unlicensed renders succeed (exit 0) but embed an
  `UNLICENSED COPY` watermark in the SVG — there is no reliable stderr signal,
  which is why the post-render watermark scan exists.
- Licence key: env var `TSTRUCT_TOKEN` (format `tstruct_...`), or
  `~/.config/tstruct/auth.json` containing `{"api_token": "tstruct_..."}`
  (path overridable via `TSTRUCT_AUTHFILE`). There is no licence-status
  command — presence of token/auth-file is the only pre-render check, which
  is why `render.sh` also greps the output for `UNLICENSED` afterwards.
- Purchase at <https://terrastruct.com/tala>. **Server/CI use requires an
  Enterprise licence** — never put `TSTRUCT_TOKEN` into CI to "fix" the
  watermark; render with ELK in CI instead.
- **Never bundle or redistribute** `d2plugin-tala` — Terrastruct's terms
  prohibit it. Users install it themselves:
  `brew install terrastruct/tap/tala` or
  `curl -fsSL https://d2lang.com/install.sh | sh -s -- --tala`.
- TALA phones home only to verify the token; diagrams never leave the machine.

## Detection (what render.sh does)

- Installed? `command -v d2plugin-tala` (d2 discovers plugins by scanning
  `$PATH` for `d2plugin-*`). `d2 layout tala` exits 0 with info when present,
  1 with a clear error when not.
- Licensed? Token/auth-file present, **plus** post-render `UNLICENSED` grep —
  a token can be expired or malformed, and TALA still renders watermarked.

## TALA seeds — the re-roll lever

Layout search is seeded; different seeds converge on genuinely different
layouts. By default TALA races seeds 1, 2, 3 and picks the best.

```bash
render.sh --engine tala --seed 7 in.d2 out.svg     # single seed
d2 --layout tala --tala-seeds 8,3,24 in.d2         # race several
```

When a TALA layout is *almost* right, re-roll 2–3 seeds before restructuring
the source — it's the cheapest fix in the loop.

## Failure modes

- `D2_LAYOUT "tala" is not bundled and could not be found in your $PATH`
  (exit 1) → TALA not installed. render.sh auto-falls back in `--engine auto`.
- Compile errors mentioning `failed to unmarshal json` under TALA → d2/TALA
  version skew. render.sh falls back to ELK when TALA was auto-picked;
  suggest the user update both (`brew upgrade d2 terrastruct/tap/tala`).
- Watermark in output despite a token → token invalid/expired; the script
  already re-rendered with ELK; tell the user their TALA token needs renewing.

## ELK tuning (rarely needed)

`--elk-nodeNodeBetweenLayers 70`, `--elk-padding "[top=50,left=50,bottom=50,right=50]"`,
`--elk-edgeNodeBetweenLayers 40` — try only when a specific spacing problem
survives the source-level fixes in SKILL.md Step 4. The render script passes
`--elk-*` flags through, so these work without bypassing the wrapper.
