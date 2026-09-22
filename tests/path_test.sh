#!/usr/bin/env bash
#
# The one line configure.sh adds to your shell profile.
#
# This is the only part of setup that edits a file you own, so it is worth
# testing properly: which file it picks, when it appends, and above all
# when it must NOT, since appending twice leaves a profile that grows by a
# line on every upgrade.
#
cd "$(dirname "$0")/.." || exit 1
CONFIGURE_LIB_ONLY=1 . lib/configure.sh

pass=0; fail=0
say() { # say <name> <got> <want>
  if [ "$2" = "$3" ]; then printf '  ok    %s\n' "$1"; pass=$((pass+1))
  else printf '  FAIL  %s\n        want %s\n        got  %s\n' "$1" "$3" "$2"
       fail=$((fail+1)); fi
}

SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT

# A sandbox home, and a PATH with no cpen-nios on it: the real one is on
# this machine's PATH and would short-circuit every case below.
run() { # run <shell> [--no-path]; sets $out
  HOME="$SB" SHELL="$1" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    DO_PATH=$([ "${2:-}" = "--no-path" ] && echo 0 || echo 1) \
    out=$(announce_path 2>&1)
}
lines() { grep -c . "$1" 2>/dev/null || echo 0; }
tagged() { grep -cF "$TAG" "$1" 2>/dev/null || echo 0; }

fresh() { rm -rf "$SB"; mkdir -p "$SB"; }

# A profile that does not exist yet
fresh
run /bin/zsh
say "zsh, no profile: writes .zshrc" "$(tagged "$SB/.zshrc")" "1"
say "zsh, no profile: one PATH line" \
  "$(grep -c '^export PATH=' "$SB/.zshrc")" "1"

# Running again must not add a second line
run /bin/zsh
say "second run adds nothing" "$(grep -c '^export PATH=' "$SB/.zshrc")" "1"
say "second run says so" \
  "$(printf '%s' "$out" | grep -c 'already on your PATH')" "1"

# Every tag an older version of this tool wrote must still be recognised,
# or an upgrade appends a second line beside the one already working.
for t in '# added by cpen-setup' \
         '# added by fpga-setup' \
         '# added by fpga-nios setup.sh' \
         '# added by fpga-console setup.sh'; do
  fresh
  printf '%s\nexport PATH="/somewhere/bin:$PATH"\n' "$t" > "$SB/.zshrc"
  run /bin/zsh
  say "recognises ${t#\# added by }" \
    "$(grep -c '^export PATH=' "$SB/.zshrc")" "1"
done

# An existing profile keeps its contents, and gains a blank line first
fresh
printf 'alias ll="ls -l"\n' > "$SB/.zshrc"
run /bin/zsh
say "existing profile keeps its own lines" \
  "$(grep -c 'alias ll' "$SB/.zshrc")" "1"
say "existing profile gains the tag" "$(tagged "$SB/.zshrc")" "1"

# bash prefers .bash_profile when it exists, .profile when it does not
fresh
: > "$SB/.bash_profile"
run /bin/bash
say "bash with .bash_profile writes there" "$(tagged "$SB/.bash_profile")" "1"
say "bash with .bash_profile leaves .profile alone" \
  "$([ -f "$SB/.profile" ] && echo 1 || echo 0)" "0"

fresh
run /bin/bash
say "bash without .bash_profile writes .profile" "$(tagged "$SB/.profile")" "1"

# A shell whose syntax we do not know is described, never edited
fresh
run /usr/local/bin/fish
say "fish: writes nothing" "$(ls -A "$SB" | grep -c .)" "0"
say "fish: says why" "$(printf '%s' "$out" | grep -c 'unrecognised shell')" "1"

# --no-path prints the line instead of writing it
fresh
run /bin/zsh --no-path
say "--no-path writes nothing" "$(ls -A "$SB" | grep -c .)" "0"
say "--no-path prints the line" \
  "$(printf '%s' "$out" | grep -c 'export PATH=')" "1"

# The running shell resolving cpen-nios proves nothing about new ones: it
# can still carry a directory from a profile line that has since been
# removed. The profile is what decides, so this must still write.
fresh
mkdir -p "$SB/bin"; printf '#!/bin/sh\n' > "$SB/bin/cpen-nios"
chmod +x "$SB/bin/cpen-nios"
HOME="$SB" SHELL=/bin/zsh PATH="$SB/bin:/usr/bin:/bin" DO_PATH=1 \
  out=$(announce_path 2>&1)
say "on this shell's PATH but not the profile: still writes" \
  "$(tagged "$SB/.zshrc")" "1"

# Added by hand, without our marker: recognised, not duplicated.
fresh
printf 'export PATH="%s/bin:$PATH"\n' "$REPO" > "$SB/.zshrc"
run /bin/zsh
say "a hand-added line is not duplicated" \
  "$(grep -c '^export PATH=' "$SB/.zshrc")" "1"
say "a hand-added line: says so" \
  "$(printf '%s' "$out" | grep -c 'already on your PATH')" "1"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
