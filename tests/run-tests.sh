#!/usr/bin/env bash
# run-tests.sh — wrapper-script tests using a stub d2 executable.
#
# Covers the wrapper logic: TALA as the default engine, the ELK fallback when
# auto-selected TALA fails, forced-engine honesty, the d2 >= 0.9.0 floor in
# both scripts, multi-board handling, preview failure semantics, input/seed
# validation, and the remote-asset scan.
#
# No real d2 needed — everything renders through the stub, so this runs in CI
# (which also renders the examples with real d2).
#
# Usage: tests/run-tests.sh   (from anywhere; exit 0 = all pass)

set -u

TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPTS_DIR=$(cd "$TESTS_DIR/../skills/d2-diagrams/scripts" && pwd)

WORK=$(mktemp -d)
STUBS="$WORK/stubs"
mkdir -p "$STUBS"
trap 'rm -rf "$WORK"' EXIT

# --- stub d2: env-controlled behaviour -------------------------------------------
cat > "$STUBS/d2" <<'STUB'
#!/bin/sh
# stub d2 for wrapper tests (behaviour via STUB_* env vars)
case "${1:-}" in
  --version) echo "${STUB_D2_VERSION:-v0.9.0}"; exit 0 ;;
  validate|fmt|layout) exit 0 ;;
esac
ARGV="$*"
layout=elk
prev=""
for a in "$@"; do
  [ "$prev" = "--layout" ] && layout="$a"
  prev="$a"
done
out=""
for a in "$@"; do out="$a"; done
if [ "$layout" = "tala" ] && [ "${STUB_FAIL_TALA:-0}" = "1" ]; then
  echo "stub: simulated TALA layout failure" >&2; exit 1
fi
if [ "${STUB_FAIL_PNG:-0}" = "1" ]; then
  case "$out" in *.png) echo "stub: simulated PNG export failure" >&2; exit 1 ;; esac
fi
# the SVG records the full argv so tests can assert on engine and flags
emit() {
  printf '<svg xmlns="http://www.w3.org/2000/svg"><text>%s</text></svg>\n' "$ARGV" > "$1"
}
case "$out" in
  *.svg)
    if [ "${STUB_MULTI:-0}" = "1" ]; then
      d="${out%.svg}"; rm -rf "$d"; mkdir -p "$d"; emit "$d/index.svg"; emit "$d/detail.svg"
    else
      emit "$out"
    fi ;;
  *.png)
    if [ "${STUB_MULTI:-0}" = "1" ]; then
      d="${out%.png}"; rm -rf "$d"; mkdir -p "$d"; : > "$d/index.png"; : > "$d/detail.png"
    else
      : > "$out"
    fi ;;
esac
exit 0
STUB
chmod +x "$STUBS/d2"

PATH="$STUBS:$PATH"
export PATH

RENDER="$SCRIPTS_DIR/render.sh"
SETUP="$SCRIPTS_DIR/setup.sh"

pass=0
fail=0
t() {
  # t <description> <expected-exit> <cmd...>
  desc="$1"; want="$2"; shift 2
  out=$("$@" 2>&1)
  got=$?
  if [ "$got" -eq "$want" ]; then
    pass=$((pass + 1))
    printf 'ok   %s\n' "$desc"
  else
    fail=$((fail + 1))
    printf 'FAIL %s (exit %s, wanted %s)\n%s\n' "$desc" "$got" "$want" "$out"
  fi
}
expect_grep() {
  # expect_grep <description> <pattern> <file-or-string-source: file path>
  desc="$1"; pattern="$2"; file="$3"
  if grep -q -- "$pattern" "$file" 2>/dev/null; then
    pass=$((pass + 1)); printf 'ok   %s\n' "$desc"
  else
    fail=$((fail + 1)); printf 'FAIL %s (pattern not found: %s)\n' "$desc" "$pattern"
  fi
}

cd "$WORK" || exit 1
printf 'a: Server\nb: DB\na -> b\n' > good.d2
printf 'a: API {icon: https://icons.example.com/x.svg}\na -> b\n' > icons.d2
cp good.d2 trap.png

# 1. Default engine is TALA
if bash "$RENDER" good.d2 default.svg > default.report 2>&1 \
   && grep -q '^engine: tala' default.report && ! grep -q '^fallback:' default.report \
   && grep -q -- '--layout tala' default.svg; then
  pass=$((pass + 1)); echo "ok   default engine is tala"
else
  fail=$((fail + 1)); echo "FAIL default engine"; cat default.report
fi

# 2. Auto TALA failure -> ELK fallback, reported, exit 0
if STUB_FAIL_TALA=1 bash "$RENDER" good.d2 auto.svg > auto.report 2>&1 \
   && grep -q '^engine: elk' auto.report && grep -q '^fallback: TALA render failed' auto.report \
   && grep -q -- '--layout elk' auto.svg; then
  pass=$((pass + 1)); echo "ok   auto tala failure falls back to elk"
else
  fail=$((fail + 1)); echo "FAIL auto tala fallback"; cat auto.report
fi

# 3. Forced TALA failure -> exit 1, never substituted
STUB_FAIL_TALA=1 t "forced tala failure fails" 1 bash "$RENDER" --quiet --engine tala good.d2 forced.svg

# 4. Seed validation
t "seed ,, rejected" 2 bash "$RENDER" --quiet --seed ',,' good.d2 s1.svg
t "seed 1,2,3 accepted" 0 bash "$RENDER" --quiet --seed '1,2,3' good.d2 s2.svg
expect_grep "seed passed to tala as --tala-seeds" '--tala-seeds 1,2,3' s2.svg
bash "$RENDER" --quiet --engine elk --seed 4 good.d2 s3.svg
if grep -q -- '--tala-seeds' s3.svg; then
  fail=$((fail + 1)); echo "FAIL --seed must not reach non-TALA engines"
else
  pass=$((pass + 1)); echo "ok   seed ignored on elk"
fi

# 5. Input must be .d2
t "non-.d2 input rejected" 2 bash "$RENDER" --quiet trap.png t1.svg

# 6. --png failure semantics
STUB_FAIL_PNG=1 t "png failure fails the run" 1 bash "$RENDER" --quiet --png good.d2 p1.svg
STUB_FAIL_PNG=1 t "png failure tolerated with --preview-optional" 0 bash "$RENDER" --quiet --png --preview-optional good.d2 p2.svg

# 7. Multi-board: per-board SVGs survive --png, honest reporting
if STUB_MULTI=1 bash "$RENDER" --png good.d2 boards.svg > multi.report 2>&1 \
   && grep -q 'svg: boards/ (one SVG per board)' multi.report \
   && [ -f boards/index.svg ] && [ -f boards-preview/index.png ]; then
  pass=$((pass + 1)); echo "ok   multi-board reporting + SVG survival"
else
  fail=$((fail + 1)); echo "FAIL multi-board handling"; cat multi.report; ls -R .
fi

# 8. Remote-asset scan
t "--no-remote-assets refuses icon URL" 1 bash "$RENDER" --quiet --no-remote-assets icons.d2 i1.svg
bash "$RENDER" icons.d2 i2.svg > remote.report 2>&1
expect_grep "remote hosts surfaced in report" '^remote: icons.example.com' remote.report

# 9. d2 >= 0.9.0 floor (d2 prints a leading "v"; compare numerically)
STUB_D2_VERSION=v0.8.1 t "render: d2 0.8.1 rejected" 3 bash "$RENDER" --quiet good.d2 old.svg
STUB_D2_VERSION=v0.10.0 t "render: d2 0.10.0 accepted" 0 bash "$RENDER" --quiet good.d2 new.svg
STUB_D2_VERSION=v0.8.1 t "setup floor: old d2 fails check" 1 bash "$SETUP" --check-only
STUB_D2_VERSION=v0.8.1 t "setup floor: --allow-unsupported passes" 0 bash "$SETUP" --check-only --allow-unsupported
t "setup: current d2 passes" 0 bash "$SETUP" --check-only

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
