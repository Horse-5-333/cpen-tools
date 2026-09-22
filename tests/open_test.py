#!/usr/bin/env python3
"""The Open Directory prompt: typing, pasting, completion, validation."""
import curses, importlib.util, os, sys
from importlib.machinery import SourceFileLoader
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_loader(
    "fc", SourceFileLoader("fc", os.path.join(ROOT, "bin", "cpen-nios")))
fc = importlib.util.module_from_spec(spec); spec.loader.exec_module(fc)

pass_n = fail_n = 0
def check(name, got, want):
    global pass_n, fail_n
    if got == want:
        print(f"  ok    {name}"); pass_n += 1
    else:
        print(f"  FAIL  {name}\n        want {want!r}\n        got  {got!r}"); fail_n += 1

def app_with(text=""):
    a = fc.Console.__new__(fc.Console)          # no VM, no threads
    a.openbuf, a.opencur, a.openerr = text, len(text), ""
    a.overlay, a.startdir, a.cwd = "open", "", ""
    a.sent = []
    a.run_vm = lambda cmd, phase: a.sent.append(cmd)
    return a

def typ(a, s):
    for c in s:
        fc.handle_open(a, ord(c))

# Typing
a = app_with(); typ(a, "/tmp/x")
check("typing inserts", a.openbuf, "/tmp/x")

# Pasting is just a burst of the same characters.
a = app_with()
typ(a, "/Users/someone/CPEN211/lab3")
check("paste of a long path", a.openbuf, "/Users/someone/CPEN211/lab3")

# A pasted path with a trailing newline submits, as it would in a shell.
a = app_with("/tmp")
fc.handle_open(a, 10)
check("Enter submits", a.overlay, None)
check("Enter sends a quoted cd", a.sent, ["cd '/tmp'"])

# Editing
a = app_with("/tmp/abc")
fc.handle_open(a, curses.KEY_BACKSPACE)
check("backspace", a.openbuf, "/tmp/ab")
a = app_with("/a/b/c")
fc.handle_open(a, 23)                            # Ctrl-W
check("Ctrl-W drops a path part", a.openbuf, "/a/b/")
a = app_with("/a/b/c")
fc.handle_open(a, 21)                            # Ctrl-U
check("Ctrl-U clears", a.openbuf, "")
a = app_with("/tmp/x")
fc.handle_open(a, 1); fc.handle_open(a, ord("Z"))
check("Ctrl-A goes home", a.openbuf, "Z/tmp/x")

# Completion against a real directory tree
base = os.path.join(ROOT, "tests")
a = app_with(os.path.join(ROOT, "te"))
fc.handle_open(a, ord("\t"))
check("Tab completes a unique dir", a.openbuf, base + "/")

# Validation: a Mac-visible path that does not exist is refused, not sent.
a = app_with("/Users/nobody/definitely/not/here")
fc.handle_open(a, 10)
check("bad path refused", (a.overlay, a.sent), ("open", []))
check("bad path explains", a.openerr, "no such directory")

# A VM-only path is not second-guessed here; the shell reports it.
a = app_with("/home/someone/work")
fc.handle_open(a, 10)
check("VM-only path passes through", a.sent, ["cd '/home/someone/work'"])

# A path with a space must survive as one argument. Uses a real directory,
# because a Mac-visible path that does not exist is refused before sending.
import tempfile
with tempfile.TemporaryDirectory() as td:
    spaced = os.path.join(td, "My Labs", "lab 3")
    os.makedirs(spaced)
    a = app_with(spaced)
    fc.handle_open(a, 10)
    check("space in path stays one argument", a.sent, [f"cd '{spaced}'"])

# Esc cancels without sending anything.
a = app_with("/tmp"); fc.handle_open(a, 27)
check("Esc cancels", (a.overlay, a.sent), (None, []))

print(f"\n{pass_n} passed, {fail_n} failed")
sys.exit(1 if fail_n else 0)
