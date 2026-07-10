# D2 Language Reference (for writing correct D2, verified against d2 v0.7.1)

Contents: [Basics](#basics) · [Connections](#connections) · [Containers](#containers) ·
[Shapes](#shape-catalogue) · [Styling](#styling-classes-vars) · [Special diagram types](#special-diagram-types) ·
[Silent pitfalls](#silent-pitfalls-compiles-fine-renders-wrong) · [Compile errors](#compile-errors) · [Reserved keywords](#reserved-keywords)

## Basics

```d2
api                      # shape with key "api", label "api"
api: API Gateway         # key "api", label "API Gateway"
db.shape: cylinder       # set shape
direction: right         # up | down | left | right (root level; per-container is TALA-only)
```

- Keys are **case-insensitive** (`Node` and `node` are the same object).
- Semicolons separate declarations on one line: `SQLite; Cassandra`.
- Comments: `# ...` to end of line.
- Default shape is `rectangle`.

**Quoting:** only `#` and `;` corrupt a label *silently* (comment-start and
declaration-split); `{` fails loudly at compile. Quoting any label containing
punctuation is still the safe habit. Single quotes suppress `${var}`
substitution. See [Silent pitfalls](#silent-pitfalls-compiles-fine-renders-wrong).

## Connections

```d2
a -> b                   # directed
a <-> b                  # bidirectional        a -- b   # undirected
a -> b: label            # edge label (keep short — long labels drift on ELK)
a -> b -> c              # chain
a -> b: { style.animated: true }             # animated flow
a -> b: { target-arrowhead.shape: diamond }  # arrowheads: triangle (default),
                                             # arrow, diamond, circle, box, cross,
                                             # cf-one, cf-many, cf-one-required, cf-many-required
```

- **Connections reference keys, never labels.** `be: Backend` then
  `Backend -> fe` creates a NEW shape labelled "Backend".
- **Repeating `a -> b` adds a second parallel edge** — it does not merge or
  restyle. To restyle an existing edge: `(a -> b)[0].style.stroke-dash: 3`.
- Cross-container edges use full paths: `app.api -> data.pg`. Inside a
  container, `_` references the parent scope.

## Containers

```d2
app: Application {
  api: API Gateway
  worker: Worker
}
data: Data Layer {
  pg: PostgreSQL { shape: cylinder }
}
app.api -> data.pg: read/write
```

Nesting also works with dotted keys (`app.api: API Gateway`). Containers get
their label from the key or `label:`. Group nodes by *logical* boundary
(deployment unit, team, trust zone) — a container is a claim, not decoration.

## Shape catalogue

`rectangle square page parallelogram document cylinder queue package step
callout stored_data person c4-person diamond oval circle hexagon cloud text
code class sql_table image sequence_diagram hierarchy`

Conventions that read instantly: `cylinder` = database, `queue` = broker/queue,
`person`/`c4-person` = actor, `cloud` = external/managed, `hexagon` = decision
or gateway, `page`/`document` = artefact, `diamond` = branch point.

## Styling, classes, vars

Define once, apply by name — never sprinkle per-node styles:

```d2
classes: {
  svc:  { style: { border-radius: 8; shadow: true } }
  ext:  { style: { stroke-dash: 3; font-color: "#666666" } }
}
billing: Billing Service { class: svc }
stripe: Stripe { class: ext }
```

- Style keys: `opacity stroke fill fill-pattern stroke-width (0–15)
  stroke-dash (0–10) border-radius font font-size (8–100) font-color bold
  italic underline text-transform shadow multiple double-border 3d animated`.
- **Avoid `style.fill` on nodes** — hard-coded fills fight the theme palette
  and break dark-theme rendering. Themes exist so you don't pick colours.
- Vars: `vars: { org: Acme }` then `${org}` in labels.
- Per-file config (persists without CLI flags — CLI overrides it):

```d2
vars: { d2-config: { layout-engine: elk; theme-id: 0; dark-theme-id: 200 } }
```

- Globs: `*.style.font-size: 14` (one level), `**` recursive.
  To restyle existing connections use `(* -> *)[*].style.stroke-width: 1` —
  a bare `* -> *` glob CREATES a new connection between every pair of shapes.

Markdown / code labels:

```d2
explanation: |md
  **Retries**: 3 attempts, exponential backoff
|
snippet: |go
  func main() { ... }
|
```

`near:` pins a shape out of the flow: one of `top-left top-center top-right
center-left center-right bottom-left bottom-center bottom-right`
(targeting another shape's ID is TALA-only). Use for titles and legends.

## Special diagram types

**Sequence** — declaration order = display order (unique in D2; declare actors first):

```d2
shape: sequence_diagram
client; api; db                       # actor order fixed here
client -> api: POST /orders
api -> db: INSERT
db -> api: order_id
api -> client: 201 Created
api."validates payload first"        # note on an actor
alt: {                                # fragment = container of connections
  "payment fails": { api -> client: 402 }
}
```

Spans (activation bars): connect nested keys — `client.req -> api.req`.

**SQL tables / ERD:**

```d2
users: {
  shape: sql_table
  id: uuid { constraint: primary_key }
  email: varchar { constraint: unique }
}
orders: {
  shape: sql_table
  id: uuid { constraint: primary_key }
  user_id: uuid { constraint: foreign_key }
}
orders.user_id -> users.id            # FK edge points at the exact row (ELK/TALA)
```

Column named like a reserved keyword? Quote it: `"label": varchar`.

**Grid** (rigid alignment — dashboards, matrices, legends):

```d2
grid-rows: 2
grid-columns: 3
grid-gap: 8
cell1; cell2; cell3; cell4; cell5; cell6
```

**Multi-board:** `layers:` (independent boards), `scenarios:` (variations of
base), `steps:` (progressive build). Render one board with the render
script's `--target PATH`, animate with `--animate N` (SVG output only).
Multi-board renders produce one SVG per board in a directory — the render
script reports and watermark-scans all of them. Prefer layers over one giant
diagram.

## Silent pitfalls (compiles fine, renders wrong)

1. **Label-vs-key**: `Backend -> Frontend` after `be: Backend` → duplicate
   shapes. Always connect via keys.
2. **Unquoted `#`** starts a comment mid-label: `h: my #1 label` renders as
   "my". Quote it.
3. **Unquoted `;`** splits one declaration into two shapes:
   `x: hello; world` → two shapes.
4. **Repeated edges duplicate** rather than restyle → `(a -> b)[0].style...`.
5. **Reserved keywords as data keys** (sql_table columns like `label`,
   `class`, `width`) must be quoted.
6. **Arrowhead styling on an end with no arrowhead** does nothing silently.
7. **`* -> *` as a "style everything" attempt** silently creates a full mesh
   of new connections — restyle existing ones with `(* -> *)[*].style...`.
8. Format-specific flags: `--dark-theme` is SVG-only (warns, then ignored,
   elsewhere); `--animate-interval` works for SVG and GIF and hard-fails
   (exit 1) for any other output format.

## Compile errors

`d2 validate` catches parse errors only. The real compile check is the render
itself (the render script does both). Errors are precise and fixable:

```
err: failed to compile arch.d2: .../arch.d2:12:5: unknown shape "cylnder"
```

Go to `line:col`, fix, re-render. `near`-constant and `direction` errors
enumerate the valid values in the message; shape errors do not — use the
shape catalogue above.

## Reserved keywords

Quote these when used as plain data keys (e.g. table columns):
`label shape icon constraint tooltip link near width height direction top
left grid-rows grid-columns grid-gap vertical-gap horizontal-gap class vars
style classes layers scenarios steps source-arrowhead target-arrowhead`
plus all style keys listed above.
