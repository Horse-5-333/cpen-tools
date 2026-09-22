# common.mk - everything both kinds of lab need.
#
# Board identity, tool locations, programming the FPGA, and the JTAG chain.
# None of this cares whether you are running a Nios V program or your own
# Verilog: it is the layer that gets a working board.

# ---------------------------------------------------------------- inputs ---
INSTALL     ?= /opt/altera
QUARTUS_BIN ?= $(INSTALL)/quartus/bin
NIOSV_BIN   ?= $(INSTALL)/niosv/bin
GDB_PORT    ?= 2454
TERM_INSTANCE ?= 0
TOOLCHAIN   ?= proprietary

# Board. JTAG_INDEX is the FPGA's position in the chain: 1 on a DE10-Lite,
# 2 on a DE1-SoC because the ARM HPS occupies position 1. Do not guess it;
# cpen-nios counts it from jtagconfig.
BOARD       ?= DE10-Lite
# Note the inconsistency in the shipped tree: the directory keeps the
# hyphen (DE10-Lite_Computer) but the file does not (DE10_Lite_Computer.sof).
SOF         ?= $(INSTALL)/fpgacademy/Computer_Systems/$(BOARD)/$(BOARD)_Computer/niosVg/$(subst -,_,$(BOARD))_Computer.sof
JTAG_INDEX  ?= 1

# Empty by default and that is deliberate. Quartus picks the only cable
# when there is one, and the cable name differs between setups - the
# published Windows Makefile hardcodes "USB-Blaster [USB-0]", which does
# not match what OrbStack presents. Set it only for a second cable.
CABLE_FLAG  ?=

# ---------------------------------------------------------------- board ---
DETECT_DEVICES:
	$(QP_PROGRAMMER) $(CABLE_FLAG) --auto

# One target for every board. The old per-board targets are kept below so
# course instructions that say "make DE10-Lite" still work.
PROGRAM:
	@test -f "$(SOF)" || { echo "no bitstream at $(SOF)" >&2; exit 1; }
	$(QP_PROGRAMMER) $(CABLE_FLAG) -m jtag -o "P;$(SOF)@$(JTAG_INDEX)"

DE10-Lite:
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) PROGRAM BOARD=DE10-Lite JTAG_INDEX=1
DE1-SoC:
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) PROGRAM BOARD=DE1-SoC JTAG_INDEX=2


CLEAN:
	$(RM) $(basename $(MAIN)).srec $(ELF) $(OBJS)
	$(RM) -r work transcript *.vcd vsim.wlf *_rtl.svg *_rtl.dot *_rtl.json

WHICH:
	@echo "BOARD      = $(BOARD)"
	@echo "SOF        = $(SOF)"
	@echo "JTAG_INDEX = $(JTAG_INDEX)"
	@echo "TOOLCHAIN  = $(TOOLCHAIN)"
	@echo "TB         = $(TB)"
	@echo "QPF        = $(QPF)"
	@echo "PROJECT    = $(PROJECT)"
	@echo "PROJECT_SOF= $(PROJECT_SOF)"
	@echo "MAIN       = $(MAIN)"
	@echo "ELF        = $(ELF)"

.PHONY: PROGRAM DETECT_DEVICES DE10-Lite DE1-SoC CLEAN WHICH
clean: CLEAN
which: WHICH
program: PROGRAM
de10-lite: DE10-Lite
de1-soc: DE1-SoC
detect_devices: DETECT_DEVICES
.PHONY: clean which program de10-lite de1-soc detect_devices
