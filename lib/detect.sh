#!/usr/bin/env bash
#
# detect.sh - work out where everything is, and print it as KEY=value.
#
# Sourced by the bash tools and parsed by the Python console, so there is
# exactly one implementation of "where is Quartus / which board is this".
#
# Run it directly to see what it found:   lib/detect.sh
# Anything already set in the environment or the config file wins, so a
# student with an unusual layout can override any single value without
# giving up detection of the rest.
#
# Every probe prints to stderr; only KEY=value goes to stdout, so callers
# can do:   eval "$(lib/detect.sh 2>/dev/null)"
#
set -uo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/cpen-tools"
CONFIG_FILE="${CPEN_TOOLS_CONFIG:-$CONFIG_HOME/config}"

note() { [ -n "${DETECT_QUIET:-}" ] || printf '  %s\n' "$*" >&2; }
fail() { printf 'detect: %s\n' "$*" >&2; }
# Single-quoted and escaped: cable names contain spaces and brackets
# ("USB-Blaster [1-1]"), which an unquoted eval would try to execute.
emit() { printf "%s='%s'\n" "$1" "${2//\'/\'\\\'\'}"; }

# User config first: everything below only fills in what is still unset.
# shellcheck disable=SC1090
[ -r "$CONFIG_FILE" ] && . "$CONFIG_FILE"

# --------------------------------------------------------------- the VM ---
# Every VM-side probe goes through here. stdin MUST be /dev/null: given a
# TTY, orb allocates a remote pty and tears down backgrounded processes
# with it, and the capability sequences it emits corrupt our output.
vm() { orb -m "$MACHINE" bash -c "$*" < /dev/null 2>/dev/null; }

# The toolchain lives in ~/.bashrc, which Ubuntu skips for non-interactive
# shells, so a login shell finds nothing. Only -i sees it.
vm_i() { orb -m "$MACHINE" bash -ic "$*" < /dev/null 2>/dev/null; }

detect_machine() {
  # CPEN_VM is how cpen-setup, cpen-gui and cpen-uninstall are told which
  # machine to use. Without it here, `CPEN_VM=x cpen-setup` installed into
  # x and then could not work out which machine it had just used.
  MACHINE="${MACHINE:-${CPEN_VM:-}}"
  if [ -n "${MACHINE:-}" ]; then note "machine: $MACHINE (configured)"; return 0; fi
  command -v orb >/dev/null 2>&1 || { fail "orb not found - is OrbStack installed?"; return 1; }

  local running names n
  # orb prints a header row only when stdout is a TTY, so do not skip a
  # line by number - filter the header out by name instead.
  names=$(orb list 2>/dev/null | awk '$1!="NAME" && $2=="running" {print $1}')
  n=$(printf '%s\n' "$names" | grep -c . )
  if [ "$n" -eq 1 ]; then
    MACHINE=$names; note "machine: $MACHINE (only one running)"
  elif [ "$n" -eq 0 ]; then
    fail "no OrbStack machine is running. Start one:  orb start <name>"; return 1
  else
    # Perfectly ordinary for an OrbStack user to have other machines, so
    # say how to choose rather than just refusing.
    fail "several machines running; say which one holds the toolchain."
    printf '%s\n' "$names" | sed 's/^/        /' >&2
    printf '      Either set MACHINE in %s, or run once with:\n' "$CONFIG_FILE" >&2
    printf '        CPEN_VM=<name> cpen-setup --config-only\n' >&2
    return 1
  fi
}

# Quartus root. Four strategies, cheapest first.
detect_install() {
  if [ -n "${INSTALL:-}" ]; then note "install: $INSTALL (configured)"; return 0; fi

  local root
  root=$(vm 'echo "${QUARTUS_ROOTDIR:-}"')
  if [ -n "$root" ] && vm "[ -d '$root' ]"; then
    INSTALL=$(dirname "$root"); note "install: $INSTALL (from QUARTUS_ROOTDIR)"; return 0
  fi

  root=$(vm 'for d in /opt/altera* /opt/intelFPGA* "$HOME"/intelFPGA* "$HOME"/altera*; do
               [ -d "$d/quartus" ] && { echo "$d"; break; }; done')
  if [ -n "$root" ]; then
    INSTALL=$root; note "install: $INSTALL (found on disk)"; return 0
  fi

  # Last resort: ask an interactive shell, which is the only one that has
  # the student's PATH, and walk back up from the binary.
  root=$(vm_i 'command -v quartus_pgm' | tail -1)
  if [ -n "$root" ]; then
    INSTALL=${root%/quartus/*}; note "install: $INSTALL (from PATH)"; return 0
  fi

  fail "cannot find a Quartus install. Set INSTALL in $CONFIG_FILE"
  return 1
}

# Gist 1 documents quartus/bin; the Windows-derived Makefiles use bin64.
detect_bindir() {
  if [ -n "${QUARTUS_BIN:-}" ]; then note "bin: $QUARTUS_BIN (configured)"; return 0; fi
  local d
  for d in "$INSTALL/quartus/bin" "$INSTALL/quartus/bin64" \
           "$INSTALL/qprogrammer/quartus/bin" "$INSTALL/qprogrammer/quartus/bin64"; do
    if vm "[ -x '$d/quartus_pgm' ]"; then
      QUARTUS_BIN=$d; note "bin: $QUARTUS_BIN"; return 0
    fi
  done
  fail "no quartus_pgm under $INSTALL - is the install complete?"
  return 1
}

# --------------------------------------------------------------- board ---
# Map a JTAG device to a board. IDCODE first; the device name that
# jtagconfig prints alongside it is the fallback, because it survives
# silicon revisions that change the IDCODE.
#
# 4BA00477 is the ARM HPS on the SoC boards - a real device in the chain
# but NOT the FPGA, which is why DE1-SoC programs at index 2 and
# DE10-Lite at index 1. Never assume the index; count it.
board_for() {
  case "$1" in
    031050DD) echo "DE10-Lite";  return ;;
    02D120DD) echo "DE1-SoC";    return ;;
    4BA00477) echo "__HPS__";    return ;;
  esac
  case "$2" in
    *10M50*)          echo "DE10-Lite" ;;
    *5CSEMA5*|*5CSE*) echo "DE1-SoC" ;;
    *5CSEBA6*)        echo "DE10-Nano" ;;
    *5CSXFC6*)        echo "DE10-Standard" ;;
    *SOCVHPS*)        echo "__HPS__" ;;
    *)                echo "" ;;
  esac
}

# Parse jtagconfig output on stdin. It looks like:
#     1) USB-Blaster [1-1]
#       031050DD   10M50DA(.|ES)/10M50DC
# or, on a DE1-SoC, two devices where the FIRST is the HPS, which is why
# that board programs at index 2 and the DE10-Lite at index 1.
#
# Split out from detect_chain so it can be tested against boards that are
# not plugged in - see tests/chain_test.sh.
parse_chain() {
  local line idx=0 code name board
  while IFS= read -r line; do
    case "$line" in
      *')'*'['*)                                  # cable line
        CABLE=${CABLE:-$(printf '%s' "$line" | sed -n 's/^[0-9]*)[[:space:]]*\(.*\)$/\1/p')}
        continue ;;
    esac
    code=$(printf '%s' "$line" | awk '{print $1}')
    name=$(printf '%s' "$line" | awk '{print $2}')
    case "$code" in [0-9A-Fa-f][0-9A-Fa-f]*) ;; *) continue ;; esac
    idx=$((idx + 1))
    board=$(board_for "$code" "$name")
    [ "$board" = "__HPS__" ] && continue           # in the chain, not the FPGA
    if [ -n "$board" ]; then
      BOARD=${BOARD:-$board}; JTAG_INDEX=${JTAG_INDEX:-$idx}; IDCODE=${IDCODE:-$code}
    fi
  done
  [ -n "${BOARD:-}" ]
}

detect_chain() {
  local out
  out=$(vm "'$QUARTUS_BIN/jtagconfig'")
  if [ -z "$out" ] || printf '%s' "$out" | grep -qi "No JTAG hardware"; then
    note "chain: no JTAG hardware visible"
    return 1
  fi
  if ! parse_chain <<< "$out"; then
    fail "chain readable but no FPGA recognised. Set BOARD in $CONFIG_FILE"
    note "jtagconfig said:"; printf '%s\n' "$out" | sed 's/^/        /' >&2
    return 1
  fi
  note "board: $BOARD  (IDCODE $IDCODE, chain index $JTAG_INDEX, cable '$CABLE')"
}

# The prebuilt Nios V system for this board. Globbed, never hardcoded:
# DE10-Nano and DE10-Standard ship source only, with no niosVg/*.sof.
detect_sof() {
  if [ -n "${SOF:-}" ]; then note "sof: $SOF (configured)"; return 0; fi
  [ -n "${BOARD:-}" ] || return 1
  SOF=$(vm "ls '$INSTALL/fpgacademy/Computer_Systems/$BOARD/'*_Computer/niosVg/*.sof 2>/dev/null | head -1")
  if [ -z "$SOF" ]; then
    fail "no prebuilt .sof for $BOARD under $INSTALL/fpgacademy"
    note "that board may ship source only - build it, then set SOF in $CONFIG_FILE"
    return 1
  fi
  note "sof: $SOF"
}

# --------------------------------------------------------------- tools ---
detect_tools() {
  local missing="" t p
  for t in quartus_pgm jtagconfig nios2-terminal; do
    vm "[ -x '$QUARTUS_BIN/$t' ]" || missing="$missing $t"
  done
  GDBSRV="$INSTALL/riscfree/debugger/gdbserver-riscv/ash-riscv-gdb-server"
  vm "[ -x '$GDBSRV' ]" || { missing="$missing ash-riscv-gdb-server"; GDBSRV=""; }
  NIOSV_BIN="$INSTALL/niosv/bin"
  vm "[ -x '$NIOSV_BIN/niosv-download' ]" || missing="$missing niosv-download"
  RISCV_BIN="$INSTALL/riscfree/toolchain/riscv32-unknown-elf/bin"
  vm "[ -d '$RISCV_BIN' ]" || missing="$missing riscv32-unknown-elf toolchain"

  if [ -n "$missing" ]; then
    fail "missing from the install:$missing"
    note "Gist 1's 'qinst.sh --auto-install' installs all of this (~14 GB)."
    TOOLCHAIN_OK=0
  else
    TOOLCHAIN_OK=1; note "toolchain: complete"
  fi

  # Profile B is only informational until someone needs it.
  p=$(vm_i 'command -v clang' | tail -1)
  LLVM_OK=0; [ -n "$p" ] && LLVM_OK=1
}

# --------------------------------------------------------- simulation ---
# Questa needs a licence file even though the Starter edition is free, and
# it is named by SALT_LICENSE_SERVER. The file lives on the Mac at a path
# the VM sees unchanged, so one string works on both sides.
# A licence date -> yyyymmdd, so two can be compared as numbers without
# depending on BSD or GNU date's very different parsing flags. Altera puts
# the expiry in dd-mmm-yyyy and the issue date in mm/dd/yyyy, in the same
# file, so both forms are read here.
lic_daynum() {
  printf '%s' "$1" | awk '
    BEGIN { split("jan feb mar apr may jun jul aug sep oct nov dec", n, " ")
            for (i in n) m[n[i]] = i }
    /^[0-9]+\/[0-9]+\/[0-9]+$/ {
      split($0, d, "/"); printf "%04d%02d%02d", d[3], d[1], d[2]; next }
    { split($0, d, "-")
      mo = m[tolower(d[2])]
      if (mo != "" && d[3] != "") printf "%04d%02d%02d", d[3], mo, d[1] }'
}

detect_questa() {
  QUESTA_BIN="$INSTALL/questa_fse/linux_x86_64"
  if ! vm "[ -x '$QUESTA_BIN/vsim' ]"; then
    QUESTA_BIN=""; QUESTA_OK=0
    note "questa: not installed"
    return 0
  fi
  if [ -z "${SALT_LICENSE_SERVER:-}" ]; then
    local f
    for f in "$CONFIG_HOME"/*.dat "$HOME/.altera"/*.dat "$INSTALL/licenses"/*.dat; do
      [ -f "$f" ] && grep -qi "intelqsimstarter\|mgcld" "$f" 2>/dev/null         && { SALT_LICENSE_SERVER=$f; break; }
    done
  fi
  if [ -z "${SALT_LICENSE_SERVER:-}" ]; then
    QUESTA_OK=0
    note "questa: installed, but no licence found (simulation will not run)"
    note "        put the .dat from Altera's SSLC in $CONFIG_HOME/"
  elif [ ! -f "$SALT_LICENSE_SERVER" ]; then
    QUESTA_OK=0
    note "questa: licence path does not exist: $SALT_LICENSE_SERVER"
  else
    # The licence is node-locked to a NIC. A file that merely exists proves
    # nothing: copied between machines it parses fine and then fails at
    # checkout, which is a confusing way to find out.
    local exp start nic mac
    # start= is a separate field from the expiry, and grabbing whichever
    # date came first called a licence good that had not begun yet. Altera
    # issues them dated from its own timezone, so a fresh one is routinely
    # a day ahead of you, and the only symptom is vsim saying "Feature
    # start date is in the future" at the moment you try to simulate.
    start=$(grep -oiE "start=[0-9]{1,2}-[a-z]{3}-[0-9]{4}" "$SALT_LICENSE_SERVER" \
              | head -1 | cut -d= -f2)
    # Altera does not write start=; it stamps an issue date instead, and
    # FlexLM refuses the feature until that day has arrived.
    [ -n "$start" ] || start=$(grep -oiE "issued[: ]+[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}" \
                                 "$SALT_LICENSE_SERVER" | head -1 \
                                 | grep -oE "[0-9]+/[0-9]+/[0-9]+")
    exp=$(grep -oiE "(start=)?[0-9]{1,2}-[a-z]{3}-[0-9]{4}" "$SALT_LICENSE_SERVER" \
            | grep -viE "^start=" | head -1)
    nic=$(grep -oiE "[0-9A-F]{12}" "$SALT_LICENSE_SERVER" | head -1 | tr 'a-f' 'A-F')
    mac=$(vm "cat /sys/class/net/eth0/address" | tr -d ':' | tr 'a-f' 'A-F')
    if [ -n "$nic" ] && [ -n "$mac" ] && [ "$nic" != "$mac" ]; then
      QUESTA_OK=0
      fail "questa licence is for NIC $nic but this VM is $mac"
      note "        generate one for $mac at the Altera SSLC, or simulation will fail"
    elif [ -n "$start" ] && [ "$(lic_daynum "$start")" -gt "$(date +%Y%m%d)" ] 2>/dev/null; then
      QUESTA_OK=0
      fail "questa licence is dated $start, and today is $(date '+%m/%d/%Y')"
      note "        Nothing is wrong with it. Altera stamps licences in UTC, so"
      note "        one requested after about 5pm Pacific is dated tomorrow, and"
      note "        FlexLM refuses the feature until that day arrives. Simulation"
      note "        starts working by itself at midnight; the rest works now."
    else
      QUESTA_OK=1
      note "questa: licensed${exp:+, expires $exp}${start:+, from $start}"
    fi
  fi
}

# ----------------------------------------------------------- USB (Mac) ---
# orb usb lives on the MAC, not in the VM: a process inside the guest
# cannot re-attach its own passthrough.
detect_usb() {
  USB_ID=$(orb usb list 2>/dev/null | awk -v p="${USB_VIDPID:-09fb:6001}" '$2==p {print $1; exit}')
  if [ -z "$USB_ID" ]; then
    note "usb: no Altera cable (${USB_VIDPID:-09fb:6001}) - is the board plugged in and powered?"
  else
    note "usb: $USB_ID"
  fi
}

# ----------------------------------------------------------------- run ---
# Sourcing with DETECT_LIB_ONLY=1 gives the functions without probing, so
# the tests can exercise the parser directly.
[ -n "${DETECT_LIB_ONLY:-}" ] && return 0

[ -n "${DETECT_QUIET:-}" ] || echo "Detecting..." >&2

detect_machine || exit 1
detect_install  || exit 1
detect_bindir   || exit 1
detect_tools
detect_questa
detect_usb
detect_chain && detect_sof

emit MACHINE      "$MACHINE"
emit INSTALL      "$INSTALL"
emit QUARTUS_BIN  "$QUARTUS_BIN"
emit NIOSV_BIN    "${NIOSV_BIN:-}"
emit RISCV_BIN    "${RISCV_BIN:-}"
emit GDBSRV       "${GDBSRV:-}"
emit BOARD        "${BOARD:-}"
emit IDCODE       "${IDCODE:-}"
emit JTAG_INDEX   "${JTAG_INDEX:-}"
emit CABLE        "${CABLE:-}"
emit SOF          "${SOF:-}"
emit USB_ID       "${USB_ID:-}"
emit USB_VIDPID   "${USB_VIDPID:-09fb:6001}"
emit GDB_PORT     "${GDB_PORT:-2454}"
emit TERM_INSTANCE "${TERM_INSTANCE:-0}"
emit TOOLCHAIN    "${TOOLCHAIN:-proprietary}"
emit TOOLCHAIN_OK "${TOOLCHAIN_OK:-0}"
emit LLVM_OK      "${LLVM_OK:-0}"
emit QUESTA_BIN   "${QUESTA_BIN:-}"
emit QUESTA_OK    "${QUESTA_OK:-0}"
emit SALT_LICENSE_SERVER "${SALT_LICENSE_SERVER:-}"
