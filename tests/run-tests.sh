#!/usr/bin/env bash
# run-tests.sh — wrapper-script tests using stub d2/d2plugin-tala executables.
#
# Covers the safety logic the plugin differentiates itself on: the watermark
# guard (positive fixture + negative user-label fixture), forced-engine
# honesty, multi-board handling, preview failure semantics, input/seed
# validation, the remote-asset scan, and setup.sh's version floor.
#
# No real d2 or TALA needed — everything renders through stubs, so this runs
# in CI. What stubs CANNOT catch: Terrastruct changing the watermark markup in
# a new TALA release. RELEASE-TIME SMOKE TEST (maintainer machine, real
# binaries, TALA installed WITHOUT a licence):
#     render.sh --engine tala examples/microservices.d2 /tmp/smoke.svg
# must exit 1 with the "forced TALA rendered an UNLICENSED watermark" message
# and leave no /tmp/smoke.svg behind. If it exits 0 with engine: tala, the
# watermark pattern no longer matches the current TALA — update
# WATERMARK_PATTERN in render.sh before releasing.
#
# Usage: tests/run-tests.sh   (from anywhere; exit 0 = all pass)

set -u

TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPTS_DIR=$(cd "$TESTS_DIR/../skills/d2-diagrams/scripts" && pwd)
FIXTURES="$TESTS_DIR/fixtures"

WORK=$(mktemp -d)
STUBS="$WORK/stubs"
mkdir -p "$STUBS"
trap 'rm -rf "$WORK"' EXIT

export STUB_FIXTURE="$FIXTURES/watermark-element.svg"

# --- stub d2: env-controlled behaviour -------------------------------------------
cat > "$STUBS/d2" <<'STUB'
#!/bin/sh
# stub d2 for wrapper tests (behaviour via STUB_* env vars)
case "${1:-}" in
  --version) echo "${STUB_D2_VERSION:-0.7.1}"; exit 0 ;;
  validate) exit 0 ;;
  fmt) exit 0 ;;
esac
layout=elk
prev=""
for a in "$@"; do
  [ "$prev" = "--layout" ] && layout="$a"
  prev="$a"
done
out=""
for a in "$@"; do out="$a"; done
if [ "${STUB_FAIL_PNG:-0}" = "1" ]; then
  case "$out" in *.png) echo "stub: simulated PNG export failure" >&2; exit 1 ;; esac
fi
emit() {
  if [ "$layout" = "tala" ] && [ "${STUB_WATERMARK:-0}" = "1" ]; then
    cat "$STUB_FIXTURE" > "$1"
  else
    printf '<svg xmlns="http://www.w3.org/2000/svg"><text>ok</text></svg>\n' > "$1"
  fi
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

printf '#!/bin/sh\nexit 0\n' > "$STUBS/d2plugin-tala"
chmod +x "$STUBS/d2plugin-tala"

PATH="$STUBS:$PATH"
export PATH

RENDER="$SCRIPTS_DIR/render.sh"
SETUP="$SCRIPTS_DIR/setup.sh"
WATERMARK_PATTERN='opacity:0.3">UNLICENSED COPY</text>'

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
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass=$((pass + 1)); printf 'ok   %s\n' "$desc"
  else
    fail=$((fail + 1)); printf 'FAIL %s (pattern not found: %s)\n' "$desc" "$pattern"
  fi
}

cd "$WORK" || exit 1
printf 'a: Server\nb: DB\na -> b\n' > good.d2
printf 'a: API {icon: https://icons.example.com/x.svg}\na -> b\n' > icons.d2
cp good.d2 trap.png

# 1. Watermark pattern: matches the fixture, not a plain user label
expect_grep "pattern matches watermark fixture" "$WATERMARK_PATTERN" "$FIXTURES/watermark-element.svg"
if grep -q "$WATERMARK_PATTERN" "$FIXTURES/user-label-unlicensed.svg" 2>/dev/null; then
  fail=$((fail + 1)); printf 'FAIL pattern must NOT match a user label reading UNLICENSED COPY\n'
else
  pass=$((pass + 1)); printf 'ok   pattern ignores user-label fixture\n'
fi

# 2. Forced TALA + watermark -> exit 1, no output left behind
STUB_WATERMARK=1 t "forced tala watermark fails" 1 bash "$RENDER" --quiet --engine tala good.d2 forced.svg
if [ ! -e forced.svg ]; then
  pass=$((pass + 1)); echo "ok   forced tala watermark output removed"
else
  fail=$((fail + 1)); echo "FAIL watermarked forced.svg left behind"
fi

# 3. Auto TALA (credentials present) + watermark -> ELK fallback, clean output, exit 0
if STUB_WATERMARK=1 TSTRUCT_TOKEN=stub bash "$RENDER" good.d2 auto.svg > auto.report 2>&1 \
   && grep -q '^engine: elk' auto.report && ! grep -q "$WATERMARK_PATTERN" auto.svg; then
  pass=$((pass + 1)); echo "ok   auto tala watermark falls back to elk"
else
  fail=$((fail + 1)); echo "FAIL auto tala watermark fallback"; cat auto.report
fi

# 4. Seed validation
t "seed ,, rejected" 2 bash "$RENDER" --quiet --seed ',,' good.d2 s1.svg
t "seed 1,2,3 accepted" 0 bash "$RENDER" --quiet --seed '1,2,3' good.d2 s2.svg

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

# 8. Multi-board watermark guard scans every board (forced tala -> exit 1, dir removed)
STUB_MULTI=1 STUB_WATERMARK=1 t "multi-board forced tala watermark fails" 1 bash "$RENDER" --quiet --engine tala good.d2 wmboards.svg
if [ ! -d wmboards ]; then
  pass=$((pass + 1)); echo "ok   multi-board watermarked dir removed"
else
  fail=$((fail + 1)); echo "FAIL watermarked wmboards/ left behind"
fi

# 9. Remote-asset scan
t "--no-remote-assets refuses icon URL" 1 bash "$RENDER" --quiet --no-remote-assets icons.d2 i1.svg
bash "$RENDER" icons.d2 i2.svg > remote.report 2>&1
expect_grep "remote hosts surfaced in report" '^remote: icons.example.com' remote.report

# 10. setup.sh version floor
STUB_D2_VERSION=0.6.5 t "setup floor: old d2 fails check" 1 bash "$SETUP" --check-only
STUB_D2_VERSION=0.6.5 t "setup floor: --allow-unsupported passes" 0 bash "$SETUP" --check-only --allow-unsupported
t "setup: current d2 passes" 0 bash "$SETUP" --check-only

# 11. setup.sh --with-tala failure semantics (no brew, no tala on a bare PATH)
env -i PATH="$STUBS:/usr/bin:/bin" HOME="$WORK" sh -c "rm -f '$STUBS/d2plugin-tala'; bash '$SETUP' --with-tala" > wt.report 2>&1
if [ $? -eq 1 ]; then
  pass=$((pass + 1)); echo "ok   --with-tala failure exits 1"
else
  fail=$((fail + 1)); echo "FAIL --with-tala failure semantics"; cat wt.report
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
