# niosv.mk - the Nios V labs: assemble, download, run, debug.
#
# This is what cpen-nios drives. The program runs on a soft processor
# that the prebuilt bitstream puts into the FPGA, so there are two loading
# steps: the bitstream (common.mk) and then the ELF.

# ---------------------------------------------------------------- source ---
HDRS ?= $(wildcard address_map*.s)
MAIN ?= $(firstword $(filter-out $(HDRS),$(wildcard *.s)))
SRCS := $(MAIN)

ifeq ($(strip $(MAIN)),)
  ifneq ($(filter COMPILE RUN SYMBOLS OBJDUMP GDB_CLIENT,$(MAKECMDGOALS)),)
    $(error No lab .s file found in $(CURDIR) - pass MAIN=yourfile.s)
  endif
endif

SHELL := $(shell command -v bash || echo /bin/bash)

OBJS := $(patsubst %, %.o, $(SRCS))
ELF  := $(basename $(MAIN)).elf

# ------------------------------------------------------------- toolchain ---
# Profile A, the proprietary RISC-V toolchain that Gist 1's
# "qinst.sh --auto-install" installs. This is the default and the only
# one that works out of the box.
ifeq ($(TOOLCHAIN),proprietary)
  COMPILER   := $(INSTALL)/riscfree/toolchain/riscv32-unknown-elf/bin
  GDBSRV_DIR := $(INSTALL)/riscfree/debugger/gdbserver-riscv
  AS := $(COMPILER)/riscv32-unknown-elf-as
  LD := $(COMPILER)/riscv32-unknown-elf-ld
  CC := $(COMPILER)/riscv32-unknown-elf-gcc
  OC := $(COMPILER)/riscv32-unknown-elf-objcopy
  OD := $(COMPILER)/riscv32-unknown-elf-objdump
  NM := $(COMPILER)/riscv32-unknown-elf-nm
  ASFLAGS := -march=rv32im_zicsr --gdwarf2
  LDFLAGS := $(USERLDFLAGS) --section-start .text=0x0 --no-relax
  ARCHCCFLAGS := -march=rv32im_zicsr -mabi=ilp32
  GDB_SERVER := $(GDBSRV_DIR)/ash-riscv-gdb-server
  GDB_CLIENT := $(COMPILER)/riscv32-unknown-elf-gdb

# Profile B, LLVM + OpenOCD + LLDB. EXPERIMENTAL and untested: neither
# setup guide installs LLVM, so nothing here has been run against
# hardware. cpen-setup reports whether clang is present; normally it is not.
#
# Note the console still assumes a standing debug server started at init.
# Under this profile OpenOCD is started by RUN instead and holds the cable
# itself, so the status panes would read wrong. Unfinished on purpose.
else ifeq ($(TOOLCHAIN),llvm)
  AS := clang
  LD := ld.lld
  CC := clang
  OC := llvm-objcopy
  OD := llvm-objdump
  NM := llvm-nm
  ASFLAGS := -c --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32 -gdwarf-2
  LDFLAGS := $(USERLDFLAGS) --image-base=0 --section-start=.text=0x0 --no-relax
  ARCHCCFLAGS := --target=riscv32-unknown-elf -march=rv32im_zicsr -mabi=ilp32
  GDB_CLIENT := lldb
else
  $(error TOOLCHAIN must be 'proprietary' or 'llvm', not '$(TOOLCHAIN)')
endif

RM := rm -f
QP_PROGRAMMER := $(QUARTUS_BIN)/quartus_pgm
export PATH := $(QUARTUS_BIN):$(NIOSV_BIN):$(INSTALL)/quartus/sopc_builder/bin:$(PATH)

# ---------------------------------------------------------------- build ---
COMPILE: $(ELF)

$(ELF): $(OBJS)
	@$(RM) $@
	@echo "Linking:    $(notdir $(LD)) $(LDFLAGS) $(OBJS) -o $@"
	@$(LD) $(LDFLAGS) $(OBJS) -o $@

%.s.o: %.s $(HDRS)
	@$(RM) $@
	@echo "Assembling: $(notdir $(AS)) $(ASFLAGS) $< -o $@"
	@$(AS) $(ASFLAGS) $< -o $@

%.c.o: %.c $(HDRS)
	@$(RM) $@
	@echo "Compiling:  $(notdir $(CC)) $(ARCHCCFLAGS) -c $< -o $@"
	@$(CC) $(ARCHCCFLAGS) -c $< -o $@

SYMBOLS: $(ELF)
	@$(NM) -p $<

OBJDUMP: $(ELF)
	@$(OD) -d -S $<



# ---------------------------------------------------------- run / debug ---
ifeq ($(TOOLCHAIN),proprietary)
GDB_SERVER:
	$(GDB_SERVER) --device auto-scan --gdb-port $(GDB_PORT) --instance 1 \
	  --probe-type USB-Blaster-2 --transport-type jtag --auto-detect true

# The -ex arguments must be in SINGLE quotes. Make turns $$ into $, and in
# double quotes the shell then expands $mstatus to nothing, so gdb receives
# "set =0" and reports: A syntax error in expression, near `=0'.
GDB_CLIENT:
	$(GDB_CLIENT) -silent -ex "target remote:$(GDB_PORT)" -ex 'set $$mstatus=0' \
	  -ex 'set $$mtvec=0' -ex "load" -ex 'set $$pc=_start' -ex "info reg pc" "$(ELF)"

RUN:
	$(NIOSV_BIN)/niosv-download -g $(ELF)
else
# OpenOCD both downloads and serves, so RUN leaves a long-lived process
# holding the JTAG cable - unlike the proprietary profile, where the
# standing server is separate and niosv-download is transient.
GDB_SERVER: niosv.cfg
	openocd -f niosv.cfg

niosv.cfg:
	openocd-cfg-gen niosv.cfg

GDB_CLIENT:
	$(GDB_CLIENT) "$(ELF)" -o "gdb-remote $(GDB_PORT)"

RUN: niosv.cfg
	openocd -f niosv.cfg -c 'init' -c 'reset halt' -c 'load_image $(ELF)'
endif

TERMINAL:
	$(QUARTUS_BIN)/nios2-terminal --instance $(TERM_INSTANCE)

.PHONY: COMPILE SYMBOLS OBJDUMP TERMINAL GDB_SERVER GDB_CLIENT RUN
compile: COMPILE
symbols: SYMBOLS
objdump: OBJDUMP
run: RUN
terminal: TERMINAL
gdb_server: GDB_SERVER
gdb_client: GDB_CLIENT
.PHONY: compile symbols objdump run terminal gdb_server gdb_client
