# verilog.mk - the Verilog labs: your own hardware.
#
# Here the design IS the hardware, so you build the bitstream yourself and
# there is no processor and no program to download. Nothing in this file is
# used by cpen-nios; these are make targets you run directly.

# -------------------------------------------------------- new project ---
# Writes the .qpf and .qsf that Quartus's New Project Wizard would produce,
# so the GUI-only setup step is not a blocker.
#
#     labmake NEWPROJECT TOP=fulladder
#
# Part numbers are the ones the course lists per board. The fpgacademy
# projects are NOT a safe source for these: their DE10-Lite targets an
# engineering-sample part (10M50DAF484C6GES) rather than the retail C7G.
FAMILY_DE10-Lite     := MAX 10 FPGA
DEVICE_DE10-Lite     := 10M50DAF484C7G
FAMILY_DE1-SoC       := Cyclone V
DEVICE_DE1-SoC       := 5CSEMA5F31C6
FAMILY_DE0-CV        := Cyclone V
DEVICE_DE0-CV        := 5CEBA4F23C7N

FAMILY ?= $(FAMILY_$(BOARD))
DEVICE ?= $(DEVICE_$(BOARD))
PROJ   ?= $(TOP)

NEWPROJECT:
	@test -n "$(TOP)" || { echo "pass the top module: labmake NEWPROJECT TOP=<module>" >&2; exit 1; }
	@test -n "$(DEVICE)" || { echo "no part number known for BOARD=$(BOARD); pass DEVICE= and FAMILY=" >&2; exit 1; }
	@test ! -f "$(PROJ).qsf" || { echo "$(PROJ).qsf already exists; not overwriting" >&2; exit 1; }
	@if [ ! -f "$(TOP).sv" ] && [ -z "$(RTL_SRCS)" ]; then \
	  { echo '// $(TOP) - top-level module for this project.'; \
	    echo '// Declare your ports between the parentheses.'; \
	    echo ''; \
	    echo 'module $(TOP) ('; \
	    echo ');'; \
	    echo ''; \
	    echo 'endmodule'; } > $(TOP).sv; \
	  echo "wrote $(CURDIR)/$(TOP).sv"; \
	fi
	@echo 'PROJECT_REVISION = "$(PROJ)"' > $(PROJ).qpf
	@{ \
	  echo '# Written by: labmake NEWPROJECT TOP=$(TOP)'; \
	  echo ''; \
	  echo 'set_global_assignment -name FAMILY "$(FAMILY)"'; \
	  echo 'set_global_assignment -name DEVICE $(DEVICE)'; \
	  echo 'set_global_assignment -name TOP_LEVEL_ENTITY $(TOP)'; \
	  echo ''; \
	  echo '# One line per source file. Add more as you create them.'; \
	  for f in $$(ls *.sv *.v 2>/dev/null | grep -vE '_tb\.(sv|v)$$|^tb_'); do \
	    case "$$f" in \
	      *.sv) echo "set_global_assignment -name SYSTEMVERILOG_FILE $$f" ;; \
	      *.v)  echo "set_global_assignment -name VERILOG_FILE $$f" ;; \
	    esac; \
	  done; \
	  echo ''; \
	  echo '# Pins, from Appendix B of the lab. Two lines per signal, and one'; \
	  echo '# pair per bit of a bus - never a range. Uncomment and edit:'; \
	  echo '#set_location_assignment PIN_C10 -to SW[0]'; \
	  echo '#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[0]'; \
	} > $(PROJ).qsf
	@echo "wrote $(CURDIR)/$(PROJ).qpf and $(PROJ).qsf  ($(BOARD): $(DEVICE))"

# ------------------------------------------------------- your own design ---
# For the Verilog labs, where you build the bitstream instead of loading the
# prebuilt Nios V computer.
#
# Verified on a DE10-Lite: the sample design from lamadaemon's guide,
# retargeted to MAX 10, compiled in 30s and programmed in 3s.
#
# QPF is the Quartus project in this directory; PROJECT is its revision name,
# which is what quartus_sh --flow compile takes and what names the .sof.
QPF     ?= $(firstword $(wildcard *.qpf))
PROJECT ?= $(basename $(notdir $(QPF)))

# Where quartus_sh leaves the bitstream. Older projects write beside the
# project file rather than into output_files/, so accept either.
PROJECT_SOF ?= $(firstword $(wildcard output_files/$(PROJECT).sof) \
                          $(wildcard $(PROJECT).sof))

SYNTH:
	@test -n "$(QPF)" || { echo "no .qpf in $(CURDIR) - not a Quartus project" >&2; exit 1; }
	$(QUARTUS_BIN)/quartus_sh --flow compile $(PROJECT)

# Program the bitstream built here rather than the Nios V one.
PROGRAM_PROJECT:
	@test -n "$(PROJECT_SOF)" || { echo "no built .sof for $(PROJECT) - run SYNTH first" >&2; exit 1; }
	$(QP_PROGRAMMER) $(CABLE_FLAG) -m jtag -o "P;$(PROJECT_SOF)@$(JTAG_INDEX)"

# --------------------------------------------------------- opening files ---
# Everything here writes a file on the Mac, because the lab directory is
# shared. OrbStack's `mac` bridge runs a macOS command from inside the VM,
# which is how a file built here gets opened by an app over there.
#
#     labmake SIM_WAVE OPEN=1      or      labmake WAVE
#
# The two viewers are different kinds of thing, so each names a full command
# rather than an app: Surfer installs as a CLI binary with no .app bundle,
# so "open -a Surfer" cannot find it.
OPEN          ?=
RTL_OPEN_CMD  ?= open -a Preview
WAVE_OPEN_CMD ?= surfer

# Run through a LOGIN shell so Homebrew is on PATH, and background it so a
# viewer that stays open does not block make.
# $(1) file, $(2) command
define open_on_mac
	@if [ -n "$(OPEN)" ]; then \
	  if ! command -v mac >/dev/null 2>&1; then \
	    echo "no OrbStack 'mac' bridge here; open $(1) yourself" >&2; \
	  elif mac sh -lc '$(2) "$(CURDIR)/$(1)" >/dev/null 2>&1 &' 2>/dev/null; then \
	    echo "opened $(1) with $(firstword $(2))"; \
	  else \
	    echo "could not open $(1) with '$(2)'; is it installed on the Mac?" >&2; \
	  fi; \
	fi
endef

# ------------------------------------------------------------ schematic ---
# A stand-in for Quartus's RTL Viewer, which has no command-line equivalent.
# Yosys elaborates the same source and graphviz draws it.
#
# Note this is a SECOND synthesiser reading your code, not a view of what
# Quartus built. For catching an accidental latch or a register you did not
# mean to infer, an independent opinion is arguably the more useful one.
#
# The design only: a testbench is not part of the hardware.
RTL_SRCS ?= $(filter-out %_tb.sv %_tb.v tb_%.sv tb_%.v, $(wildcard *.sv) $(wildcard *.v))

# Top module: the .qsf names it, otherwise fall back to the first file.
RTL_QSF_TOP := $(if $(QSF),$(shell sed -n 's/.*TOP_LEVEL_ENTITY[ \t]*\([^ \t]*\).*/\1/p' $(QSF) 2>/dev/null | head -1))
RTL_TOP     ?= $(if $(RTL_QSF_TOP),$(RTL_QSF_TOP),$(basename $(notdir $(firstword $(RTL_SRCS)))))

# proc turns always-blocks into registers and muxes, which is what makes the
# picture readable. A full synth would map to gates and lose the structure.
#
# netlistsvg draws proper IEEE gate symbols with orthogonal routing and is
# much closer to Quartus's RTL Viewer than graphviz boxes, so it is used
# when present. Install it once with:
#     sudo apt-get install -y nodejs npm && sudo npm install -g netlistsvg
#
# What neither renderer can fix: Yosys's Verilog frontend splits multi-input
# gate primitives into binary ones and drops your instance names, so a
# 3-input or becomes two 2-input gates and "o2" becomes "$or$file:6$4".
# Quartus keeps both. For a diagram that matches the handout exactly, its
# own viewer is the only option.
RTL:
	@test -n "$(RTL_SRCS)" || { echo "no Verilog in $(CURDIR)" >&2; exit 1; }
	@command -v yosys >/dev/null || { echo "yosys not installed: sudo apt-get install -y yosys graphviz" >&2; exit 1; }
	@if command -v netlistsvg >/dev/null; then \
	  yosys -q -p "read_verilog -sv $(RTL_SRCS); hierarchy -check -top $(RTL_TOP); proc; opt_clean; write_json $(RTL_TOP)_rtl.json" && \
	  netlistsvg $(RTL_TOP)_rtl.json -o $(RTL_TOP)_rtl.svg && \
	  echo "wrote $(CURDIR)/$(RTL_TOP)_rtl.svg  (netlistsvg)"; \
	else \
	  yosys -q -p "read_verilog -sv $(RTL_SRCS); hierarchy -check -top $(RTL_TOP); proc; opt_clean; show -format svg -prefix $(RTL_TOP)_rtl $(RTL_TOP)" && \
	  echo "wrote $(CURDIR)/$(RTL_TOP)_rtl.svg  (graphviz; install netlistsvg for gate symbols)"; \
	fi
	$(call open_on_mac,$(RTL_TOP)_rtl.svg,$(RTL_OPEN_CMD))

# ---------------------------------------------------------- simulation ---
# Questa Starter is free but still needs a licence file, named by
# SALT_LICENSE_SERVER. cpen-nios passes it from detection; set it here
# only if you are running make directly.
QUESTA_BIN          ?= $(INSTALL)/questa_fse/linux_x86_64
SALT_LICENSE_SERVER ?=
export SALT_LICENSE_SERVER

# Everything synthesisable plus the bench. Override SIM_SRCS to narrow it.
SIM_SRCS ?= $(wildcard *.sv) $(wildcard *.v)

# The bench is the module to run, and vsim wants the MODULE name, which
# often is not the file name: a fulladder_tb.sv commonly declares
# "module testbench". Read the declaration rather than guess. Override TB
# to force a particular one.
TB_FILE ?= $(firstword $(wildcard *_tb.sv) $(wildcard tb_*.sv) \
                       $(wildcard *_tb.v)  $(wildcard tb_*.v))
TB_MOD  := $(if $(TB_FILE),$(shell grep -oE '(^|[^A-Za-z0-9_])module[ \t]+[A-Za-z_][A-Za-z0-9_]*' $(TB_FILE) 2>/dev/null | head -1 | grep -oE '[A-Za-z_][A-Za-z0-9_]*$$'))
TB      ?= $(if $(TB_MOD),$(TB_MOD),$(basename $(notdir $(TB_FILE))))

sim-check:
	@test -n "$(SALT_LICENSE_SERVER)" || { \
	  echo "no Questa licence: set SALT_LICENSE_SERVER to your .dat file" >&2; exit 1; }
	@test -n "$(TB)" || { \
	  echo "no testbench found in $(CURDIR) - name it *_tb.sv or pass TB=<module>" >&2; exit 1; }

# The work library is rebuilt from scratch every time. Questa caches an
# optimised design and will happily run the previous build after you edit a
# source, reporting results for code you no longer have. Lab-sized designs
# compile in seconds, so correctness is worth far more than the cache.
SIM_COMPILE: sim-check
	@$(RM) -r work
	@$(QUESTA_BIN)/vlib work
	$(QUESTA_BIN)/vlog -sv $(SIM_SRCS)

# Headless. A self-checking testbench reports pass or fail right here, so
# no waveform viewer is needed for the result itself.
SIM: SIM_COMPILE
	$(QUESTA_BIN)/vsim -c -voptargs=+acc -do "run -all; quit" $(TB)

# Same run, plus a VCD to open in a viewer on the Mac. The vcd commands go
# in the do-script rather than the testbench, so no source changes.
#
# +acc is required: Questa optimises signal visibility away by default, and
# without it "vcd add -r /*" matches nothing and writes a header-only file.
SIM_WAVE: SIM_COMPILE
	$(QUESTA_BIN)/vsim -c -voptargs=+acc \
	  -do "vcd file $(TB).vcd; vcd add -r /*; run -all; quit" $(TB)
	@echo "wrote $(CURDIR)/$(TB).vcd"
	$(call open_on_mac,$(TB).vcd,$(WAVE_OPEN_CMD))

# Build it and look at it, in one word.
WAVE:
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) SIM_WAVE OPEN=1
SCHEMATIC:
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) RTL OPEN=1

.PHONY: NEWPROJECT SYNTH PROGRAM_PROJECT RTL SIM SIM_WAVE SIM_COMPILE sim-check \
        WAVE SCHEMATIC
newproject: NEWPROJECT
synth: SYNTH
program_project: PROGRAM_PROJECT
rtl: RTL
sim: SIM
sim_wave: SIM_WAVE
wave: WAVE
schematic: SCHEMATIC
.PHONY: newproject synth program_project rtl sim sim_wave wave schematic
