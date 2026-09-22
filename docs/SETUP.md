# CPEN 211 on Apple Silicon Macs
The CPEN 211 instruction team only officially supports the course on an x86_64 processor running Windows 11. This is an unofficial, student-written guide for making the course accessible to Apple Silicon Mac while avoiding Windows emulation software. Only follow this guide if you will be comfortable with debugging your own setup when something goes wrong (or asking chat for help). A TA or professor cannot provide help with this setup.

Notably, this guide *does not* use Parallels or attempt to exactly recreate the teaching team's setup; it aims to reproduce the function of Quartus and the required features for this course.

**What you'll need:** bravery, some free time, and about 35GB of free space.

## ⚠️ MULTIPLE INSTALLATION PATHS ⚠️

To fully cover the features of Quartus/Questa for this course, we need at least some GUI features outside of just the terminal. These can be accessed in 2 ways:
 - **[gui]**: Steps tagged with this create a display server for the Linux VM so that you can control Quartus directly, and you should be able to follow lab handouts directly.
 - **[native]**: Steps tagged with this install tools directly to your Mac to emulate the features in Quartus. You'll need to interpret the meaning behind lab handouts and translate them to terminal commands.

You MUST follow at least one path by completing all of its steps.
I recommend doing both so that if one option were to fail during an exam, you can have a backup solution.

## Contents

- [Glossary & Important Terms](#glossary--important-terms)
- [1. Mac Prerequisite Tools](#1-mac-prerequisite-tools)
- [2. Correct Installer File](#2-correct-installer-file)
- [3. A Linux VM with OrbStack](#3-a-linux-vm-with-orbstack)
- [4. The Toolchain](#4-the-toolchain)
- [5. PATH and your Board](#5-path-and-your-board)
- [6. Console Tools and Licensing](#6-console-tools-and-licensing)
- [7. Running the real Quartus GUI](#7-running-the-real-quartus-gui-gui)
- [8. Using the tools](#8-using-the-tools)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)

---

## Glossary & Important Terms
You do not need to understand these deeply to follow the guide, but knowing what is what makes error messages easier to follow.

| Name | What it is |
|---|---|
| **FPGA** | The chip on your board. After writing and compiling SystemVerilog to the chip, it physically rewires itself into whatever circuit you describe. |
| **DE10-Lite** | The board itself: an FPGA chip plus switches, LEDs, displays and a USB socket. |
| **Verilog / SystemVerilog** | The language you describe that circuit in. |
| **Quartus** | Altera's toolkit. Turns your Verilog into a **bitstream**, the file that configures the chip. |
| **Bitstream** (`.sof`) | The compiled output. Loading it onto the board is called **programming** the board. |
| **JTAG** | The wiring the programmer talks over, through the board's USB socket. |
| **Questa** | A simulator. Runs your design as software so you can test it without a board. |
| **Nios V** | A small processor you can build *into* the FPGA, then run ordinary programs on. |
| **RISC-V** | The instruction set Nios V uses, so its compiler is a RISC-V compiler. |
| **OrbStack** | An app for hosting linux virtual machines natively on macOS. |
| **Virtual Machine (VM)** | An instance of an operating system running on top of your main system. For this guide, we'll stick to a mostly terminal only Ubuntu install. |

### A note on typing commands

For multi-line commands, you should copy and paste the entire block into your terminal and enter it as a whole unit.

Some commands only work inside the VM terminal, and some only work on the native Mac terminal. I'll try to distinguish which are which by prefacing commands with [VM] or [Mac].

In a similar vein, some files are only accessible from inside the VM, while others are not. With OrbStack, every file on your Mac is available, at its usual directory. Typing `cd ~` in the VM brings you to your home directory *in the VM*, but typing `cd ~` in the mac brings you to `/Users/<your-username>/`.

### Credit

The hard parts here, especially the Rosetta fix in Part 4, were worked out
by lamadaemon in
[this gist](https://gist.github.com/Lama3L9R/15d8c6568bc4a97b2fa39fc8125375f8).
This guide fills in what the gist assumes you already know, and adds a few quality of life steps.

---

## 1. Mac Prerequisite Tools
### 1.1 Xcode Command Line Tools

Developer tools Apple ships but does not install by default. You need them
for `git` and `python3`.

**[mac]**
```bash
xcode-select --install
```

<details>
<summary><b>Check this step</b></summary>

**[mac]** `xcode-select -p` should output:

```
/Library/Developer/CommandLineTools
```

If it says the tools are not installed, the installer window is still open or was dismissed.

</details>

### 1.2 Rosetta
The command finishes without output, even on success.

**[mac]**
```bash
softwareupdate --install-rosetta --agree-to-license
```

<details>
<summary><b>Check this step</b></summary>

**[mac]** `/usr/bin/pgrep -q oahd && echo "rosetta ok"` should output:

```
rosetta ok
```

There is nothing else to look at; Rosetta is invisible when it works. Skip this on an Intel Mac.

</details>

### 1.3 OrbStack

Homebrew is highly recommended for installing this and other tools in this guide, but you can find binaries packaged individually for each requirement.

If you do not have Homebrew already:

**[mac]**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Then, download OrbStack:

**[mac]**
```bash
brew install --cask orbstack
```

Launch the OrbStack app manually before trying to use commands.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `orb version` should output:

```
Version: 2.2.3 (2020300)
Commit: c83556b0ef8f1ba9a33abbb194622b6b7a1c0307 (v2.2.3)
```

Your version will differ. If `orb` is not found, open the OrbStack app once; it installs the command on first launch.

</details>

### 1.4 Surfer [native]

On Windows you would read simulation waveforms in Questa's own window and
view schematics in Quartus's RTL Viewer. Neither of those exist natively, so the mac alternatives are:

| Instead of | You use |
|---|---|
| Questa's waveform window | **Surfer**, opening a `.vcd` file |
| Quartus's RTL Viewer | **Preview**, opening a `.svg` file |

To download Surfer, we use Homebrew:

**[mac]**
```bash
brew install surfer
```

<details>
<summary><b>Check this step</b></summary>

**[mac]** `surfer --version` should output:

```
surfer 0.7.0 (git: v0.7.0)
```

Surfer installs as a command, not an app in your Applications folder, so do not go looking for an icon.

</details>

---

## 2. Correct Installer File

As of 2026-2027, CPEN211 is using the `24.1` version of Quartus. After creating an account and agreeing to terms, you can download the file from the
[Download Center](https://www.altera.com/downloads), choose
Quartus Prime Lite, then then version `24.1` and operating system `linux`. Or go straight to
the [24.1 Linux page][dl].

[dl]: https://www.altera.com/downloads/fpga-development-tools/quartus-prime-lite-edition-design-software-version-24-1-linux

We'll be using the **Installer (recommended)** version for downloading and unpacking.

    Quartus Prime Lite Edition Installer (SFX)
    (qinst-lite-linux-24.1std-1077.run)

Click Download, accept the agreement, and leave the file in your Downloads folder.

### Double check you got the right file:
This command returns `OK` if the file matches what it should be, otherwise it returns a `FAILED` message. In that case, ensure you picked the correct installer file.

**[mac]**
```bash
echo "03b7abe3990ce26a70bd953253e7c8a6923126cc  $HOME/Downloads/qinst-lite-linux-24.1std-1077.run" | shasum -a 1 -c
```
Note: `03b7abe3990ce26a70bd953253e7c8a6923126cc` is the SHA1 hash for the correct file, as of Sep-2026.

---
## 3. A Linux VM with OrbStack

### 3.1.1 Create the machine

**[mac]**
```bash
orb create -a amd64 ubuntu altera
```

- `-a amd64` builds an **Intel** machine. OrbStack would otherwise give you
  an ARM, which is incompatible.
- `ubuntu` is the flavour of Linux. Any recent Ubuntu works.
- `altera` is the instance's name, and the one part you may change, but I would recommend leaving it as is.

Creation takes a minute, mostly downloading the base image.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `orb list` should output:

```
altera     running  ubuntu  resolute  amd64  31.1 GB  192.168.139.245
```

The size and address will differ. If the architecture column says `arm64` you left out `-a amd64`: delete it with `orb delete altera` and create it again, because nothing you install later will run.

</details>

### 3.1.2 Reiterating that note...
Thirty seconds here prevents most later confusion.

**Files are shared.** Your Mac home folder appears inside Linux at the same
path. A file at `/Users/you/CPEN211/verilog/xyz.sv` on the Mac is at that exact
path in Linux. Edit in your usual Mac editor, build in Linux, both see the
same bytes. Nothing to copy or sync.

**But `~` means different folders on each side.** `~` is shorthand for "my
home folder", and Linux has its own, at `/home/you`, which starts empty.
Your Mac home stays at `/Users/you`.

**[VM]**
```bash
ls ~/Downloads                  # empty: this is the Linux home
ls /Users/$(whoami)/Downloads   # your real Mac downloads
```

When you want to read a Mac file from inside Linux, use `/Users/<your Mac
username>/...` for that reason. The commands here write `$(whoami)` in that
spot, which fills your username in for you, so they can be pasted as they
are. Writing the name out by hand works just as well.

To get a shell inside the machine:

**[mac]**
```bash
orb -m altera
```
Commands entered after this point will be interpreted as Linux commands and run inside Ubuntu.
Typing `exit` returns to the Mac.

**Everything from here to the end of Part 5 runs inside the VM.** Run
**[mac]** `orb -m altera` once and stay there.

<details>
<summary><b>Check this step</b></summary>

**[VM]** `ls -d /Users/$(whoami)` should output:

```
/Users/yourname
```

This proves the VM can see your Mac's files. OrbStack gives the VM the same username as your Mac, which is why nothing needs filling in.

</details>

### 3.2 Install the packages Quartus needs

Refresh our package list:

**[VM]**
```bash
sudo apt-get update
```

After that, we can download the required packages for Quartus.

**[VM]**
```bash
sudo apt-get install -y build-essential git usbutils libarchive-tools libfontconfig1 libxft2 libxext6 nodejs unzip
```

<details>
<summary><b>Check this step</b></summary>

**[VM]** `make --version | head -1 && bsdtar --version | cut -d' ' -f1-3 && node --version` should output:

```
GNU Make 4.4.1
bsdtar 3.8.5 -
v22.22.1
```

Versions will differ. `bsdtar` matters most: it comes from `libarchive-tools` and unpacks the installer in 4.1.

</details>

---

## 4. The Toolchain
Everything here runs **inside the VM**.

### 4.1 Unpack the installer
This set of commands makes a directory named `quartus-install` at the home directory inside the VM, moves there and copies the downloaded installer into the VM from your Mac's downloads.

**[VM]**
```bash
mkdir -p ~/quartus-install
cd ~/quartus-install
cp /Users/$(whoami)/Downloads/qinst-lite-linux-24.1std-1077.run .
```

Now unpack:

**[VM]**
```bash
F=qinst-lite-linux-24.1std-1077.run
skip=$(head -c 4000 "$F" | strings | sed -n 's/^skip="\([0-9]*\)"/\1/p' | head -1)
echo "payload starts at line $skip"
tail -n +$((skip + 1)) "$F" | gzip -dc | bsdtar -xf -
```
We cannot run the installer outright because it fails to unpack itself, so we must parse the install script to find the actual payload and unzip that ourselves.

<details>
<summary><b>Check this step</b></summary>

**[VM]** `ls` should output:

```
licenses
qcore
qinst-lite-linux-24.1std-1077.run
qinst.sh
quartus
```

If you only see the `.run` file the unpack produced nothing; check that the earlier `echo` printed `payload starts at line 767`.

</details>

### 4.2 Run the installer

**[VM]**
```bash
sudo mkdir -p /opt/altera
```

`/opt` is the conventional Linux home for large self-contained software. You
may put it elsewhere, but remember where.

Then, run the installer with:

**[VM]**
```bash
cd ~/quartus-install
sudo ./qinst.sh --auto-install --download-dir ~/qinst-dl --install-dir /opt/altera --accept-eula --cli
```

| Flag | Meaning |
|---|---|
| `--auto-install` | install after downloading, not just download |
| `--download-dir` | where the 5.4 GB of downloads land |
| `--install-dir` | where the software ends up |
| `--accept-eula` | accepts the licence agreement, which you must do to proceed |
| `--cli` | no graphical installer, since the VM has no screen |

This should take around 10 minutes to complete.

<details>
<summary><b>Check this step</b></summary>

**[VM]** `ls /opt/altera` should output:

```
devdata  ip  licenses  logs  nios2eds  niosv  quartus  questa_fse  uninstall
```

The installer's own last line should read `Installation completed successfully`. A block of hex addresses ending in `End-trace` means it crashed; see [Troubleshooting](#troubleshooting-common-issues).

</details>

### 4.3 Patching Quartus

Quartus does not run yet. Try it, so you recognise the failure:

**[VM]**
```bash
/opt/altera/quartus/bin/quartus_sh --version
```
```
    *** Fatal Error: Illegal Instruction
    Module: quartus_sh
    Stack Trace:
        0x1af7f: hasHighPrecisionDouble + 0x42 (ccl_sqlite3)
        ...
```

The fix is a short script by [lamadaemon](https://gist.github.com/Lama3L9R/15d8c6568bc4a97b2fa39fc8125375f8)
which rewrites that one function to a Rosetta compatible instruction.

**This step downloads a script from the internet and runs it as root, so
here is exactly what it does and how to check it before you run it.** The
script opens `libccl_sqlite3.so`, finds the function called
`hasHighPrecisionDouble`, and overwrites its first six bytes with `return
1`. It copies the original to `libccl_sqlite3.so.backup` first. It does
nothing else: no network, no other files. You can read it yourself, it is
about a hundred lines:
[patch-libccl_sqlite.js](https://gist.github.com/Lama3L9R/15d8c6568bc4a97b2fa39fc8125375f8).

The URL below is pinned to one specific revision and the `sha256sum -c`
line checks the file before anything runs it. If the file is not byte for
byte the one this guide was written against, `sha256sum` prints `FAILED`,
the `&&` chain stops, and nothing is executed. Do not skip that line, and
do not continue if it fails: tell the course forum instead.

**[VM]** paste all four lines together:
```bash
cd ~
curl -fsSL https://gist.githubusercontent.com/Lama3L9R/15d8c6568bc4a97b2fa39fc8125375f8/raw/09579d6b8623821d3d6b5078750d45bc74380544/patch-libccl_sqlite.js -o patch-libccl_sqlite.js
echo "36d37a72c80069283d1f8766c2aea67511dacb3ce7cc26595f8ee01428fc0bed  patch-libccl_sqlite.js" | sha256sum -c \
  && sudo node patch-libccl_sqlite.js $(find /opt/altera -name "libccl_sqlite3.so")
```

You should see `patch-libccl_sqlite.js: OK` from the checksum, then
`Patched! Backup saved to: ...libccl_sqlite3.so.backup`.

If you would rather not do this by hand, `cpen-setup` (Part 6) performs the
same pinned and checksummed step for you.

<details>
<summary><b>Check this step</b></summary>

**[VM]** `/opt/altera/quartus/bin/quartus_sh --version` should output:

```
Quartus Prime Shell
Version 24.1std.0 Build 1077 03/04/2025 SC Lite Edition
```

If it still says `Illegal Instruction`, the `find` matched nothing. Run `find /opt/altera -name "libccl_sqlite3.so"` on its own; it should print exactly one path.

</details>

### 4.4 Install the RISC-V compiler

What we've installed has no compiler for Assembly for Nios V processor. The compiler is in a component called `riscfree`, which is not in the
installer's default set, so it needs a second pass:

**[VM]**
```bash
cd ~/quartus-install
sudo ./qinst.sh --components riscfree --download-dir ~/qinst-dl --install-dir /opt/altera --accept-eula --cli
```

<details>
<summary><b>Check this step</b></summary>

**[VM]** `ls /opt/altera/riscfree/toolchain/riscv32-unknown-elf/bin/ | grep -E "gcc$|gdb$"` should output:

```
riscv32-unknown-elf-gcc
riscv32-unknown-elf-gdb
```

Without these the Nios V labs cannot compile at all.

</details>

### 4.5 Reclaim download space

The installer left about 6GB of downloaded packages behind. They are no
longer needed, and deleting them is optional: skip this section entirely if
you have the space and would rather not.

**If you are going to run `cpen-setup` in Part 6, skip this.** It reclaims
the same space for you, once it has confirmed everything is installed.

To do it by hand, look before you delete. This prints what is there without
removing anything:

**[VM]**
```bash
du -sh ~/qinst-dl
```

That should print one line ending in `/home/<you>/qinst-dl`, around 6GB. If
it says `No such file or directory`, there is nothing to reclaim and you are
done here.

Only once you have seen that line:

**[VM]**
```bash
sudo rm -rf ~/qinst-dl
```

`rm -rf` deletes a folder and everything in it, with no undo and no
confirmation, so it is worth being careful with. The two things that make it
safe here are that the path is typed exactly as above and that you have just
seen `du` agree the folder exists. If you mistype the path, the worst case is
`rm` reporting that nothing matched.

Keep `~/quartus-install`: adding a component later means running `qinst.sh`
from there again. If you do delete it by accident, nothing is lost
permanently, you would unpack the `.run` file again from 4.1.

<details>
<summary><b>Check this step</b></summary>

**[VM]** `du -sh /opt/altera` should output:

```
20G	/opt/altera
```

And `df -h /` should show roughly 6GB more free than before.

</details>

---

## 5. PATH and your Board

### 5.1 Adding these tools to PATH

`PATH` is the list of folders your terminal searches when you type a command
name. Quartus is in none of them yet, so we can't directly invoke it yet.

Running this command append to the end of `~/.bashrc`, the file Ubuntu reads
whenever you open a shell:

**[VM]**
```bash
cat >> ~/.bashrc <<'LINE'

# Altera toolchain
export QUARTUS_ROOTDIR=/opt/altera/quartus
export PATH="$QUARTUS_ROOTDIR/bin:/opt/altera/niosv/bin:/opt/altera/riscfree/toolchain/riscv32-unknown-elf/bin:$PATH"
LINE
```

Changes to `.bashrc` only apply to new shells, so start one:

**[VM]**
```bash
exit
orb -m altera
```

<details>
<summary><b>Check this step</b></summary>

**[VM]** `which quartus_sh niosv-app riscv32-unknown-elf-gcc` should output:

```
/opt/altera/quartus/bin/quartus_sh
/opt/altera/niosv/bin/niosv-app
/opt/altera/riscfree/toolchain/riscv32-unknown-elf/bin/riscv32-unknown-elf-gcc
```

If you get `command not found` you are still in the old shell: `exit`, then `orb -m altera` again.

</details>

### 5.2 Allow access to the board

**[VM]**
```bash
sudo tee /etc/udev/rules.d/51-altera-usb-blaster.rules > /dev/null <<'RULE'
# Altera USB-Blaster (DE10-Lite, DE1-SoC on-board)
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6002", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6003", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666"
RULE
```

Paste that whole block at once, **NOT** line by line.

`09fb` is Altera's manufacturer number, and the five product numbers cover
the USB-Blaster programmer variants. The DE10-Lite is `6001`; but we'll apply changes for the other DE10 family boards.

Rules only take effect after a reload:

**[VM]**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

<details>
<summary><b>Check this step</b></summary>

**[VM]** `udevadm verify /etc/udev/rules.d/51-altera-usb-blaster.rules` should output:

```
1 udev rules files have been checked.
  Success: 1
  Fail:    0
```

The folder matters as much as the file. A rule anywhere other than `/etc/udev/rules.d/` is ignored silently, with no error and no hint.

</details>

### 5.3 Hand the board off to the VM

Plug the board into your Mac and ensure it has power (it should be flashing all its LEDs and 7-seg displays).

USB devices belong to the Mac, and only the Mac can pass one to the VM, so
these two run **on your Mac**:

**[mac]**
```bash
orb usb list
```

Find the line with `09fb:6001`. The
first column is its ID:

```
    ID         VENDOR:PRODUCT  NAME
    12345678   09fb:6001       USB-Blaster
```

Then attach it, putting your own ID in place of `12345678`:

**[mac]**
```bash
orb usb attach 12345678
```

<details>
<summary><b>Check this step</b></summary>

**[VM]** `jtagconfig` should output:

```
1) USB-Blaster [1-1]
  031050DD   10M50DA(.|ES)/10M50DC
```

`031050DD` is the MAX 10 chip on a DE10-Lite. If `lsusb | grep 09fb` finds the device but `jtagconfig` says `No JTAG hardware available`, your udev rule from 5.2 is in the wrong place or has not been reloaded.

</details>

---
## 6. Console Tools and Licensing

### 6.1 Install the tools

This is a set of tools I created to help with NIOS-V and SystemVerilog connections with this setup. Although technically optional, I highly recommend it. Otherwise, you must port your own makefile.

| Command | What it is for |
|---|---|
| `cpen-setup` | installs and re-checks everything in this guide |
| `cpen-nios` | the TUI console for the Nios V flow |
| `cpen-verilog` | the SystemVerilog build targets, from your own terminal |
| `cpen-gui` | Quartus and Questa's real interfaces, over VNC |

**If you would rather not do Parts 3 to 5 by hand**, `./bin/cpen-setup`
does all of it: the VM, packages, the installer, the Rosetta fix, the RISC-V
compiler, PATH, udev and the GUI desktop. It stops with instructions at the
two steps that cannot be scripted, which are downloading the installer
(Part 2) and the licence (6.2), and it is safe to re-run: every step checks
whether it is already done. `--check` reports without changing anything.

**[mac]**
```bash
git clone https://github.com/Horse-5-333/cpen-tools.git
cd cpen-tools
./bin/cpen-setup
```

`./bin/` is needed only this first time; it adds itself to your PATH, so
after this `cpen-setup` works from anywhere.

This setup script attempts to work regardless of possible path name differences, but it mostly assumes the structure of this guide has been followed.

You should see roughly:
```
    Host
      ok    macOS 26.6.2
      ok    python3 3.13
      ok    curses available
      ok    orb Version: 2.2.3

    Toolchain
      ok    machine        altera
      ok    install        /opt/altera
      ok    quartus bin    /opt/altera/quartus/bin
      ok    RISC-V toolchain complete
      warn  Questa found but not licensed - SIM and WAVE will not work.

    Board
      ok    DE10-Lite  (IDCODE 031050DD, chain index 1)
```

This runs as a general check for all the work done so far. The Questa warning is expected here and 6.2 fixes it.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `cpen-setup --check` should output:

```
Toolchain
  ok    machine        altera
  ok    install        /opt/altera
  ok    quartus bin    /opt/altera/quartus/bin
  ok    RISC-V toolchain complete
```

It reports on every step of this guide without changing anything. Everything except the licence should say `ok`. This is also the first thing to run whenever something breaks later in the term. `cpen-setup --report` prints the same thing with your versions attached, for when you need to show someone.

</details>

### 6.2 Questa Licensing

Questa is the simulator used by CPEN211 for generating waveforms and testing SystemVerilog before it reaches hardware.

#### 6.2.1 Find your VM's NIC ID

A NIC ID is the hardware address of a network adapter, used here just as a
unique machine identifier.

**[VM]**
```bash
cat /sys/class/net/eth0/address | tr -d ':' | tr 'a-f' 'A-F'
```

It should print 12 characters in the shape `A1B2C3D4E5F6`. Note YOURS down for the next step.

<details>
<summary><b>Check this step</b></summary>

**[VM]** the command above should output twelve characters:

```
A1B2C3D4E5F6
```

Yours will differ; use your own. If it prints nothing, the interface may not be `eth0`: list them with `ls /sys/class/net/`.

</details>

#### 6.2.2 Request the licence

Go to the Altera Self-Service Licensing Center:
**<https://licensing.altera.com/>**

You'll have to make another account here. Use the same info as you did for your previous account.

1. Find **Sign up for Evaluation or No-Cost Licenses**.
2. Choose **Questa-Intel FPGA Starter Edition**, product `SW-QUESTA`.
3. It asks you to create a "computer":

   | Field | Value |
   |---|---|
   | Computer Name | anything, for example `orbstack-altera` |
   | Computer Type | **FIXED** |
   | License Type | **NIC ID** |
   | Primary NIC ID | your twelve characters from 6.2.1 |

4. Submit. The `.dat` file gets sent via email.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `grep -c SW-QUESTA ~/Downloads/Questa_License.dat` should output:

```
1
```

A licence issued against the wrong NIC installs fine and then refuses to simulate, so check the ID in the file matches the one you submitted.

</details>

#### 6.2.3 Installing It

Download the license file to your Downloads and name it `Questa_License.dat`. Then, create a hidden directory and move the file to where the setup tool expects:

**[mac]**
```bash
mkdir -p ~/.config/cpen-tools
mv ~/Downloads/Questa_License.dat ~/.config/cpen-tools/
```

Then re-run detection so it picks the licence up:

**[mac]**
```bash
cpen-setup --config-only
```

Note: It expires after 12 months. You'll have to renew the license for free from the same portal.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `cpen-setup --config-only` should output:

```
ok    Questa         licensed
```

If it says the licence is for a different NIC, it was generated against the wrong machine, most likely your Mac instead of the VM. Making another is free.

</details>

### 6.3 Final Checks

#### 6.3.1 NIOS-V
With the board plugged in and switched on, run `cpen-nios`
and press `F1`. That starts the VM if needed, re-attaches the USB cable,
clears anything else holding the board, and programs it with a prebuilt Nios
V system. The status bar should turn green across the board.

Then `F7` to open a project folder, `F3` to compile, `F4` to run. Output appears
in the bottom left pane.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `cpen-nios`, then `F1`. The status bar should read:

```
VM ok   USB ok   JTAG ok   TERM ok
```

All four green. If JTAG stays red, press `F1` again; it releases anything else holding the board.

</details>

#### 6.3.2 SystemVerilog

Make an empty folder for a throwaway test project and work there.

`NEWPROJECT` is what turns a plain folder into a Quartus project, so it runs
**once, in a folder that does not have one yet**. After that the folder has
`.qpf` and `.qsf` files and you never run it again.

`TOP=` names your top-level module, and `NEWPROJECT` will not run without
it. Every command here is a Mac one, run from the folder you made:

**[mac]**
```bash
mkdir -p ~/CPEN211/scratch && cd ~/CPEN211/scratch
cpen-verilog NEWPROJECT TOP=blink
```

That writes `blink.qpf`, `blink.qsf` and a `blink.sv` stub for you to fill
in. The `.qsf` carries the device and a commented example of the pin format;
the real pins come from Appendix B of your lab. Fill in the stub, then:

**[mac]**
```bash
cpen-verilog SYNTH
cpen-verilog PROGRAM_PROJECT
```

Those compile your Verilog and load it onto the board. Synthesis takes about
30 seconds, programming about 3. If your design lights an LED, the LED
lights.

To simulate instead, `cpen-verilog WAVE` builds and runs the testbench and opens
the result in Surfer on your Mac. That is the step needing the licence from
6.2.

[Part 8](#8-using-the-tools) covers all of this properly.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `cpen-verilog SYNTH` should end with:

```
Quartus Prime Full Compilation was successful
```

About 30 seconds. `cpen-verilog PROGRAM_PROJECT` then takes about 3, after which the board behaves as your design says it should.

</details>

---

## 7. Running the real Quartus GUI [gui]

The `[native]` path replaces Quartus's windows with terminal commands and
Mac viewers. This path runs Quartus's own interface instead, so lab handouts
can be followed as written.

Everything Quartus ships is already installed and works. The only thing
missing is a screen for it to draw on, since the VM has none.

This part gives it one: a small virtual screen inside the VM, shown on your
Mac over VNC. It costs about 100 MB in the VM and needs nothing extra on the
Mac, since macOS already has a VNC viewer built in.

### 7.1 Install the desktop pieces [gui]

**[VM]**
```bash
sudo apt-get install -y tigervnc-standalone-server openbox wmctrl \
  x11-xserver-utils fonts-dejavu fonts-liberation2 fonts-noto-core
```

`tigervnc-standalone-server` is the virtual screen, `openbox` is a minimal
window manager so dialogs and menus behave, `wmctrl` lets the launcher size
windows, and the font packages matter more than they look: a stock VM has
about 24 font files and Quartus falls back to something barely legible.

<details>
<summary><b>Check this step</b></summary>

**[VM]** `command -v Xvnc openbox wmctrl` should output:

```
/usr/bin/Xvnc
/usr/bin/openbox
/usr/bin/wmctrl
```

`fc-list | wc -l` should also print a number in the hundreds. Around 24 means the font packages did not install and Quartus will be hard to read.

</details>

### 7.2 Set a password [gui]

VNC needs one. Run this yourself and pick anything you will remember; it is
never stored by the tooling.

**[VM]**
```bash
vncpasswd
```

Answer `n` to the view-only password question.

The screen is only reachable from your own Mac, never from the network, so
this password is there to satisfy the viewer rather than to protect
anything.

<details>
<summary><b>Check this step</b></summary>

**[VM]** `ls ~/.vnc/passwd` should output:

```
/home/yourname/.vnc/passwd
```

Nothing reads it but the VNC server, and no tool in this repo stores or transmits it.

</details>

### 7.3 Launch it [gui]

**[mac]**
```bash
cpen-gui both
```

That starts two screens in the VM, one per application, and opens a viewer
window on each. `cpen-gui` on its own starts only Quartus, `cpen-gui questa`
only Questa, and there is `cpen-gui stop` and `cpen-gui status`.

Both open in the folder you ran the command from, and if that folder holds a
Quartus project, Quartus opens it. So `cd` into your lab folder first. A
screen that is already running keeps the folder it started in, so to move it
you need `cpen-gui stop` and then start it again.

They get separate screens because the two disagree about scaling, and there
is no single size that suits both:

| | Screen | Size | How it is scaled |
|---|---|---|---|
| Quartus | `:1` | 2560x1600 | drawn at 2x, so one drawn pixel lands on one screen pixel |
| Questa | `:2` | 1280x800 | drawn at normal size, and the viewer magnifies it |

Quartus is a Qt program, so `QT_SCALE_FACTOR` enlarges its toolbar icons
along with its text, and it can be drawn large and sharp. Questa is Tcl/Tk:
its fonts come from `~/.modelsim`, but its toolbar icons are fixed-size
bitmaps that nothing scales. Enlarging only its text leaves icons you cannot
read. The only way to enlarge those icons is to enlarge every pixel, which
means a small screen that the viewer blows up, and that is why Questa looks
softer than Quartus. `cpen-gui` sets all of this up; there is nothing to
configure.

**Set your viewer to Scaled, not Full Size.** In Screen Sharing that is the
View menu. Full Size on the Quartus screen gives you text you cannot read.

<details>
<summary><b>Check this step</b></summary>

**[mac]** `cpen-gui status` should output:

```
quartus: running on :1  (vnc://127.0.0.1:5901)
    0x0040004e  0 0    42   2560 1579 altera Quartus Prime Lite Edition
questa: running on :2  (vnc://127.0.0.1:5902)
    windows open (unnamed): 229
```

Questa's windows show as unnamed because it maps its main window before
giving it a title, which is normal and not a fault.

</details>

---

## 8. Using the tools

Setup is done. This is the part you will come back to.

### 8.1 The two flows

CPEN 211 has two, and they use different tools:

| | What you write | What runs it |
|---|---|---|
| **SystemVerilog labs** | `.sv` describing a circuit | the FPGA itself, after synthesis |
| **Nios V labs** | `.s` assembly | a processor built into the FPGA |

The Nios V flow needs the board programmed with a prebuilt processor first,
which is what `F1` does. The SystemVerilog flow programs the board with
*your* design instead.

### 8.2 SystemVerilog, the `[native]` way

Work in one folder per lab. Two ways to run the same targets:

- **From your Mac terminal:** `cpen-verilog <TARGET>`, in the folder you are
  working in, or `cpen-verilog <TARGET> <folder>`.
- **Inside the console's shell pane:** `labmake <TARGET>`, which is the same
  thing with the Makefile already wired up. `cpen-verilog` is a Mac command
  and is not on the VM's PATH, so it does not work in that pane.

Both take make variables the same way: `TOP=`, `TB=`, `BOARD=`, `OPEN=1`.

The table below uses `cpen-verilog`; swap in `labmake` if you are in the
console.

**Once per new project**, in an otherwise empty folder. `TOP=` is your
top-level module name, and the command will not run without it:

```bash
cpen-verilog NEWPROJECT TOP=fulladder
```

That writes `fulladder.qpf`, `fulladder.qsf` and a `fulladder.sv` stub. The
`.qsf` carries the device for your board and a commented example of the pin
format; fill the real pins in from Appendix B of your lab.

Run it once per project. If the folder already has a `.qpf`, you do not need
it again: `F7` in the console opens a folder you already made, while
`NEWPROJECT` creates the project inside a new one.

Two things to get right: `TOP` must match the name after `module` in your
source, not the filename, and each source file needs its own line in the
`.qsf`.

**Then, the loop you actually live in:**

| Command | What it does | Takes |
|---|---|---|
| `cpen-verilog SIM` | compiles your design and testbench, runs the simulation | seconds |
| `cpen-verilog WAVE` | same, then opens the waveform in Surfer on your Mac | seconds |
| `cpen-verilog SYNTH` | compiles to a bitstream | ~30s |
| `cpen-verilog PROGRAM_PROJECT` | loads your bitstream onto the board | ~3s |
| `cpen-verilog SCHEMATIC` | draws a schematic and opens it in Preview | seconds |
| `cpen-verilog CLEAN` | deletes build output when something is stuck | |

Simulate before you synthesise. Synthesis is fifty times slower and tells
you far less about why your logic is wrong.

### 8.3 SystemVerilog, the `[gui]` way

With `cpen-gui` running:

| Instead of | In Quartus |
|---|---|
| `NEWPROJECT` | File > New Project Wizard |
| `SYNTH` | Processing > Start Compilation |
| `PROGRAM_PROJECT` | Tools > Programmer, then Auto Detect and Start |
| `SCHEMATIC` | Tools > Netlist Viewers > RTL Viewer |

The RTL Viewer is the one real gain here. `cpen-verilog SCHEMATIC` uses a different
synthesiser and shows you its opinion of your code, which is useful but is
not what Quartus actually built. The GUI viewer shows the real thing.

**Waveforms in Questa** are driven from the Transcript pane at the bottom:

```
vlib work
vlog yourdesign.sv yourtestbench.sv
vsim -voptargs=+acc work.<testbench module name>
add wave -r /*
run -all
```

Three things that will cost you an evening if you do not know them:

**`-voptargs=+acc` is not optional.** Without it Questa optimises your
internal signals away and the waveform comes back nearly empty. There is no
error message.

**The last argument is the module name, not the filename.** If you get
`vopt-11: Could not find work.something`, open your testbench and use the
name after `module`. They are often different.

**Delete `work` if results look stale.** Questa caches an optimised design
and will re-run the old one after you edit your source. `rm -rf work`, then
start again from `vlib work`. (`cpen-verilog SIM` does this for you, which is why
the `[native]` path does not hit it.)

### 8.4 Nios V

Start the console from your lab folder; it opens there, and `F7` moves it
somewhere else.

**[mac]**
```bash
cd ~/CPEN211/lab5
cpen-nios
```

Board plugged in and powered, then:

| Key | Does |
|---|---|
| `F1` | full bring-up: starts the VM, re-attaches USB, clears the JTAG connection, programs the board with the prebuilt Nios V system |
| `F7` | open the folder you are working in |
| `F3` | compile your assembly |
| `F4` | run it on the board, output in the bottom-left pane |
| `F5` | open GDB in a new terminal window |
| `F6` | stop the servers and release the board |
| `F8` | clear the panes |
| `Ctrl-Q` | quit |

`F1` first, every session. The others assume it.

### 8.5 When the board stops responding

Only one program can hold the JTAG connection at a time. If you see
`Error (209042)`, or programming hangs, something else is holding it: a
previous run, a GDB server, or Quartus's own Programmer window.

`F6` releases it, `F1` rebuilds everything from scratch. If you are in the
`[gui]` path, close Quartus's Programmer window before going back to the
console, and vice versa.

### 8.6 Which path for which lab

Nothing stops you mixing them, and the files are the same either way.

- Editing and simulating: `[native]` is faster. `cpen-verilog WAVE` beats five
  Questa commands.
- Following a handout that says "click this": `[gui]`, obviously.
- Looking at a real schematic, or anything involving Platform Designer or
  SignalTap: `[gui]`, because the `[native]` path has no equivalent.
- On an exam with something broken: whichever one is still working, which
  is the argument for having set up both.
## Troubleshooting Common Issues

Work through these before assuming something is badly wrong.

**The installer stopped with hex addresses ending in `End-trace`.** You are
almost certainly on a newer Quartus than 24.1. That is the same Rosetta
problem as [4.3](#43-patching-quartus), hit from inside the installer.
Version 25.1 does this reliably; 24.1 does not. Install 24.1 instead, which
the course uses anyway. If you must stay on the newer one, apply the 4.3
patch to the partly installed copy and run the installer again; it resumes
cleanly.

**`command not found` for a Quartus tool.** Either you are on the Mac when
you meant to be in the VM, or you have not opened a new shell since editing
`.bashrc`, or you are in a script rather than a terminal. See
[5.1](#51-adding-these-tools-to-path).

**`Illegal Instruction` from any Quartus tool.** The
[4.3](#43-patching-quartus) patch is missing, or was undone by a reinstall.

**The board is in `lsusb` but `jtagconfig` finds nothing.** The udev rule is
in the wrong folder or has not been reloaded. See
[5.2](#52-allow-access-to-the-board).

**`Error (209042)`, or the board was working and stopped.** Something else
is holding the connection. Press `F1` in the console, which clears it. See
[8.5](#85-when-the-board-stops-responding).

**Questa's waveform is empty, or missing signals.** You left out
`-voptargs=+acc`. See [8.3](#83-systemverilog-the-gui-way).

**GUI text is unreadably small.** Your viewer is showing the desktop at
Full Size instead of Scaled. See [7.3](#73-launch-it-gui).

**Anything else:** see [TROUBLESHOOTING.md](TROUBLESHOOTING.md), and please
[open an issue](https://github.com/Horse-5-333/cpen-tools/issues)
saying what you have and what happened. A setup that differs from the one
this was verified on is useful to know about either way.

**[mac]**
```bash
cpen-setup --report
```

If you did not get as far as [5.1](#51-adding-these-tools-to-path), or you
used `--no-path`, `cpen-setup` is not a command yet. `cd` to the `cpen-tools`
folder you cloned in [6.1](#61-install-the-tools) and run it from there:

**[mac]**
```bash
./bin/cpen-setup --report
```

Paste the result into the issue. It lists your Mac, macOS build, OrbStack,
VM, kernel, Quartus and board, then the pass or fail of every step in this
guide, including the ones that would normally stop the script. It changes
nothing, and it takes your home directory and username out before printing.
