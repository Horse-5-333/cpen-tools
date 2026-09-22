#!/usr/bin/env python3
"""Render the console against a fake curses screen.

A real terminal is not needed and not wanted: this is ground truth for
layout, where a pty plus a VT emulator is not. Run it to eyeball the
panes, or with --check to assert the frames close properly.
"""
import curses
import importlib.util
import os
import sys
from importlib.machinery import SourceFileLoader

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The console has no .py extension, so importlib cannot infer a loader
# from the filename - name one explicitly.
_path = os.path.join(ROOT, "bin", "cpen-nios")
spec = importlib.util.spec_from_loader("fc", SourceFileLoader("fc", _path))
fc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fc)

ROWS, COLS = 30, 120


class Fake:
    def __init__(s): s.b = [[" "] * COLS for _ in range(ROWS)]
    def getmaxyx(s): return (ROWS, COLS)
    def erase(s): s.b = [[" "] * COLS for _ in range(ROWS)]
    def refresh(s): pass
    def addstr(s, y, x, text, attr=0):
        if not (0 <= y < ROWS):
            raise curses.error
        for i, c in enumerate(text):
            if 0 <= x + i < COLS:
                s.b[y][x + i] = c
    def addnstr(s, y, x, text, n, attr=0): s.addstr(y, x, text[:n], attr)
    def dump(s): return ["".join(r).rstrip() for r in s.b]


curses.color_pair = lambda n: 0


def shot(app, name, show=True):
    scr = Fake()
    fc.draw(scr, app)
    lines = scr.dump()
    if show:
        print("#" * COLS)
        print(f"### {name}")
        print("#" * COLS)
        print("\n".join(lines))
        print()
    return lines


def main():
    check = "--check" in sys.argv
    app = fc.Console()
    app.polled = True
    app.cwd = "/home/you/CPEN211/lab0"
    app.buf, app.cur = "", 0
    app.vm.add("$ labmake COMPILE")

    cases = []

    app.st.update(machine=True, usb=True, idcode="031050DD", term=False, gdbsrv=False)
    app.show_debug = True
    cases.append(("servers down: panes explain themselves", shot(app, "servers down", not check)))

    app.st.update(term=True, gdbsrv=True)
    app.out.add("Hello World!")
    cases.append(("running", shot(app, "running", not check)))

    app.busy, app.phase = True, "PROGRAMMING"
    cases.append(("busy", shot(app, "busy: spinner and phase", not check)))

    if not check:
        return 0

    bad = 0
    for name, lines in cases:
        for i, ln in enumerate(lines):
            # Frames must close: a line that opens a box must end with one.
            if ln.startswith("┌") or ln.startswith("└"):
                if not (ln.endswith("┐") or ln.endswith("┘")):
                    print(f"FAIL  {name}: row {i} frame does not close: {ln[-8:]!r}")
                    bad += 1
            if ln.startswith("│") and not ln.endswith("│"):
                print(f"FAIL  {name}: row {i} side does not close")
                bad += 1
        print(f"  ok    {name}" if not bad else f"  FAIL  {name}")
    print("\nlayout ok" if not bad else f"\n{bad} layout problems")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
