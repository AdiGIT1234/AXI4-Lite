VERILATOR = verilator
TOP = tb_axi4_lite_slave
OBJ_DIR = obj_dir

RTL = rtl/register_bank.sv \
      rtl/axi_write_channel.sv \
      rtl/axi_read_channel.sv \
      rtl/axi4_lite_slave.sv \
      rtl/axi_write_assertions.sv

TB = tb/tb_axi4_lite_slave.sv

VERILATOR_FLAGS = --timing --trace --assert -Wall --timescale 1ns/1ps

.PHONY: all lint build sim test clean

all: test

lint:
	$(VERILATOR) --lint-only $(VERILATOR_FLAGS) --top-module $(TOP) $(RTL) $(TB)

build:
	$(VERILATOR) --binary $(VERILATOR_FLAGS) --top-module $(TOP) --Mdir $(OBJ_DIR) $(RTL) $(TB)

sim: build
	./$(OBJ_DIR)/V$(TOP)

test: lint sim

clean:
	rm -rf $(OBJ_DIR) obj_dir_negative
	rm -f waveforms/*.vcd
