# AXI4-Lite Slave IP

A parameterizable AXI4-Lite slave peripheral implemented in SystemVerilog. The design includes memory-mapped registers, independent write-channel handshakes, byte-enabled writes, and read/write response handling.

## Features

- AXI4-Lite read and write channels
- Independent AW and W channel handshakes
- Parameterizable register bank
- Byte strobes for partial writes
- OKAY and SLVERR response handling
- Address alignment and range validation
- Reset handling
- SystemVerilog Assertions (SVA) for response stability under backpressure

## Architecture

| File | Description |
|---|---|
| `rtl/axi4_lite_slave.sv` | Top-level integration |
| `rtl/axi_write_channel.sv` | Write-channel logic |
| `rtl/axi_read_channel.sv` | Read-channel logic |
| `rtl/register_bank.sv` | Memory-mapped register bank |
| `rtl/axi_write_assertions.sv` | SVA checker |
| `tb/tb_axi4_lite_slave.sv` | Verification testbench |

## Verification

The testbench contains 12 directed tests covering reset, full-word and partial writes, invalid addresses, independent AW/W handshakes, response backpressure, register boundaries, reset during pending transactions, consecutive transactions, and concurrent read/write activity.

**Regression result:** 12/12 directed tests passed using Verilator with assertions enabled. This is simulation-based verification, not a formal proof of all possible input sequences.

## Tools

- SystemVerilog
- Verilator
- Yosys

## Running the Tests

Run lint:

```bash
make lint
```

Build and run the testbench:

```bash
make test
```

Run the compiled testbench after building:

```bash
./obj_dir/Vtb_axi4_lite_slave
```

Clean generated build files and VCD waveforms:

```bash
make clean
```

## Synthesis Reports

The `reports/` directory contains the Yosys synthesis log and synthesized Verilog netlist.
