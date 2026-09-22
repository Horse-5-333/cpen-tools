#!/usr/bin/env bash
#
# Taking the PATH line back out of your shell profile.
#
# This edits a file full of things the reader wrote themselves, so the
# interesting cases are all about what it must NOT touch.
#
cd "$(dirname "$0")/.." || exit 1
CPEN_UNINSTALL_LIB_ONLY=1 . bin/cpen-uninstall

pass=0; fail=0
SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT

check() { # check <name> <tag> <input> <want>
  local name=$1 tag=$2 got
  printf '%s' "$3" > "$SB/p"
  got=$(strip_path_line "$tag" "$SB/p")
  if [ "$got" = "$4" ]; then printf '  ok    %s\n' "$name"; pass=$((pass+1))
  else
    printf '  FAIL  %s\n' "$name"
    printf '        want |%s|\n        got  |%s|\n' "$4" "$got"
    fail=$((fail+1))
  fi
}

T='# added by cpen-setup'
P='export PATH="/repo/bin:$PATH"'

check "removes the tag and the export under it" "$T" \
'alias ll="ls -l"

'"$T"'
'"$P"'
' \
'alias ll="ls -l"'

# The installer writes a blank line before the tag, so taking it back is
# part of leaving the profile as it was found.
check "takes the blank line above it too" "$T" \
'a=1

'"$T"'
'"$P"'
b=2
' \
'a=1
b=2'

check "at the top of the file" "$T" \
"$T"'
'"$P"'
a=1
' \
'a=1'

check "at the end of the file" "$T" \
'a=1
'"$T"'
'"$P" \
'a=1'

# The one that used to go wrong: with anything between the tag and the
# export, the old version stayed armed and deleted the next PATH line it
# found, which could be one the reader wrote.
check "a line in between: keeps the reader's own PATH" "$T" \
"$T"'
# a note someone added
export PATH="/my/own/tools:$PATH"
alias x=y
' \
'# a note someone added
export PATH="/my/own/tools:$PATH"
alias x=y'

check "a later unrelated PATH line survives" "$T" \
"$T"'
'"$P"'
alias x=y
export PATH="/my/own/tools:$PATH"
' \
'alias x=y
export PATH="/my/own/tools:$PATH"'

check "no tag: the file is untouched" "$T" \
'a=1

export PATH="/my/own/tools:$PATH"
b=2
' \
'a=1

export PATH="/my/own/tools:$PATH"
b=2'

check "an old tag is removed when that is what was found" \
'# added by fpga-nios setup.sh' \
'a=1
# added by fpga-nios setup.sh
'"$P"'
b=2
' \
'a=1
b=2'

check "runs of blank lines are not collapsed away" "$T" \
'a=1


b=2
' \
'a=1


b=2'

# found_tag decides which tag the profile is carrying.
ft() { printf '%s\nexport PATH=x\n' "$1" > "$SB/p"; found_tag "$SB/p"; }
for t in '# added by cpen-setup' '# added by fpga-setup' \
         '# added by fpga-nios setup.sh' '# added by fpga-console setup.sh'; do
  got=$(ft "$t")
  if [ "$got" = "$t" ]; then printf '  ok    finds %s\n' "${t#\# added by }"; pass=$((pass+1))
  else printf '  FAIL  finds %s: got |%s|\n' "$t" "$got"; fail=$((fail+1)); fi
done
got=$(ft '# something else')
if [ -z "$got" ]; then printf '  ok    an unrelated comment is not a tag\n'; pass=$((pass+1))
else printf '  FAIL  unrelated comment matched: |%s|\n' "$got"; fail=$((fail+1)); fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
