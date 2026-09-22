#!/usr/bin/env bash
#
# The chain parser decides which board you have and which index to program.
# Only one board can be plugged in at a time, so the rest are tested here
# against captured jtagconfig output.
#
# The DE1-SoC case is quoted verbatim from Gist 1; it has TWO devices and
# the FPGA is the second, which is the whole reason the index is counted
# rather than assumed.
#
cd "$(dirname "$0")/.." || exit 1
DETECT_LIB_ONLY=1 DETECT_QUIET=1 . lib/detect.sh

pass=0; fail=0
check() { # name input want_board want_index want_cable
  local name=$1 input=$2 wb=$3 wi=$4 wc=$5
  unset BOARD JTAG_INDEX IDCODE CABLE
  parse_chain <<< "$input"
  if [ "${BOARD:-}" = "$wb" ] && [ "${JTAG_INDEX:-}" = "$wi" ] && [ "${CABLE:-}" = "$wc" ]; then
    printf '  ok    %s\n' "$name"; pass=$((pass+1))
  else
    printf '  FAIL  %s\n        want board=%s index=%s cable=%s\n        got  board=%s index=%s cable=%s\n' \
      "$name" "$wb" "$wi" "$wc" "${BOARD:-}" "${JTAG_INDEX:-}" "${CABLE:-}"
    fail=$((fail+1))
  fi
}

check "DE10-Lite, single device" \
'1) USB-Blaster [1-1]
  031050DD   10M50DA(.|ES)/10M50DC' \
  "DE10-Lite" "1" "USB-Blaster [1-1]"

# Gist 1's own transcript. The HPS is at position 1, the FPGA at 2.
check "DE1-SoC, HPS first then FPGA" \
'1) DE-SoC [1-1]
  4BA00477   SOCVHPS
  02D120DD   5CSE(BA5|MA5)/5CSTFD5D5/..' \
  "DE1-SoC" "2" "DE-SoC [1-1]"

# Gist 2 hardcodes -c "USB-Blaster [USB-0]" and the author noted it did not
# match theirs. Whatever the cable is called, we use what jtagconfig says.
check "unusual cable name is taken as-is" \
'1) USB-Blaster [USB-0]
  031050DD   10M50DA(.|ES)/10M50DC' \
  "DE10-Lite" "1" "USB-Blaster [USB-0]"

# An unknown IDCODE must fall back to the device-name pattern.
check "unknown IDCODE, known family name" \
'1) USB-Blaster [1-1]
  0BADC0DE   10M50DA(.|ES)/10M50DC' \
  "DE10-Lite" "1" "USB-Blaster [1-1]"

# Nothing recognisable must fail, not guess.
unset BOARD JTAG_INDEX IDCODE CABLE
if parse_chain <<< '1) USB-Blaster [1-1]
  12345678   SOMETHING_ELSE'; then
  printf '  FAIL  unknown device should not be identified as a board\n'; fail=$((fail+1))
else
  printf '  ok    unknown device is rejected, not guessed\n'; pass=$((pass+1))
fi

# A configured BOARD must win over detection.
BOARD=DE1-SoC; JTAG_INDEX=2; unset IDCODE CABLE
parse_chain <<< '1) USB-Blaster [1-1]
  031050DD   10M50DA(.|ES)/10M50DC'
if [ "$BOARD" = "DE1-SoC" ] && [ "$JTAG_INDEX" = "2" ]; then
  printf '  ok    configured board overrides detection\n'; pass=$((pass+1))
else
  printf '  FAIL  config was overwritten by detection (got %s/%s)\n' "$BOARD" "$JTAG_INDEX"; fail=$((fail+1))
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
