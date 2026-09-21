# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It is the shared instruction file for every coding agent used here — `AGENTS.md` is a symlink to it, so Codex and other `AGENTS.md`-aware tools read the same content. See [Agent configuration](#agent-configuration).

## Project

A programmable protocol emulator ASIC ("tiny CPU for bit-banging"), written in SystemVerilog, for the Jane Street protocol emulator ASIC competition (`docs/TASK.md`). The repository is currently a **skeleton**: build/lint/CI infrastructure and the three flow targets exist, but `rtl/proto_emu.sv`, the Verilator wrapper, and the FPGA top are empty module shells.

Hard constraints from the competition task that shape every architectural decision:

- Target process is IHP 130nm CMOS5L via Tiny Tapeout, **6x4 tiles** (~0.7 mm², budget ~1K logic cells/tile).
- Must stay reprogrammable post-fabrication — a fixed UART/SPI/I2C block set is explicitly a non-goal. Reference points are RP2040 PIO and TI Sitara PRU.
- SRAM is preferred over flip-flops for instruction memory on area grounds.
- Deadline 2027-01-18; the design must be open source.

## Environment

All tooling comes from the Nix flake (`flake.nix`) and is auto-activated by direnv (`.envrc`). Every command below assumes the dev shell is active; if a tool is missing, run `direnv allow` in the repo root, or prefix with `nix develop --accept-flake-config --command ...` (this is what CI does).

The shell provides: `bender`, `slang`, `verilator`, `iverilog`, `yosys` (yosysFull), `sv2v`, `gtkwave`. Vivado is *not* in the flake — the Xilinx flow expects a system install.

## Commands

```sh
make lint             # slang + verilator lint
make lint-slang       # slang only
make lint-verilator   # verilator only
make regression       # UART + strobe verification + lint; this is the CI gate
make regression-uart  # UART verification only
make regression-strobe # Strobe verification only

make -C target/sim core CORE_CPP="cpp/<tb>.cpp"   # build Verilator sim binary
make -C target/sim clean

make -C target/xilinx/pynq-z2 bitstream           # also: synth, impl, program
```

UART verification lives in `verif/uart/` and runs through its own `Makefile`.
It checks independent RX stimulus, TX pin timing, loopback,
filtering, errors, and reset/disable recovery across five parameter configurations.
`verif/uart/check_uart_parameters.sh` checks rejection of invalid parameters at elaboration.
Strobe verification lives in `verif/strobe/`, with independent RX stimulus, TX pin
timing and throughput checks, loopback, packet-boundary holds, error recovery, and
synthesis checks that outgoing pads connect directly to flops. See its README for
the bundled-data timing contract and supported parameter combinations.
When adding tests, wire them into `regression` rather than inventing a parallel entry point.

### Known-failing state

- `make lint` currently **fails** (7 slang errors). `proto_emu` is an empty module and slang runs `-Weverything -Werror`, so every unconnected port trips `-Wunused-port` / `-Wundriven-port`. These errors disappear once the module has a body; they are not a lint-config problem.
- `make -C target/sim core` currently fails at link with `undefined reference to 'main'` — `target/sim/cpp/` holds only a `.gitkeep`, and `CORE_CPP` is unset by default, so `verilator --exe` has no testbench to compile.
- `target/xilinx/pynq-z2/vivado/build.tcl` is a license header with no body, and the Makefile's flist rule appends `src/tc_sram.sv`, which does not exist. The FPGA flow will not run until both are filled in.

## Source lists: Bender is the source of truth

`Bender.yml` lists the RTL files; the `.f` file lists consumed by slang, Verilator, and Vivado are **generated** from it via `bender script flist-plus` and are gitignored (they contain absolute paths, so they are per-machine and must never be committed).

Adding an RTL file means editing `Bender.yml` — dropping a `.sv` into `rtl/` does nothing on its own. Each flow regenerates its own flist with a different target set:

| Flow | Flist | Bender targets | Extra files appended by hand |
| --- | --- | --- | --- |
| root lint | `sources.f` | `rtl synthesis` | — |
| Verilator sim | `target/sim/sources_core.f` | `rtl synthesis` | `target/sim/rtl/proto_emu_verilator.sv` |
| UART verification | `verif/uart/sources.f` | `uart_test` | — |
| Strobe verification | `verif/strobe/sources.f` | `strobe_test` | — |
| Strobe pad synthesis check | `verif/strobe/sources_rtl.f` | `strobe_test synthesis` | — |
| pynq-z2 | `target/xilinx/pynq-z2/sources.f` | `rtl synthesis fpga xilinx` | `src/tc_sram.sv`, `src/fpga_top.sv` |

Flist rules depend on `Bender.yml`/`Bender.lock`, so `make` regenerates them automatically — but a stale flist after a `git pull` is worth deleting if something looks wrong.

## Architecture

`rtl/` holds the technology-independent core. `target/` holds per-flow wrappers that must never leak into the core:

- `target/sim/rtl/proto_emu_verilator.sv` — Verilator top (`proto_emu_verilator`), paired with a C++ testbench in `target/sim/cpp/`.
- `target/xilinx/pynq-z2/src/` — `fpga_top.sv` plus `fpga_top_wrap.v`, a plain-Verilog wrapper for Vivado IP integration. Pin constraints in `constraints/fpga_top.xdc`.

`proto_emu` (`rtl/proto_emu.sv`) is parameterized by `NumPins` and by the bus struct types. It exposes both a **subordinate** port (`s_obi_req_i`/`s_obi_rsp_o`, host programs the emulator) and a **manager** port (`m_obi_req_o`/`m_obi_rsp_i`, emulator drives other peripherals). The bus is OBI, defined in `proto_emu_pkg` as packed structs in the PULP layout (`proto_emu_obi_req_t` = `{a: {addr, we, be, wdata}, req}`, `proto_emu_obi_rsp_t` = `{r: {rdata, err}, gnt, rvalid}`), 32-bit address and data. The profile is deliberately minimal — one outstanding transaction, no `rready`, no transaction IDs, none of the optional A/R channel signals — because every optional signal costs tiles. Field names and order follow pulp-platform/obi so the types can be overridden with `OBI_TYPEDEF_ALL` output; parameterizing them (rather than hardcoding) is what lets the module be dropped into a larger SoC with a different OBI configuration — keep that indirection.

`ASSERTS_OFF` is defined in both the lint and sim flows, so any SVA added to the core must sit behind `` `ifndef ASSERTS_OFF ``.

## Conventions

- Style: [lowRISC Verilog Coding Style Guide](https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md) (`CONTRIBUTING.md`). Signal suffixes `_i`/`_o`/`_ni`, `snake_case`, named `endmodule : name`.
- Every source file (`.sv`, `.tcl`, `.xdc`, `Makefile`, `.sh`, `.yml`) starts with the Apache-2.0 WITH SHL-2.1 header block used throughout the repo. Copy it verbatim into new files.
- Slang runs `-Weverything -Werror` with only `-Wno-duplicate-definition` and `-Wno-case-redundant-default` excused, and `.bender/...` suppressed. Third-party code belongs under `.bender/` or `rtl/vendored/` (both already excluded from Verilator lint in `verilator_lint.vlt`) — do not widen the waivers for first-party code.
- `CHANGELOG.md` follows Keep a Changelog with SemVer; add user-visible changes under `[Unreleased]`.
- `.slang/server.json` mirrors the Makefile's slang flags for the editor LSP. If lint flags change in the `Makefile`, update `server.json` to match.

## Agent configuration

- `AGENTS.md` → `CLAUDE.md` is a **symlink**, not a copy. Edit `CLAUDE.md`; never replace the symlink with a duplicate file, because the two will drift. On a Windows checkout without `core.symlinks`, `AGENTS.md` lands as a text file containing the path `CLAUDE.md` — read `CLAUDE.md` instead.
- When a `.claude/` directory is added, read it regardless of which agent you are. The path is Claude-specific but the contents are not: `.claude/skills/*/SKILL.md` and `.claude/commands/*.md` are plain-markdown procedures any agent can follow, and you should read the relevant one before starting a task it covers. `.claude/settings.json` (permissions, hooks) is Claude Code-only and has no equivalent elsewhere — do not try to act on it.
