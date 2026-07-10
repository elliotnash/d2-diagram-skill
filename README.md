# D2 Diagrams for Claude Code

[![skills.sh](https://skills.sh/b/khollingworth/d2-diagram-skill)](https://skills.sh/khollingworth/d2-diagram-skill)

**Ask for a diagram, get a professional SVG — checked by the agent's own eyes before you see it.**

A Claude Code plugin that gives Claude a complete [D2](https://d2lang.com) diagramming capability: it writes diagram-as-code, renders SVG with the best layout engine available on your machine (**TALA** if you have a licence, **ELK** otherwise — automatically), then **views its own render and fixes layout defects in a loop** before delivering. No more edge spaghetti shipped sight-unseen.

![Example architecture diagram rendered by this plugin](examples/microservices.svg)

*All diagrams on this page were generated and self-checked by the plugin. They adapt to your colour scheme — try dark mode.*

## Why this exists

- **Diagram-as-code that's actually reviewed.** LLMs are good at writing D2 and bad at knowing how it will look. This plugin closes the loop: render → view → fix → repeat (typically 2–4 iterations) using a defect checklist for edge tangles, label drift, unbalanced composition, and truncated text.
- **TALA when you have it, ELK when you don't.** [TALA](https://terrastruct.com/tala) is Terrastruct's proprietary layout engine, purpose-built for architecture diagrams. The render script detects it, verifies your licence, and **never silently ships a watermarked SVG** — it falls back to bundled ELK instead.
- **SVG-first.** Crisp at every zoom, dark-mode capable (a single SVG responds to `prefers-color-scheme` when rendered with `--dark-theme`, as every diagram on this page was), embeddable in READMEs and docs sites.

## Install

**As a plugin (recommended — versioned updates):**

```
/plugin marketplace add khollingworth/d2-diagram-skill
/plugin install d2-diagrams@d2-diagram-skill
```

**As a bare skill (copy-paste):**

```bash
git clone https://github.com/khollingworth/d2-diagram-skill.git
cp -r d2-diagram-skill/skills/d2-diagrams ~/.claude/skills/
```

**Via [skills.sh](https://skills.sh/khollingworth/d2-diagram-skill) (works across 17+ agents):**

```bash
npx skills add khollingworth/d2-diagram-skill
```

**Requirements:** the [d2 CLI](https://d2lang.com/tour/install), minimum 0.7.0 — the skill checks for it and guides the install (`brew install d2`, or `curl -fsSL https://d2lang.com/install.sh | sh -s --`). ELK ships inside d2, so SVG rendering needs nothing else; the **PNG self-inspection step downloads a headless browser on first use** (offline, the skill falls back to SVG-only delivery). On Windows the scripts run through Claude Code's Git Bash — no extra setup.

## Use it

Just ask:

> *"Diagram the architecture of this repo"*
> *"Draw the checkout flow as a sequence diagram"*
> *"Turn these CREATE TABLE statements into an ERD"*
> *"Visualise our incident process as a flowchart"*

Claude plans the diagram, writes the `.d2` source, renders it, inspects the result, fixes what looks wrong, and hands you both the SVG and the editable `.d2`.

## Examples

Sources for every example are in [`examples/`](examples/) — click any diagram to open it full size.

**Entity-relationship diagram** (`sql_table`)

[![ERD](examples/erd-commerce.svg)](examples/erd-commerce.svg)

**State machine**

[![State machine](examples/state-machine.svg)](examples/state-machine.svg)

**Sequence diagram**

<p align="center"><a href="examples/sequence-checkout.svg"><img src="examples/sequence-checkout.svg" width="620" alt="Sequence diagram"></a></p>

**Incident flowchart**

<p align="center"><a href="examples/flowchart-incident.svg"><img src="examples/flowchart-incident.svg" width="440" alt="Incident flowchart"></a></p>

## TALA and licensing — the honest version

| Component | Licence | Cost |
|---|---|---|
| This plugin | MIT | Free |
| D2 + ELK + dagre | MPL-2.0 (open source) | Free |
| TALA layout engine | Proprietary (Terrastruct) | Free **evaluation with watermark**; paid licence for clean output ([pricing](https://terrastruct.com/tala)) |

The plugin works fully without TALA — ELK produces good layouts and is what renders the gallery above. If TALA is installed (`brew install terrastruct/tap/tala`) **and** licensed (`TSTRUCT_TOKEN` env var or `~/.config/tstruct/auth.json`), it is used automatically for better architecture layouts. If TALA is installed but unlicensed, the render script detects the watermark and re-renders with ELK — you never get surprise `UNLICENSED COPY` stamps in deliverables (pass `--allow-watermark` to evaluate TALA deliberately). TALA is **not** bundled with this plugin and never will be; install it from Terrastruct under their terms. Note: running TALA in CI/servers requires a Terrastruct Enterprise licence — this repo's CI renders with ELK.

## How the self-check loop works

1. **Validate + render** via `scripts/render.sh` — engine auto-selection, watermark guard, `file:line:col` compile errors fed back to the model.
2. **View** — the agent Reads the PNG preview of its own render.
3. **Audit** — two passes: does the diagram make its argument? then a defect checklist (label drift, edge tangles, crossing edges, cramped-vs-empty regions, truncated text).
4. **Fix at the source level** — direction, containers, shorter labels, `near`, TALA seed re-rolls — never pixel-pushing.
5. **Repeat** until clean, then deliver SVG + source.

## Troubleshooting

| Problem | Fix |
|---|---|
| `d2: command not found` | `brew install d2` or `curl -fsSL https://d2lang.com/install.sh \| sh -s --` |
| Output has an `UNLICENSED COPY` watermark | You passed `--allow-watermark` (TALA evaluation), or rendered with raw `d2 --layout tala` outside the plugin's render script — set `TSTRUCT_TOKEN` for clean TALA output |
| TALA installed but ELK used | No licence found — that's the designed fallback. Set `TSTRUCT_TOKEN` or the auth file |
| PNG preview fails, SVG fine | First PNG render downloads a headless browser; retry once |
| Icons missing in output | Some icons.terrastruct.com URLs 403 — remove or swap the icon |

## Credits

- [D2](https://github.com/terrastruct/d2) and [TALA](https://github.com/terrastruct/TALA) by Terrastruct.
- D2 rendering conventions informed by [claude-d2-diagrams](https://github.com/heathdutton/claude-d2-diagrams) by Heath Dutton (MIT).
- The render-and-self-check loop pattern — and the "a diagram should make an argument" planning discipline — were pioneered for Excalidraw by [Cole Medin](https://github.com/coleam00/excalidraw-diagram-skill); this plugin adapts both to D2, where native CLI rendering removes the browser/CDN dependency chain from diagram delivery (a headless browser is still downloaded once for the agent's raster self-checks).

## Licence

MIT — see [LICENSE](LICENSE). TALA is separately and proprietarily licensed by Terrastruct; this plugin only detects and invokes a TALA installation you provide.
