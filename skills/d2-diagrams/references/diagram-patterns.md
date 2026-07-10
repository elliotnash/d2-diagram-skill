# Diagram Patterns, Themes, and Delivery

Contents: [Choosing a type](#choosing-a-type) · [Architecture](#architecture-diagrams) ·
[Sequence](#sequence-diagrams) · [ERD](#data-models-erd) · [C4](#c4-diagrams) ·
[Themes](#themes) · [Dark mode & embedding](#dark-mode-and-embedding) · [Icons](#icons) · [Sketch mode](#sketch-mode)

## Choosing a type

| The user wants to show | Use |
|---|---|
| Components and how they talk | Architecture (shapes + containers) |
| Who calls whom, in what order | `sequence_diagram` |
| Tables and relationships | `sql_table` ERD |
| System context at multiple zoom levels | C4 (theme 303) or `layers` |
| A process with branches | Flowchart (`diamond` decisions, `direction: down`) |
| States and transitions | State machine (ovals, labelled edges) |
| Rigid rows/columns | Grid diagram |

One diagram, one argument. If the user's ask contains two arguments
("the architecture AND the deploy flow"), make two diagrams.

## Architecture diagrams

- `direction: right` for request flows; `direction: down` for layered stacks.
- Containers = deployment/trust boundaries (VPC, cluster, team, SaaS
  boundary), not visual grouping for its own sake.
- Externals (third-party SaaS, users) live *outside* containers, styled with
  a dashed `ext` class so ownership boundaries are legible.
- Databases as `cylinder`, queues/brokers as `queue`, people as `person`,
  external managed services as `cloud`.
- Edge labels carry protocol or intent (`gRPC`, `order.created`, `read
  replica`) — never restate the obvious ("connects to").
- One `style.animated: true` edge maximum — reserve it for the single flow
  the diagram argues about.

## Sequence diagrams

- Actors declared first, in the order conversations read (caller → callee →
  stores). Declaration order is display order.
- Label every message with the concrete call (`POST /orders`, `INSERT
  order`), returns with the concrete response (`201 Created`, `order_id`).
- Fragments (`alt`, `loop`, retries) as containers holding connections; keep
  to one level of nesting — deep fragment nesting is unreadable.
- Notes for timing/constraint annotations, not narration.

## Data models (ERD)

- `sql_table` shapes; FK edges from column to column
  (`orders.user_id -> users.id`) — ELK and TALA point at the exact row.
- Only include columns that matter to the argument (keys, FKs, and the 2–3
  business-critical fields). A full schema dump belongs in migrations, not a
  diagram.
- Cardinality via arrowheads: `cf-one`, `cf-many`, `cf-one-required`,
  `cf-many-required` (crow's foot).

## C4 diagrams

- Theme `303` is purpose-built for C4 styling; `c4-person` for actors.
- Model each C4 level as its own board with `layers:` (context → containers
  → components), linked with `link: layers.containers` for click-through.
- Keep to the C4 discipline: every box states name, technology, and
  responsibility in its label.

## Themes

Set via `--theme N` (light) and `--dark-theme N`. Sensible palette, no
hand-picked colours — this is why nodes shouldn't hard-code `style.fill`.

| ID | Name | Use |
|---|---|---|
| 0 | Neutral Default | The default — professional, safe everywhere |
| 1 | Neutral Grey | Even quieter; dense diagrams |
| 4 | Cool Classics | Blue-leaning corporate |
| 8 | Colorblind Clear | Accessibility-first decks |
| 302 | Origami | Clean minimal, presentation-friendly |
| 303 | C4 | C4 model diagrams |
| 200 | Dark Mauve | The standard dark pairing |
| 201 | Dark Flagship Terrastruct | Alternative dark |

(300/301 "Terminal" themes restyle typography, not just colour — only when a
retro terminal look is requested.)

## Dark mode and embedding

**Single adaptive SVG (preferred):**

```bash
render.sh --theme 0 --dark-theme 200 in.d2 out.svg
```

The SVG embeds a `prefers-color-scheme` media query — one file, correct in
both modes, works in GitHub READMEs and most doc sites.

**PNG or strict-sanitiser contexts** need two renders plus `<picture>`:

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagram-dark.svg">
  <img alt="Architecture" src="diagram-light.svg">
</picture>
```

For HTML pages embedding several diagrams inline, render with `--no-xml-tag`
and unique `--salt` values to avoid ID collisions (both are supported
directly by the render script).

## Icons

`icon: https://icons.terrastruct.com/...` URLs; free library at
<https://icons.terrastruct.com>. Icons are fetched at render time and
embedded by `--bundle` (render.sh always bundles). The render report's
`remote:` line lists every host a render fetched; for a `.d2` file you did
not author, render with `--no-remote-assets` first so an untrusted source
cannot trigger outbound requests.

- Icons are seasoning: use them for *recognition* (AWS/GCP service marks,
  well-known product logos), not decoration on every box.
- Some library URLs 403/404 — if a render drops an icon or errors, remove
  the icon rather than shipping a broken glyph. Test icon-heavy diagrams
  early in the loop.
- Offline environments: skip icons entirely; shapes and labels must carry
  the diagram anyway.
- Standalone logo/image nodes: `shape: image` + `icon:`.

## Sketch mode

`--sketch` gives a credible hand-drawn look — good for proposals and "this
is a draft, argue with me" documents. Combine with theme 0 or 302. Don't use
it for reference documentation; precision cues matter there.
