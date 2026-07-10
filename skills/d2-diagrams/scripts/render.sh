#!/usr/bin/env bash
# render.sh — render a .d2 file to SVG with the best available layout engine.
#
# Engine selection (default --engine auto):
#   1. TALA installed AND licensed        -> tala
#   2. TALA installed, unlicensed         -> elk (TALA would watermark; --allow-watermark overrides)
#   3. TALA not installed                 -> elk
#   Force a specific engine with --engine tala|elk|dagre. A forced engine is
#   never substituted: if it cannot render — or renders a watermark you did not
#   accept with --allow-watermark — the script fails.
#
# Licence detection: TSTRUCT_TOKEN env var, or api_token in
# ${TSTRUCT_AUTHFILE:-${XDG_CONFIG_HOME:-$HOME/.config}/tstruct/auth.json}.
# Belt-and-braces: after a TALA render every produced SVG is scanned for TALA's
# watermark element; if present (expired/invalid token), auto-selected TALA is
# re-rendered with ELK, and a forced TALA fails.
#
# Multi-board sources (layers/scenarios/steps) render one SVG per board into a
# directory named after the output; the report and watermark scan cover every
# board, and PNG previews go to a separate {name}-preview/ directory.
#
# Usage: render.sh [options] input.d2 [output.svg]
#   --engine auto|tala|elk|dagre   layout engine (default: auto)
#   --allow-watermark              keep unlicensed TALA output (evaluation only)
#   --png                          also write a PNG preview next to the SVG
#   --preview-optional             with --png: a failed preview is non-fatal
#   --theme N                      d2 theme ID (0 = Neutral Default)
#   --dark-theme N                 embed a dark variant (responds to prefers-color-scheme)
#   --sketch                       hand-drawn sketch mode
#   --pad N                        padding in px (d2 default: 100)
#   --animate N                    animate multi-board SVGs, interval in ms (SVG output only)
#   --seed N[,N...]                TALA layout seed(s) (--tala-seeds; ignored on other engines)
#   --target PATH                  render a single board of a multi-board source
#   --no-xml-tag                   omit the XML tag from the SVG (inline HTML embedding)
#   --salt VALUE                   unique SVG ID salt (multiple diagrams on one page)
#   --elk-OPTION VALUE             pass an ELK tuning flag through (e.g. --elk-padding "...")
#   --no-remote-assets             refuse to render if the source (or its local
#                                  imports) references remote http(s) assets
#   --quiet                        suppress the engine report
#   -h, --help                     show this help
#
# Output (stdout): "engine:", optional "fallback:", optional "remote:" (hosts the
# render may fetch), "svg:", optional "png:" lines.
# Exit codes: 0 ok; 1 validate/render/watermark/preview error; 2 usage error; 3 d2 not installed.

set -u

ENGINE="auto"
AUTO_TALA=0
ALLOW_WATERMARK=0
WANT_PNG=0
PREVIEW_OPTIONAL=0
THEME=""
DARK_THEME=""
SKETCH=0
PAD=""
ANIMATE=""
SEED=""
TARGET_SET=0
TARGET=""
NO_XML_TAG=0
SALT_SET=0
SALT=""
ELK_FLAGS=()
NO_REMOTE=0
QUIET=0
INPUT=""
OUTPUT=""

err() { printf 'render.sh: %s\n' "$*" >&2; }
report() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

need_value() {
  # $1 flag name, $2 remaining-arg count
  if [ "$2" -lt 2 ]; then
    err "$1 needs a value (see --help)"
    exit 2
  fi
}

need_number() {
  # $1 flag name, $2 value
  case "$2" in
    *[!0-9]*|"")
      err "$1 expects a number, got: $2"
      exit 2
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --engine) need_value --engine $#; ENGINE="$2"; shift 2 ;;
    --allow-watermark) ALLOW_WATERMARK=1; shift ;;
    --png) WANT_PNG=1; shift ;;
    --preview-optional) PREVIEW_OPTIONAL=1; shift ;;
    --theme) need_value --theme $#; need_number --theme "$2"; THEME="$2"; shift 2 ;;
    --dark-theme) need_value --dark-theme $#; need_number --dark-theme "$2"; DARK_THEME="$2"; shift 2 ;;
    --sketch) SKETCH=1; shift ;;
    --pad) need_value --pad $#; need_number --pad "$2"; PAD="$2"; shift 2 ;;
    --animate) need_value --animate $#; need_number --animate "$2"; ANIMATE="$2"; shift 2 ;;
    --seed)
      need_value --seed $#
      case "$2" in
        *[!0-9,]*|""|,*|*,|*,,*)
          err "--seed expects N or N,N,... got: $2"
          exit 2
          ;;
      esac
      SEED="$2"; shift 2 ;;
    --target) need_value --target $#; TARGET_SET=1; TARGET="$2"; shift 2 ;;
    --no-xml-tag) NO_XML_TAG=1; shift ;;
    --salt) need_value --salt $#; SALT_SET=1; SALT="$2"; shift 2 ;;
    --elk-*) need_value "$1" $#; ELK_FLAGS+=("$1" "$2"); shift 2 ;;
    --no-remote-assets) NO_REMOTE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    -*) err "unknown option: $1 (see --help)"; exit 2 ;;
    *)
      if [ -z "$INPUT" ]; then INPUT="$1"
      elif [ -z "$OUTPUT" ]; then OUTPUT="$1"
      else err "unexpected argument: $1"; exit 2
      fi
      shift ;;
  esac
done

[ -n "$INPUT" ] || { err "usage: render.sh [options] input.d2 [output.svg] (see --help)"; exit 2; }
case "$INPUT" in
  *.d2) : ;;
  *) err "input must be a .d2 file (guards against overwriting non-source files): $INPUT"; exit 2 ;;
esac
[ -f "$INPUT" ] || { err "input file not found: $INPUT"; exit 2; }
[ -n "$OUTPUT" ] || OUTPUT="${INPUT%.d2}.svg"
case "$OUTPUT" in
  *.svg) : ;;
  *) err "output must end in .svg (SVG is the deliverable; add --png for a raster preview): $OUTPUT"; exit 2 ;;
esac

command -v d2 >/dev/null 2>&1 || {
  err "d2 is not installed. Install it first:"
  err "  macOS:          brew install d2"
  err "  Linux/macOS:    curl -fsSL https://d2lang.com/install.sh | sh -s --"
  err "  Windows:        winget install --id Terrastruct.D2  (or scoop install d2)"
  err "  Go toolchain:   go install oss.terrastruct.com/d2@latest"
  exit 3
}

tala_installed() { command -v d2plugin-tala >/dev/null 2>&1; }

tala_licensed() {
  [ -n "${TSTRUCT_TOKEN:-}" ] && return 0
  authfile="${TSTRUCT_AUTHFILE:-${XDG_CONFIG_HOME:-$HOME/.config}/tstruct/auth.json}"
  [ -s "$authfile" ] && grep -q '"api_token"' "$authfile" 2>/dev/null
}

# TALA's watermark is a distinctively styled inline element; user labels render
# with font/class attributes instead, so this does not match diagram content.
WATERMARK_PATTERN='opacity:0.3">UNLICENSED COPY</text>'

svg_watermarked() {
  # $1 = an SVG file, or a directory of per-board SVGs (scanned recursively)
  if [ -d "$1" ]; then
    [ -n "$(find "$1" -name '*.svg' -exec grep -l "$WATERMARK_PATTERN" {} + 2>/dev/null | head -1)" ]
  else
    grep -q "$WATERMARK_PATTERN" "$1" 2>/dev/null
  fi
}

# --- remote asset scan -----------------------------------------------------------
# Walks the source plus its local @import graph and lists remote http(s) hosts
# that d2 would fetch at render time (icons, images). Always surfaced in the
# report; --no-remote-assets turns any hit into a refusal.
scan_remote_hosts() {
  queue="$1"; visited=""; scanned=0
  while [ -n "$queue" ] && [ "$scanned" -lt 50 ]; do
    f="${queue%%|*}"
    case "$queue" in *\|*) queue="${queue#*|}" ;; *) queue="" ;; esac
    case "|$visited|" in *"|$f|"*) continue ;; esac
    [ -f "$f" ] || continue
    visited="$visited|$f"
    scanned=$((scanned + 1))
    d=$(dirname "$f")
    while IFS= read -r imp; do
      [ -n "$imp" ] || continue
      p="$d/$imp"
      [ -f "$p" ] || p="$d/$imp.d2"
      [ -f "$p" ] && queue="${queue:+$queue|}$p"
    done <<EOF
$(grep -oE '@[A-Za-z0-9_./-]+' "$f" 2>/dev/null | sed 's/^@//' | sort -u)
EOF
  done
  printf '%s\n' "$visited" | tr '|' '\n' | while IFS= read -r f; do
    [ -f "$f" ] && grep -oE 'https?://[^"'"'"'[:space:]]+' "$f" 2>/dev/null
  done | sed -E 's|^https?://||; s|[/:].*$||' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

REMOTE_HOSTS=$(scan_remote_hosts "$INPUT")
if [ "$NO_REMOTE" -eq 1 ] && [ -n "$REMOTE_HOSTS" ]; then
  err "remote assets found and --no-remote-assets is set — refusing to render."
  err "hosts: $REMOTE_HOSTS"
  err "Remove the remote icon/image URLs (or drop --no-remote-assets if you trust this source)."
  exit 1
fi

# --- pick engine --------------------------------------------------------------
FALLBACK_REASON=""
case "$ENGINE" in
  auto)
    if tala_installed; then
      if tala_licensed || [ "$ALLOW_WATERMARK" -eq 1 ]; then
        ENGINE="tala"
        AUTO_TALA=1
      else
        ENGINE="elk"
        FALLBACK_REASON="TALA is installed but no licence found (TSTRUCT_TOKEN / auth.json) — using ELK to avoid a watermarked SVG. Pass --allow-watermark to evaluate TALA anyway."
      fi
    else
      ENGINE="elk"
      FALLBACK_REASON="TALA not installed — using ELK. For best architecture layouts: brew install terrastruct/tap/tala (or: curl -fsSL https://d2lang.com/install.sh | sh -s -- --tala)"
    fi
    ;;
  tala)
    tala_installed || {
      err "TALA requested but d2plugin-tala is not on PATH."
      err "Install: brew install terrastruct/tap/tala"
      err "     or: curl -fsSL https://d2lang.com/install.sh | sh -s -- --tala"
      exit 1
    }
    ;;
  elk|dagre) : ;;
  *) err "unknown engine: $ENGINE (use auto|tala|elk|dagre)"; exit 2 ;;
esac

# --- validate first: cheap, and gives line:col errors --------------------------
VALIDATE_OUT=$(d2 validate "$INPUT" 2>&1) || {
  err "d2 validate failed:"
  printf '%s\n' "$VALIDATE_OUT" >&2
  exit 1
}

# --- render --------------------------------------------------------------------
render() {
  # $1 engine, $2 svg-output (1 = include SVG-only flags), $3 output path
  r_engine="$1"; r_svg="$2"; r_out="$3"
  set -- --layout "$r_engine" --bundle
  [ -n "$THEME" ] && set -- "$@" --theme "$THEME"
  [ "$r_svg" -eq 1 ] && [ -n "$DARK_THEME" ] && set -- "$@" --dark-theme "$DARK_THEME"
  [ "$SKETCH" -eq 1 ] && set -- "$@" --sketch
  [ -n "$PAD" ] && set -- "$@" --pad "$PAD"
  [ "$TARGET_SET" -eq 1 ] && set -- "$@" --target "$TARGET"
  # --animate-interval, --dark-theme, --no-xml-tag and --salt are SVG-only
  [ "$r_svg" -eq 1 ] && [ -n "$ANIMATE" ] && set -- "$@" --animate-interval "$ANIMATE"
  [ "$r_svg" -eq 1 ] && [ "$NO_XML_TAG" -eq 1 ] && set -- "$@" --no-xml-tag
  [ "$r_svg" -eq 1 ] && [ "$SALT_SET" -eq 1 ] && set -- "$@" --salt "$SALT"
  [ "${#ELK_FLAGS[@]}" -gt 0 ] && [ "$r_engine" = "elk" ] && set -- "$@" "${ELK_FLAGS[@]}"
  [ -n "$SEED" ] && [ "$r_engine" = "tala" ] && set -- "$@" --tala-seeds "$SEED"
  RENDER_OUT=$(d2 "$@" "$INPUT" "$r_out" 2>&1) || {
    err "d2 render failed ($r_engine):"
    printf '%s\n' "$RENDER_OUT" >&2
    return 1
  }
}

if ! render "$ENGINE" 1 "$OUTPUT"; then
  # d2/TALA version skew can hard-fail compilation. Only degrade to ELK when
  # TALA was chosen automatically — a user-forced engine must fail honestly.
  if [ "$AUTO_TALA" -eq 1 ]; then
    FALLBACK_REASON="TALA render failed (possible d2/TALA version mismatch — try updating both) — re-rendered with ELK."
    ENGINE="elk"
    render elk 1 "$OUTPUT" || exit 1
  else
    exit 1
  fi
fi

# --- locate output: multi-board sources render one SVG per board into a dir ------
MULTI=0
BOARD_DIR="${OUTPUT%.svg}"
if [ ! -f "$OUTPUT" ]; then
  if [ -d "$BOARD_DIR" ]; then
    MULTI=1
  else
    err "render reported success but produced neither $OUTPUT nor $BOARD_DIR/"
    exit 1
  fi
fi
if [ "$MULTI" -eq 1 ]; then SCAN_PATH="$BOARD_DIR"; else SCAN_PATH="$OUTPUT"; fi

# --- post-render watermark guard ------------------------------------------------
USED_ENGINE="$ENGINE"
if [ "$ENGINE" = "tala" ] && [ "$ALLOW_WATERMARK" -eq 0 ] && svg_watermarked "$SCAN_PATH"; then
  if [ "$AUTO_TALA" -eq 1 ]; then
    FALLBACK_REASON="TALA rendered with an UNLICENSED watermark (token missing, invalid, or expired) — re-rendered with ELK. Pass --allow-watermark to keep TALA evaluation output."
    USED_ENGINE="elk"
    render elk 1 "$OUTPUT" || exit 1
  else
    # A forced engine is never substituted (see header) — fail, and don't
    # leave a watermarked deliverable behind.
    rm -rf "$SCAN_PATH"
    err "forced TALA rendered an UNLICENSED watermark and --allow-watermark was not given."
    err "The watermarked output was removed. Set TSTRUCT_TOKEN (or the auth file) for clean"
    err "TALA output, pass --allow-watermark to keep evaluation output, or use --engine auto."
    exit 1
  fi
fi

# --- optional PNG preview (raster, for visual self-checks) -----------------------
PNG_PATH=""
if [ "$WANT_PNG" -eq 1 ]; then
  if [ "$MULTI" -eq 1 ]; then
    # A separate directory: d2 clears its output dir per render, and the PNG
    # pass must not destroy the per-board SVGs.
    PNG_PATH="${OUTPUT%.svg}-preview.png"
  else
    PNG_PATH="${OUTPUT%.svg}.png"
  fi
  PNG_FAILED=0
  if ! render "$USED_ENGINE" 0 "$PNG_PATH"; then
    PNG_FAILED=1
  elif [ ! -f "$PNG_PATH" ]; then
    # multi-board inputs render one PNG per board into a directory
    if [ -d "${PNG_PATH%.png}" ]; then
      PNG_PATH="${PNG_PATH%.png}/ (one PNG per board)"
    else
      PNG_FAILED=1
    fi
  fi
  if [ "$PNG_FAILED" -eq 1 ]; then
    err "PNG preview failed (the SVG itself succeeded). The first PNG render"
    err "downloads a headless browser — retry once, or inspect the SVG instead."
    if [ "$PREVIEW_OPTIONAL" -eq 1 ]; then
      PNG_PATH=""
    else
      err "--png was requested; failing so the miss is not silent (pass --preview-optional for best-effort)."
      exit 1
    fi
  fi
fi

report "engine: $USED_ENGINE"
[ -n "$FALLBACK_REASON" ] && report "fallback: $FALLBACK_REASON"
[ -n "$REMOTE_HOSTS" ] && report "remote: $REMOTE_HOSTS"
if [ "$MULTI" -eq 1 ]; then
  report "svg: $BOARD_DIR/ (one SVG per board)"
else
  report "svg: $OUTPUT"
fi
[ -n "$PNG_PATH" ] && report "png: $PNG_PATH"
exit 0
