#!/usr/bin/env bash
#
# configure.sh - check the machine, detect the toolchain, write a config.
#
# Not run directly: this is the last stage of bin/cpen-setup, and
# `cpen-setup --config-only` is how you re-run just this part.
#
# Safe to re-run: it rewrites the config from fresh detection and keeps
# any value you set by hand (those live above the generated block).
#
# It adds bin/ to your PATH by adding one line to your shell profile. Pass
# --no-path to skip that and print the line instead.
#
set -uo pipefail
# BASH_SOURCE, not $0: when a test sources this for the PATH helpers, $0 is
# "bash" and REPO would come out as the parent of the checkout.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
REPO=$PWD

DO_PATH=1
for a in "$@"; do
  case "$a" in
    --no-path) DO_PATH=0 ;;
    -h|--help) sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a (try --help)" >&2; exit 2 ;;
  esac
done

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/cpen-tools"
# CPEN_TOOLS_CONFIG picks a different config file, which is how a second install
# (a dev checkout, say) keeps its own settings instead of overwriting the
# one your labs depend on. detect.sh, cpen-init and cpen-nios all honour
# the same variable.
CONFIG_FILE="${CPEN_TOOLS_CONFIG:-$CONFIG_HOME/config}"
CONFIG_HOME=$(dirname "$CONFIG_FILE")
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/cpen-tools"


bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m    %s\n' "$*"; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$*"; }
bad()  { printf '  \033[31mno\033[0m    %s\n' "$*"; }
die()  { printf '\n\033[1;31mSetup failed.\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------- on PATH? ---
# One line, in one file, marked so it can be found again. Never rewrite or
# reorder anything already in the profile.
TAG='# added by cpen-setup'
# Tags written by earlier versions. Without these an upgrade appends a
# second PATH line instead of recognising the one already there.
OLD_TAGS='# added by fpga-setup
# added by fpga-nios setup.sh
# added by fpga-console setup.sh'
has_any_tag() {  # has_any_tag <file>
  # A here-string, not a pipe: the right side of a pipe is a subshell, so
  # a hit inside it cannot report back and every old tag went unseen.
  local t
  grep -qF "$TAG" "$1" 2>/dev/null && return 0
  while IFS= read -r t; do
    [ -n "$t" ] && grep -qF "$t" "$1" 2>/dev/null && return 0
  done <<< "$OLD_TAGS"
  return 1
}
LINE="export PATH=\"$REPO/bin:\$PATH\""

profile_for_shell() {
  case "$(basename "${SHELL:-}")" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) [ -f "$HOME/.bash_profile" ] && echo "$HOME/.bash_profile" \
            || echo "$HOME/.profile" ;;
    *)    echo "" ;;                       # fish and friends: syntax differs
  esac
}

# The profile decides, never `command -v`. A shell started before the line
# was removed still carries the directory in its own PATH, so asking this
# process whether the command resolves says yes while every new terminal
# says no - which is exactly how a reinstall reported success and left the
# profile untouched.
already_on_path() {  # already_on_path <profile>
  has_any_tag "$1" && return 0
  grep -qF "$REPO/bin" "$1" 2>/dev/null   # added by hand, without a marker
}

announce_path() {
  bold "Run it"
  if [ "$DO_PATH" = 0 ]; then
    echo "  Skipped editing your PATH (--no-path). Run it in place:"
    echo "      $REPO/bin/cpen-nios"
    echo
    echo "  Or add this line to your shell profile yourself:"
    echo "      $LINE"
  else
    prof=$(profile_for_shell)
    if [ -z "$prof" ]; then
      warn "unrecognised shell ${SHELL:-unknown}; not editing it"
      echo "  Add the equivalent of this to your shell config:"
      echo "      $LINE"
    elif already_on_path "$prof"; then
      ok "already on your PATH via $prof"
    else
      { [ -s "$prof" ] && echo ""; echo "$TAG"; echo "$LINE"; } >> "$prof" \
        && ok "added to $prof" \
        || { warn "could not write $prof"; echo "  Add it yourself: $LINE"; }
      echo "  Open a new terminal, or run:  source $prof"
    fi
    echo
    echo "  Then:  cpen-nios"
  fi
}

# Sourcing with CONFIGURE_LIB_ONLY=1 gives the PATH helpers without running
# detection or writing a config, so tests can exercise them directly.
[ -n "${CONFIGURE_LIB_ONLY:-}" ] && return 0

problems=0

bold "Host"
case "$(uname -s)" in
  Darwin) ok "macOS $(sw_vers -productVersion 2>/dev/null)" ;;
  Linux)  warn "Linux host - cpen-nios drives an OrbStack VM from macOS."
          warn "On native Linux you do not need it: run the Makefile directly." ;;
  *)      bad "unsupported host: $(uname -s)"; problems=$((problems+1)) ;;
esac

if command -v python3 >/dev/null 2>&1; then
  pv=$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')
  if python3 -c 'import sys;sys.exit(0 if sys.version_info>=(3,8) else 1)'; then
    ok "python3 $pv"
  else
    bad "python3 $pv is too old - need 3.8+"; problems=$((problems+1))
  fi
  python3 -c 'import curses' 2>/dev/null && ok "curses available" || {
    bad "python3 has no curses module"; problems=$((problems+1)); }
else
  bad "python3 not found - install Xcode Command Line Tools:  xcode-select --install"
  problems=$((problems+1))
fi

if command -v orb >/dev/null 2>&1; then
  ok "orb $(orb version 2>/dev/null | head -1)"
else
  bad "orb not found - install OrbStack:  https://orbstack.dev"
  problems=$((problems+1))
fi

[ "$problems" -gt 0 ] && die "fix the above, then run cpen-setup again"

echo
bold "Toolchain"
# Keep detection's stderr: DETECT_QUIET silences the running commentary but
# not the 'detect:' lines, which are the ones that say what is actually
# wrong. Discarding them is how a licence mismatch goes unreported.
detect_err=$(mktemp)
trap 'rm -f "$detect_err"' EXIT
detected=$(DETECT_QUIET=1 ./lib/detect.sh 2>"$detect_err")
rc=$?
if [ $rc -ne 0 ] || [ -z "$detected" ]; then
  ./lib/detect.sh >/dev/null   # re-run loudly so the student sees why
  die "detection failed - see above. You can set values by hand in $CONFIG_FILE"
fi
eval "$detected"
detect_says() { grep -F "$1" "$detect_err" 2>/dev/null | sed 's/^detect: //'; }

ok "machine        $MACHINE"
ok "install        $INSTALL"
ok "quartus bin    $QUARTUS_BIN"
[ "${TOOLCHAIN_OK:-0}" = 1 ] && ok "RISC-V toolchain complete" \
  || { warn "RISC-V toolchain incomplete - COMPILE and RUN will not work."
       warn "It is NOT part of the installer's default set. Install it with:"
       warn "  sudo ./qinst.sh --components riscfree --download-dir ~/qinst-dl \\"
       warn "       --install-dir $INSTALL --accept-eula --cli"; }
[ "${LLVM_OK:-0}" = 1 ] && ok "LLVM present (experimental profile available)" \
  || ok "LLVM absent (normal - the default profile does not need it)"

if [ -z "${QUESTA_BIN:-}" ]; then
  warn "Questa not found - SIM and WAVE will not work."
  warn "Re-run the installer including the questa_fse component."
elif [ "${QUESTA_OK:-0}" = 1 ]; then
  ok "Questa         licensed"
else
  warn "Questa found but not licensed - SIM and WAVE will not work."
  detect_says licence | while IFS= read -r l; do warn "$l"; done
  warn "The licence is free. See docs/SETUP.md (Part 6)"
fi

echo
bold "Board"
if [ -n "${BOARD:-}" ]; then
  ok "$BOARD  (IDCODE $IDCODE, chain index $JTAG_INDEX)"
  ok "cable          ${CABLE:-<single cable, no flag needed>}"
  [ -n "${SOF:-}" ] && ok "bitstream      $SOF" \
    || warn "no prebuilt bitstream for $BOARD - set SOF in $CONFIG_FILE"
elif [ -n "${USB_ID:-}" ]; then
  warn "cable attached but no JTAG chain - the board may be off, or the"
  warn "passthrough is stale. cpen-nios fixes both when it starts."
else
  warn "no board detected. Plug it in, power it on, and re-run - or carry on:"
  warn "cpen-nios detects the board every time it starts."
fi

# ---------------------------------------------------------------- write ---
mkdir -p "$CONFIG_HOME" "$STATE_HOME" || die "cannot create $CONFIG_HOME"

# Preserve anything the student wrote above the generated marker.
MARKER='## BEGIN AUTOGENERATED BLOCK ##'
custom=""
if [ -f "$CONFIG_FILE" ]; then
  custom=$(sed "/^${MARKER//\//\\/}\$/,\$d" "$CONFIG_FILE")
  cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
fi

{
  if [ -n "$custom" ]; then
    printf '%s\n' "$custom"
  else
    cat <<'HDR'
# cpen-nios configuration.
#
# Anything you set ABOVE the generated block wins over detection and
# survives re-running cpen-setup. Use it when detection gets something
# wrong, e.g.:
#
#     BOARD=DE1-SoC
#     INSTALL=$HOME/intelFPGA_lite/24.1std

HDR
  fi
  printf '%s\n' "$MARKER"
  printf '# written %s\n' "$(date '+%Y-%m-%d %H:%M')"
  printf '%s\n' "$detected"        # already shell-quoted by detect.sh
  printf 'REPO="%s"\n' "$REPO"
  printf 'MAKEFILE="%s/share/Makefile.linux"\n' "$REPO"
  printf 'RUNDIR="%s"\n' "$STATE_HOME"
} > "$CONFIG_FILE"

echo
bold "Wrote $CONFIG_FILE"
ok "logs and state go to $STATE_HOME"

echo
announce_path
echo
