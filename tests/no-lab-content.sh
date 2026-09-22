#!/usr/bin/env bash
#
# Fails if anything that looks like course material is committed.
#
# This repo is public and lab solutions are not ours to publish. gitignore
# is not enough on its own: `git add -f` bypasses it, and a renamed file
# slips through, so check what is actually tracked.
#
cd "$(dirname "$0")/.." || exit 1

# Extensions that only ever belong to a lab, not to this tool.
BAD_EXT='\.(s|o|elf|srec|sof|pof|rbf|qpf|qsf|qws|sdc|v|sv|vhd|vhdl|bsf|bdf)$'

# Files we legitimately ship that would otherwise trip the scan.
ALLOW='^(share/Makefile\.linux|tests/.*\.sh|.*\.md)$'

tracked=$(git ls-files 2>/dev/null) || { echo "not a git repo - nothing to check"; exit 0; }

hits=$(printf '%s\n' "$tracked" | grep -Ei "$BAD_EXT" | grep -Ev "$ALLOW")
if [ -n "$hits" ]; then
  echo "Lab content found in the repository:" >&2
  printf '%s\n' "$hits" | sed 's/^/    /' >&2
  echo >&2
  echo "Remove it:  git rm --cached <file>" >&2
  exit 1
fi

# Tool output that carries paths from whoever ran it. `transcript` has no
# extension, so the check above cannot see it, and one reached a commit
# that way.
JUNK='^(transcript([0-9]+)?|vsim\.wlf|vsim_stacktrace\.vstf|modelsim\.ini)$|(^|/)(work|db|incremental_db|output_files)/'
junk=$(printf '%s\n' "$tracked" | grep -E "$JUNK")
if [ -n "$junk" ]; then
  echo "Tool output found in the repository:" >&2
  printf '%s\n' "$junk" | sed 's/^/    /' >&2
  echo >&2
  echo "These carry local paths. Remove them:  git rm --cached <file>" >&2
  exit 1
fi

# A lab handout directory pattern, e.g. 2026w1-lab-0-part-2-team-name
dirs=$(printf '%s\n' "$tracked" | grep -Ei '(^|/)[0-9]{4}w[0-9]-lab|(^|/)lab[0-9]+/')
if [ -n "$dirs" ]; then
  echo "Lab directory found in the repository:" >&2
  printf '%s\n' "$dirs" | sed 's/^/    /' >&2
  exit 1
fi

echo "ok    no lab content tracked ($(printf '%s\n' "$tracked" | grep -c .) files)"
