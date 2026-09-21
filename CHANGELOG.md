<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Tiny Tapeout target under `target/tinytapeout/`, flattening the design with `sv2v` into a single Verilog-2005 file (`tt_um_proto_emu`) for the separate Tiny Tapeout project repository. `make regression-tinytapeout` checks that the generated file elaborates and synthesizes on its own and reports the cell count, and CI uploads it as the workflow artifact `tt_um_proto_emu-<commit sha>`. The pinout and the reasoning behind the repository split are documented in the target's README.
- `proto_emu_top` now instantiates both host link PHYs with a PHY select, and a placeholder loopback that echoes each received byte back to the host as a single-byte packet, pending the packet layer.

- Strobe RX/TX PHYs with unfiltered synchronized inputs, packet-boundary hold, low-nibble-first transfers, configurable setup/hold/frame timing, and direct flop-driven pad outputs. Continuous TX has no byte-boundary bubbles.
- Strobe verification under `verif/strobe/`, including pin timing, packet errors, backpressure, recovery, parameter checks, and synthesis checks for pad flops, integrated into `make regression` and CI.

- Backup UART RX/TX PHYs with configurable clock and baud rate, 8N1 byte streams, and back-to-back transmit frames. RX includes input synchronization, optional glitch filtering (enabled by default), start-bit validation, and framing/overflow error pulses. Packet framing remains the responsibility of the packet layer.
- Self-checking UART simulation under `verif/uart/` across clock and filter configurations, integrated into `make regression` and CI, with independent TX waveform and RX stimulus checks.
