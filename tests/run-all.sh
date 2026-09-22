#!/usr/bin/env bash
# Everything that can run without a board attached.
cd "$(dirname "$0")/.." || exit 1
fail=0
echo "== syntax =="
for f in lib/*.sh bin/cpen-init bin/cpen-gui bin/cpen-setup \
         bin/cpen-uninstall bin/cpen-verilog tests/*.sh; do
  bash -n "$f" && echo "  ok    $f" || fail=1
done
python3 -c "import ast;ast.parse(open('bin/cpen-nios').read())" \
  && echo "  ok    bin/cpen-nios" || fail=1

echo; echo "== no lab content =="
./tests/no-lab-content.sh | sed 's/^/  /' || fail=1

echo; echo "== board detection =="
./tests/chain_test.sh | sed 's/^/  /' || fail=1

echo; echo "== PATH line =="
./tests/path_test.sh | sed 's/^/  /' || fail=1

echo; echo "== uninstall, the profile edit =="
./tests/uninstall_test.sh | sed 's/^/  /' || fail=1

echo; echo "== open prompt =="
python3 tests/open_test.py | sed 's/^/  /' || fail=1

echo; echo "== layout =="
python3 tests/render_test.py --check | sed 's/^/  /' || fail=1

echo; echo "== makefile, every board =="
for b in DE10-Lite DE1-SoC; do
  make -f share/Makefile.linux WHICH BOARD=$b INSTALL=/nonexistent >/dev/null 2>&1 \
    && echo "  ok    $b" || { echo "  FAIL  $b"; fail=1; }
done
make -f share/Makefile.linux WHICH TOOLCHAIN=llvm >/dev/null 2>&1 \
  && echo "  ok    TOOLCHAIN=llvm" || { echo "  FAIL  TOOLCHAIN=llvm"; fail=1; }
make -f share/Makefile.linux WHICH TOOLCHAIN=bogus >/dev/null 2>&1 \
  && { echo "  FAIL  bogus toolchain should be rejected"; fail=1; } \
  || echo "  ok    bogus toolchain rejected"

echo
[ $fail = 0 ] && echo "all ok" || echo "FAILURES"
exit $fail
