# Troubleshooting

Most failures are one of three things: the USB passthrough went stale, `jtagd`
is holding a dead handle, or another process owns the JTAG cable. **Pressing
`F1` fixes all three**, so try that first.

---

## `jtagconfig` says "No JTAG hardware available"

Usually after unplugging and replugging the board.

`jtagd` keeps a handle to a device node that no longer exists after a replug
and will not recover on its own. It respawns automatically the next time
`jtagconfig` runs, so killing it is enough:

```bash
orb -m altera bash -c 'pkill -f "linux64/[j]tagd"'
```

Bracketing the `j` is not a typo. `pkill -f` also matches the shell carrying
the pattern, so an unbracketed pattern kills its own shell.

`F1` does this for you and retries the chain.

## OrbStack says the cable is attached but `lsusb` shows nothing

The passthrough mapping is stale. Reporting "attached" is not the same as the
VM having it. Only a full cycle rebuilds it:

```bash
orb usb detach <ID>   # ID from: orb usb list
orb usb attach <ID>
```

`F1` always detaches before attaching for exactly this reason.

Note `orb usb` is a **macOS** command. A process inside the VM cannot
re-attach its own passthrough, which is why this tool runs on the host.

## `Error (209042): Application nios2-terminal ... is using the target device`

Only one program may own the JTAG cable. `quartus_pgm` needs it exclusively,
so `nios2-terminal` and the debug server must be stopped first and restarted
afterwards. `F2` does the whole dance; `F6` just frees the cable.

## The program runs but nothing appears in FPGA StdOut

Check the pane's status glyph. A red `✗` means `nios2-terminal` is not
running and the pane says so in the middle. Press `F1`.

A green `●` with no output usually means the program really did not print.
On the Lab 0 program, all switches down exits the loop before printing.

## `A syntax error in expression, near '=0'` from GDB

The `-ex` arguments must be in **single** quotes in the Makefile. Make turns
`$$` into `$`, and inside double quotes the shell then expands `$mstatus` to
nothing, so GDB receives `set =0`. The bundled Makefile has this fixed; if you
are using the course's Windows Makefile or the published gist version, this is
the bug.

Check what your shell will actually send with:

```bash
make -f share/Makefile.linux -n GDB_CLIENT
```

## "Waiting for debugger connection on port 33491"

That random port is not the standing debug server. `niosv-download` starts its
own private server on a free port for each download and shuts it down after.
Nothing is wrong and nothing leaks.

## The board keeps disconnecting

Re-enumeration cannot be prevented from inside the VM, because OrbStack's
virtual USB controller exposes no power-management controls. The causes are physical: the
DE10-Lite is bus-powered, and a USB-C adapter is the usual culprit. Try a
different cable or a powered hub.

The console notices a chain that has gone away and restarts `jtagd` on its own.

## Questa says the licence is invalid, the day you got it

```
** License Issue: Feature start date is in the future.
** Error: Failure to obtain a Verilog simulation license.
         Unable to checkout 'intelqsimstarter' license.
```

Your licence is fine. Altera stamps them in UTC, so one requested after
about 5pm Pacific carries tomorrow's date, and FlexLM refuses the feature
until that day actually arrives on your clock. It starts working by itself
at midnight. Nothing to re-request, nothing to reinstall.

`lib/detect.sh` spots this and says so:

```
detect: questa licence is dated 09/22/2026, and today is 09/21/2026
```

Everything except simulation works meanwhile: synthesis, programming the
board, the Nios V flow and both GUIs.

Two other things produce the same "invalid licence" wording, and these do
need action:

**A licence for a different VM.** The file is node-locked to the VM's NIC,
and OrbStack gives every machine it creates a fresh random MAC, so deleting
and recreating a VM invalidates it even under the same name. Detection says
`questa licence is for NIC ... but this VM is ...`. Request a new one for
the NIC that `cpen-setup` prints.

**`SALT_LICENSE_SERVER` not reaching the simulator.** Check with:

```bash
orb -m altera bash -c 'echo $SALT_LICENSE_SERVER'
```

`cpen-gui` exports it into both VNC sessions, so a Questa started any other
way inside the VM will not have it.

## Detection got something wrong

Run it directly to see every probe:

```bash
./lib/detect.sh
```

Then override just the wrong value **above** the generated block in
`~/.config/cpen-tools/config`; re-running `cpen-setup` keeps your overrides.

---

# Notes for contributors

Bugs that cost real time here, recorded so they are not rediscovered.

## `orb` kills background processes when stdin is a TTY

Servers started by the bring-up script reported success and vanished a second
later, but only when launched from the console, not from a shell.

Given a TTY on stdin, `orb` allocates a remote pty and negotiates terminal
capabilities with it. Backgrounded processes are torn down with that session,
and the capability queries it emits land in the caller's terminal, which
corrupted the curses display. Launching the same server both ways:

```
stdin = pipe  ->  launcher printed nothing,           listening: 1
stdin = pty   ->  launcher printed \033]11;?\033[6n,  listening: 0
```

Every `orb` invocation must therefore redirect stdin:

```bash
orb -m "$MACHINE" bash -c "$*" < /dev/null
```

and every `subprocess` call passes `stdin=subprocess.DEVNULL`.

## A command that reads stdin eats the completion marker

The console runs VM commands down one persistent bash and writes a marker
line after each to know when it finished. `RUN` hung forever because
`niosv-download` runs GDB, GDB reads stdin, and stdin was the same pipe the
marker was queued on. Proof: `echo PROBE` answered instantly during the
"hang". The shell was fine, its input had been stolen.

Each command is wrapped in a brace group with its own stdin:

```bash
{ cd somewhere && labmake RUN ; } < /dev/null
```

A brace group, not a subshell, so `cd` still changes the persistent shell.

## `bash -lc` does not see the toolchain

Ubuntu's `~/.bashrc` returns early for non-interactive shells, and `~/.profile`
only sources it for interactive bash. So a login shell finds no `quartus_pgm`.
Only `bash -ic` does.

Never rely on the student's PATH. `detect.sh` resolves the install root
explicitly and the console injects PATH and `QUARTUS_ROOTDIR` into the shell
it opens.

## `curses.addnstr` counts bytes, not characters

Every box-drawing character is 3 bytes in UTF-8, so on a 165-column terminal
only 55 were drawn and the frames looked broken. Truncate by characters and
use `addstr`. Also `locale.setlocale(locale.LC_ALL, "")` must run before
curses starts.

## `pgrep -a NAME` silently fails for long names

Names over 15 characters never match, which made `ash-riscv-gdb-server` look
dead while it was running. Always use `pgrep -f`.
