# Reference

Every command, flag and setting in this repository. For a walkthrough of
installing any of it, see [SETUP.md](SETUP.md); this is the page you come
back to when you know what you want and need the exact spelling.

Six commands, all run **on the Mac**:

| Command | Purpose |
|---|---|
| [`cpen-setup`](#cpen-setup) | install the toolchain, and check an existing install |
| [`cpen-nios`](#cpen-nios) | the Nios V console |
| [`cpen-verilog`](#cpen-verilog) | the SystemVerilog build targets |
| [`cpen-gui`](#cpen-gui) | Quartus and Questa's own interfaces, over VNC |
| [`cpen-init`](#cpen-init) | board bring-up without the console |
| [`cpen-uninstall`](#cpen-uninstall) | undo what `cpen-setup` changed |

Also: [configuration file](#the-configuration-file), [environment
variables](#environment-variables), [make variables](#make-variables),
[exit codes](#exit-codes), [files and directories](#files-and-directories).

---

## cpen-setup

Runs the install guide as far as it can be automated, and re-checks an
existing install. Safe to run repeatedly: every step tests for its own
result before acting.

```
cpen-setup [--no-gui] [--no-native] [--check] [--report]
           [--config-only] [--no-path]
```

| Flag | Effect |
|---|---|
| *(none)* | everything: Mac tools, VM, toolchain, PATH, udev, GUI desktop, then detection |
| `--no-gui` | skip the VNC desktop and its packages and fonts |
| `--no-native` | skip Surfer |
| `--check` | report on every step and change nothing |
| `--report` | `--check`, plus your versions, in a block to paste into an issue |
| `--config-only` | skip the install checks, just re-detect and rewrite the config |
| `--no-path` | do not touch your shell profile; print the line instead |
| `--help`, `-h` | usage |

**It reclaims the installer downloads.** `qinst.sh` leaves
`~/quartus-install` and `~/qinst-dl` in the VM, about 6.8GB, and they are
no use once Quartus, the Rosetta patch and riscfree are all in. They go at
the end of the toolchain step, which is the earliest possible, since
riscfree is a second pass over the same unpacked installer. If anything
above failed they are kept, because a retry needs them. `--check` reports
the size instead of removing anything.

**Stops for two things it cannot do**, printing instructions and exiting 3:
downloading the Quartus installer, which is behind a login, and requesting
the Questa licence, which is a web form. For the licence it prints your VM's
NIC ID so you can paste it straight into the form.

**`--report`** is `--check` with a header naming your Mac, macOS build,
OrbStack, Python, VM, kernel, Quartus and board, wrapped in a fenced block
ready for a GitHub issue. It strips the colour escapes, replaces your home
directory with `~` and your username with `<user>`, and never reads the
licence file or the VNC password. Its exit status is the one `--check`
would have given, so a failing report still exits 1.

It works on a machine with none of this installed, which is the point:
`./bin/cpen-setup --report` out of the clone needs nothing on `PATH`, and
under `--check` the steps that would normally stop the run print `stop`
with their instructions and carry on, so the report reaches the end instead
of stopping at the first missing prerequisite.

**When to use which.** `--check` is the first thing to run when something
breaks later in the term. `--report` is what to attach when you ask someone
about it. `--config-only` is what you want after plugging
the board in, or after saving the licence file, since neither needs the
install re-verified.

**Does not install Homebrew.** It halts and gives you the official command
instead, because piping a remote script into your shell should be your
decision.

---

## cpen-nios

The console for the Nios V assembly labs. Handles the JTAG plumbing: USB
passthrough, the one-owner rule on the cable, stale `jtagd` handles, program
output and the GDB server.

```
cpen-nios
```

No flags. Everything is a key:

| Key | Action |
|---|---|
| `F1` | full bring-up: start the VM, re-attach USB, clear the cable, program the prebuilt Nios V system |
| `F2` | program the FPGA only |
| `F3` | compile your assembly |
| `F4` | run it on the board |
| `F5` | open GDB in a new terminal window |
| `F6` | stop the servers and release the board |
| `F7` | open a working folder |
| `F8` | clear the panes |
| `F9` | show the debug pane |
| `Ctrl-Q` | quit (`F10` also works, but it is the mute key on a Mac keyboard) |
| `Tab` | move focus between panes |
| `Ctrl-C` | interrupt the running command |
| arrows, PgUp/PgDn, scroll wheel | scroll the focused pane |

`F1` first, every session; the rest assume it.

It opens in the directory you ran it from, the way any other command does.
`F7` moves somewhere else.

The shell pane runs commands inside the VM, with `labmake` predefined as
`make -f <the repo's Makefile>`, so `labmake SYNTH` and friends work there.

---

## cpen-verilog

The SystemVerilog build targets, from your own terminal instead of the
console's shell pane. Runs in the current directory unless you name another.

```
cpen-verilog <TARGET> [directory] [VAR=value ...]
cpen-verilog list
cpen-verilog --help
```

| Target | Does | Takes |
|---|---|---|
| `NEWPROJECT` | turn an empty folder into a Quartus project. Run once. | seconds |
| `SYNTH` | compile your Verilog to a bitstream | ~30s |
| `PROGRAM_PROJECT` | load that bitstream onto the board | ~3s |
| `SIM` | compile and run your testbench | seconds |
| `SIM_COMPILE` | compile the testbench without running it | seconds |
| `SIM_WAVE` | run the testbench and write `<tb>.vcd` | seconds |
| `WAVE` | the same, then open it in Surfer on the Mac | seconds |
| `RTL` | draw a schematic, writing `<top>_rtl.svg` | seconds |
| `SCHEMATIC` | the same, then open it in Preview on the Mac | seconds |
| `CLEAN` | delete build output | |
| `WHICH` | print the tools, board and project in use | |

`list` prints the target names alone, for scripting. Anything else is
rejected before the config is even read, so a typo gives a useful error.

**Make variables.** Any argument shaped like `VAR=value` goes to make, the
way make itself takes them, and the one remaining argument is the directory.
Order does not matter.

```bash
cpen-verilog NEWPROJECT TOP=fulladder
cpen-verilog SIM ~/CPEN211/lab3 TB=testbench
cpen-verilog SCHEMATIC RTL_OPEN_CMD="open -a Safari"
```

`NEWPROJECT` will not run without `TOP=`. The full list is under
[Make variables](#make-variables).

**Warnings it gives you.** Running a target other than `NEWPROJECT`,
`CLEAN` or `WHICH` in a folder with no `.qpf` prints a note telling you to
run `NEWPROJECT` first. A directory outside `/Users` prints a warning,
because the VM cannot see it.

---

## cpen-gui

Runs Quartus and Questa's real interfaces inside the VM and shows them on
the Mac over VNC. Each gets its own screen.

```
cpen-gui [quartus | questa | both | stop [quartus|questa] | status]
```

| Argument | Effect |
|---|---|
| *(none)* or `quartus` | start Quartus on `:1` if needed, and connect |
| `questa` | start Questa on `:2` if needed, and connect |
| `both` | both, in two viewer windows |
| `stop` | shut both down |
| `stop quartus`, `stop questa` | shut one down |
| `status` | what is running, with window sizes |
| `--help`, `-h` | usage |

Both start in the directory you ran `cpen-gui` from, and Quartus opens the
`.qpf` it finds there, so running it inside a lab folder lands you in that
lab. Only `/Users` is shared with the VM; anywhere else falls back to the
VM's own home. `CPEN_GUI_DIR` and `CPEN_GUI_PROJECT` override both.

| | Display | Geometry | Scaling |
|---|---|---|---|
| Quartus | `:1`, port 5901 | 2560x1600 | `QT_SCALE_FACTOR=2` |
| Questa | `:2`, port 5902 | 1280x800 | none |

**Why two.** Quartus is Qt, so `QT_SCALE_FACTOR` enlarges its toolbar icons
along with its text; it can be drawn large and stays sharp. Questa is
Tcl/Tk: its fonts come from `~/.modelsim` but its icons are fixed-size
bitmaps that no setting scales, so the only way to enlarge them is to
enlarge every pixel, which means a small screen the viewer magnifies.
Questa therefore looks softer, and there is no way around it.

**Set your viewer to Scaled, not Full Size.** In Screen Sharing that is the
View menu.

**Security.** Each VNC server binds only to the VM's loopback, which
OrbStack forwards to the Mac's loopback, so nothing listens on any network
interface. The password is whatever you set with `orb -m altera vncpasswd`;
no tool here stores, reads or transmits it.

**Session scripts.** `cpen-gui` writes `~/.vnc/xstartup-quartus` and
`~/.vnc/xstartup-questa` in the VM on every run, because they carry the
directory you started from. Edits to those files are lost.

A screen that is already running keeps the directory it started with;
`cpen-gui stop` and start again to move it.

---

## cpen-init

The bring-up `F1` performs, usable without opening the console. Runs on the
Mac because `orb usb` is a host command: a process inside the VM cannot
re-attach its own passthrough.

```
cpen-init [--no-program] [--program] [--stop] [--status] [--no-gdb] [--no-terminal]
```

| Flag | Effect |
|---|---|
| *(none)* | full bring-up: attach USB, program the board, start the servers |
| `--no-program` | skip configuring the FPGA, for when the board kept power |
| `--program` | only stop whatever holds the cable, reprogram, restart the servers |
| `--stop` | stop the GDB server and terminal |
| `--status` | report what is running, change nothing |
| `--no-gdb` | do not start the GDB server |
| `--no-terminal` | do not start the stdout terminal |

Most people never call this directly. It is here for scripting, and for
releasing the board when the console is not open.

---

## cpen-uninstall

Undoes what `cpen-setup` changed. Surveys first, then waits for
confirmation.

```
cpen-uninstall [--all] [--dry-run] [--yes]
```

| Flag | Effect |
|---|---|
| *(none)* | remove the config, the state directory and the PATH line, after confirmation |
| `--all` | also delete the VM, and with it `/opt/altera` |
| `--dry-run` | print the survey and stop |
| `--yes`, `-y` | skip the confirmation prompt |

It prints everything it found, with sizes, before asking. Confirmation is
typing the word `remove`; anything else cancels. With no terminal on stdin
and no `--yes` it refuses outright rather than guessing.

**What it never removes:** Homebrew, the Xcode Command Line Tools, Rosetta,
OrbStack, Surfer, your lab files, and this repository. The first five are
general-purpose and may be wanted for something else; delete the repository
folder yourself.

**The Questa licence.** It warns before deleting `Questa_License.dat`.
Replacing it is free but means another web form, and it is locked to the
VM's NIC, so a new VM needs a new licence regardless.

**The profile edit** keeps a copy at `<profile>.bak-cpen-uninstall`.

---
## The configuration file

`~/.config/cpen-tools/config`, written by `cpen-setup`. Shell-style
`KEY='value'` lines. It is **parsed, never executed**, so a stray line
cannot run anything.

Everything below the marker is regenerated on every run:

```
## BEGIN AUTOGENERATED BLOCK ##
```

**Anything you put above that line wins over detection and survives.** That
is the supported way to correct a wrong guess.

| Key | Meaning |
|---|---|
| `MACHINE` | the OrbStack VM's name. `ORBSTACK_VM_NAME` is accepted as an alias. |
| `INSTALL` | the toolchain root, normally `/opt/altera` |
| `QUARTUS_BIN`, `NIOSV_BIN`, `RISCV_BIN` | the three tool directories |
| `GDBSRV` | path to the RISC-V GDB server |
| `BOARD` | `DE10-Lite` or `DE1-SoC` |
| `IDCODE` | the FPGA's JTAG ID code, e.g. `031050DD` |
| `JTAG_INDEX` | position in the JTAG chain. 1 on a DE10-Lite, 2 on a DE1-SoC. |
| `CABLE` | the programmer's name, e.g. `USB-Blaster [1-1]` |
| `SOF` | the prebuilt Nios V bitstream |
| `USB_ID`, `USB_VIDPID` | the OrbStack passthrough id, and `09fb:6001` |
| `GDB_PORT` | default 2454 |
| `TERM_INSTANCE` | which `nios2-terminal` instance to attach to |
| `TOOLCHAIN` | `proprietary` or `llvm` |
| `TOOLCHAIN_OK`, `LLVM_OK`, `QUESTA_OK` | detection results, 1 or 0 |
| `QUESTA_BIN` | Questa's binary directory |
| `SALT_LICENSE_SERVER` | path to the Questa licence file |
| `REPO`, `MAKEFILE`, `RUNDIR` | where this repo, its Makefile and the logs are |

**To correct detection**, put the key above the marker:

```
BOARD=DE1-SoC
INSTALL=$HOME/intelFPGA_lite/24.1std
```

---

## Environment variables

Read at run time; useful for a second install, or a one-off.

| Variable | Read by | Effect |
|---|---|---|
| `CPEN_TOOLS_CONFIG` | all | use a different config file. This is how a dev checkout keeps its own settings. `cpen-uninstall` then removes only that file and leaves the rest of the folder, including the licence, alone. |
| `XDG_CONFIG_HOME` | all | moves `~/.config/cpen-tools` |
| `XDG_STATE_HOME` | console, init | moves `~/.local/state/cpen-tools` |
| `CPEN_VM` | all | VM name, overriding the config. Detection takes it too, which is what lets a first run work on a machine with more than one OrbStack VM. |
| `SALT_LICENSE_SERVER` | gui, make | the Questa licence file |
| `CPEN_GUI_PROJECT` | gui | a `.qpf` for Quartus to open, instead of the one in the current directory |
| `CPEN_GUI_DIR` | gui | the folder both tools start in, instead of the current directory |
| `CPEN_QT_SCALE` | gui | Quartus's scale factor, default 2 |
| `CPEN_QUARTUS_DISPLAY`, `CPEN_QUESTA_DISPLAY` | gui | display numbers, default 1 and 2 |
| `CPEN_QUARTUS_GEOMETRY`, `CPEN_QUESTA_GEOMETRY` | gui | screen sizes |

Example, running a second checkout without disturbing the one your labs
depend on:

```bash
CPEN_TOOLS_CONFIG=~/.config/cpen-tools/dev.config cpen-nios
```

---

## Make variables

The build targets come from `share/*.mk`. Override any of these on the
command line, or set them in the config.

| Variable | Default | Notes |
|---|---|---|
| `BOARD` | `DE10-Lite` | also sets `FAMILY` and `DEVICE` |
| `INSTALL` | `/opt/altera` | |
| `GDB_PORT` | `2454` | |
| `JTAG_INDEX` | `1` | 2 on a DE1-SoC |
| `TOOLCHAIN` | `proprietary` | or `llvm`, experimental |
| `QPF` | first `*.qpf` found | the Quartus project |
| `PROJECT` | from `QPF` | |
| `TOP` | the project name | top-level module |
| `TB` | read from the testbench's `module` line | not the filename |
| `TB_FILE` | first `*_tb.sv` or `tb_*.sv` | |
| `RTL_SRCS` | every `.sv`/`.v` except testbenches | what `RTL` draws |
| `OPEN` | empty | when non-empty, the result is opened on the Mac. `WAVE` and `SCHEMATIC` are just `SIM_WAVE` and `RTL` with `OPEN=1`. |
| `RTL_OPEN_CMD` | `open -a Preview` | |
| `WAVE_OPEN_CMD` | `surfer` | Surfer is a command, not an app bundle |

`TB` is read from the `module` declaration rather than the filename,
because Questa wants the module name and the two are often different.

---

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | something failed, or the user cancelled |
| 2 | bad usage: an unknown flag or target |
| 3 | `cpen-setup` stopped at a step needing you (the download, the licence) |

Code 3 is the one worth scripting against: it means nothing is broken, the
install simply cannot continue unattended.

---

## Files and directories

### On the Mac

| Path | Written by | Contents |
|---|---|---|
| `~/.config/cpen-tools/config` | setup | detected settings |
| `~/.config/cpen-tools/Questa_License.dat` | you | the Questa licence |
| `~/.local/state/cpen-tools/` | console, init | logs and run state |
| your shell profile | setup | one tagged `export PATH=` line |

The profile is `~/.zshrc` for zsh, `~/.bash_profile` or `~/.profile` for
bash. Other shells are not edited; the line is printed for you to add. The
line carries a comment tag so re-running recognises it instead of adding a
second one.

### In the VM

| Path | Contents |
|---|---|
| `/opt/altera/` | the toolchain, about 20GB |
| `~/quartus-install/` | the installer and its unpacked contents |
| `~/qinst-dl/` | ~6GB of downloads, deletable after installing |
| `~/.bashrc` | a toolchain PATH block appended by setup |
| `/etc/udev/rules.d/51-altera-usb-blaster.rules` | permission to use the programmer |
| `~/.vnc/xstartup-quartus`, `~/.vnc/xstartup-questa` | session scripts, regenerated by `cpen-gui` |
| `~/.vnc/passwd` | the VNC password you set |
| `~/.modelsim` | Questa's own preferences, written by Questa |

---

## Things that are easy to get wrong

**More than one OrbStack machine.** Detection will not guess which one
holds the toolchain. Either set `MACHINE` in the config or run
`CPEN_VM=<name> cpen-setup --config-only` once; after that the config
carries it.

**A new VM needs a new Questa licence.** OrbStack gives every machine it
creates a fresh random MAC, and the licence is tied to that NIC, so
deleting and recreating a VM invalidates it even under the same name.
`cpen-setup` prints the new NIC ID when it notices, and detection says so
explicitly: `questa licence is for NIC ... but this VM is ...`.


**`~` means different folders on each side.** In the VM it is `/home/you`,
which starts empty. Your Mac home is at `/Users/you` on both sides. Reaching
a Mac file from inside the VM means spelling out `/Users/you/...`.

**`.bashrc` is only read by interactive shells.** A script gets a shell that
skips it, so `quartus_sh` can be on your PATH when you type it and missing
inside a script. None of the tools here depend on it; they set PATH
themselves.

**Only one program can hold the JTAG cable.** `Error (209042)` means
something else has it: a previous run, a GDB server, or Quartus's Programmer
window. `F6` releases it, `F1` rebuilds everything.

**Questa optimises signals away without `-voptargs=+acc`.** The waveform
comes back nearly empty and there is no error. `SIM` and `WAVE` pass it for
you; typing `vsim` yourself does not.

**Questa caches an optimised design.** After editing your source it will
happily re-run the old one. `rm -rf work` first. The make targets do this
for you.

**The Rosetta patch is undone by reinstalling Quartus.** If `Illegal
Instruction` comes back months from now, that is why. See SETUP.md 4.3.
