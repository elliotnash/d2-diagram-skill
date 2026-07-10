#!/usr/bin/env bash
# setup.sh — check (and where possible install) the d2 toolchain.
#
# Usage: setup.sh [--with-tala] [--check-only] [--allow-unsupported]
#   --check-only         report status, install nothing
#                        (exit 0 = ready, 1 = d2 missing/unsupported or a
#                        requested TALA install failed)
#   --with-tala          also install the TALA layout engine (Terrastruct's proprietary
#                        engine; free to evaluate with a watermark, licence for clean output)
#   --allow-unsupported  don't fail on a d2 older than the tested minimum
#
# The skill is tested against d2 0.7.x; MIN_D2 below is the enforced floor.
# Non-interactive by design: never prompts. Prints clear status lines:
#   d2: ok 0.7.1 | tala: ok (credentials found) | tala: ok (no credentials — ELK fallback active)

set -u

MIN_D2="0.7.0"

WITH_TALA=0
CHECK_ONLY=0
ALLOW_UNSUPPORTED=0
for arg in "$@"; do
  case "$arg" in
    --with-tala) WITH_TALA=1 ;;
    --check-only) CHECK_ONLY=1 ;;
    --allow-unsupported) ALLOW_UNSUPPORTED=1 ;;
    -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    *) printf 'setup.sh: unknown option %s\n' "$arg" >&2; exit 2 ;;
  esac
done

status=0

# --- d2 ------------------------------------------------------------------------
check_d2_version() {
  # Enforce the tested minimum: below MIN_D2 is an error unless --allow-unsupported.
  ver=$(d2 --version 2>/dev/null)
  printf 'd2: ok %s\n' "$ver"
  lowest=$(printf '%s\n%s\n' "$MIN_D2" "$ver" | sort -V | head -1)
  if [ "$lowest" != "$MIN_D2" ] && [ "$ver" != "$MIN_D2" ]; then
    if [ "$ALLOW_UNSUPPORTED" -eq 1 ]; then
      printf 'd2: WARNING — %s is below the tested minimum %s (continuing: --allow-unsupported)\n' "$ver" "$MIN_D2"
    else
      printf 'd2: UNSUPPORTED — %s is below the tested minimum %s. Upgrade d2, or rerun with --allow-unsupported to experiment anyway.\n' "$ver" "$MIN_D2"
      status=1
    fi
  fi
}

if command -v d2 >/dev/null 2>&1; then
  check_d2_version
else
  if [ "$CHECK_ONLY" -eq 1 ]; then
    printf 'd2: MISSING\n'
    status=1
  elif command -v brew >/dev/null 2>&1; then
    printf 'd2: installing via Homebrew...\n'
    if brew install d2 >/dev/null 2>&1 && command -v d2 >/dev/null 2>&1; then
      check_d2_version
    else
      printf 'd2: install FAILED. Install manually:\n'
      printf '  curl -fsSL https://d2lang.com/install.sh | sh -s --\n'
      status=1
    fi
  else
    printf 'd2: MISSING. Install one of:\n'
    printf '  Linux/macOS:  curl -fsSL https://d2lang.com/install.sh | sh -s --\n'
    printf '  Windows:      winget install --id Terrastruct.D2\n'
    printf '  Go toolchain: go install oss.terrastruct.com/d2@latest\n'
    status=1
  fi
fi

# --- TALA (optional) -------------------------------------------------------------
tala_licence_status() {
  # Presence of credentials only — validity is proven at first render (the
  # render script's watermark guard catches expired/invalid tokens).
  if [ -n "${TSTRUCT_TOKEN:-}" ] || { authfile="${TSTRUCT_AUTHFILE:-${XDG_CONFIG_HOME:-$HOME/.config}/tstruct/auth.json}"; [ -s "$authfile" ] && grep -q '"api_token"' "$authfile" 2>/dev/null; }; then
    printf 'credentials found (unverified — validity is proven at first render)'
  else
    printf 'no credentials — ELK fallback active; get a licence at https://terrastruct.com/tala'
  fi
}

if command -v d2plugin-tala >/dev/null 2>&1; then
  printf 'tala: ok (%s)\n' "$(tala_licence_status)"
elif [ "$WITH_TALA" -eq 1 ] && [ "$CHECK_ONLY" -eq 0 ]; then
  if command -v brew >/dev/null 2>&1; then
    printf 'tala: installing via Homebrew (Terrastruct proprietary licence applies)...\n'
    if brew install terrastruct/tap/tala >/dev/null 2>&1 && command -v d2plugin-tala >/dev/null 2>&1; then
      printf 'tala: ok (%s)\n' "$(tala_licence_status)"
    else
      printf 'tala: install FAILED. Install manually:\n'
      printf '  curl -fsSL https://d2lang.com/install.sh | sh -s -- --tala\n'
      status=1
    fi
  else
    printf 'tala: cannot install automatically (no Homebrew). Install with:\n'
    printf '  curl -fsSL https://d2lang.com/install.sh | sh -s -- --tala\n'
    status=1
  fi
elif [ "$WITH_TALA" -eq 1 ]; then
  printf 'tala: not installed (requested with --with-tala, but --check-only installs nothing)\n'
  status=1
else
  printf 'tala: not installed (optional — ELK is used instead; rerun with --with-tala to add it)\n'
fi

exit "$status"
