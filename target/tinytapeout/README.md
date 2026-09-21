# Tiny Tapeout target

Flattens the design into a single Verilog-2005 file for the Tiny Tapeout IHP
130nm CMOS5L flow. The Tiny Tapeout project repository is kept separate so this
repository stays technology independent and importable with Bender; it holds
only `info.yaml`, the documentation, the Tiny Tapeout GDS workflow, and the
generated file produced here.

```sh
make -C target/tinytapeout verilog  # build/tt_um_proto_emu.v
make -C target/tinytapeout check    # elaborate and synthesize it, report cells
make -C target/tinytapeout clean
```

`check` also runs as part of `make regression` from the repository root.

The Tiny Tapeout top level `tt_um_proto_emu` lives in `src/` rather than in the
project repository so that it is regenerated, elaborated, and area-checked with
the RTL it constrains. The Bender flist for this flow adds the `tinytapeout`
target, which is where a technology-specific SRAM macro wrapper belongs once
instruction memory exists. The portable core must never instantiate one
directly.

## Generation

`sv2v` reads the plain Bender flist (not `flist-plus`; it takes bare paths) with
`--top=tt_um_proto_emu`, so the output is elaborated and pruned to one
self-contained file. `ASSERTS_OFF` is defined, matching the lint and simulation
flows. The result is checked with `yosys`, which must elaborate it with no
SystemVerilog left behind and synthesize it to generic cells; `stat` reports the
cell count against the roughly 1K cells per tile budget for the 6x4 allocation.

The generated file is not committed here. CI uploads it as the workflow artifact
`tt_um_proto_emu-<commit sha>`, so the usual way to get one is to download it
from the run rather than to build it locally. Copy it into the Tiny Tapeout
project repository and list it under `source_files` in `info.yaml`, together
with the proto-emu commit it was generated from. Mapping to real `sg13g2` cells needs the
IHP PDK, which is not in the flake; until it is, treat the generic cell count as
a trend rather than an area number.

## Pinout

Tiny Tapeout fixes the pad budget at eight dedicated inputs, eight dedicated
outputs, and eight bidirectional pads, independent of the tile count. Going from
6x4 to 8x4 tiles buys area, not pins, so this mapping is the entire chip I/O.

| Pad | Function |
| --- | --- |
| `ui_in[3:0]` | Strobe `HD[3:0]`; `ui_in[0]` doubles as the UART RX pad |
| `ui_in[4]` | Strobe `HSTRB` |
| `ui_in[5]` | Strobe `HFRM` |
| `ui_in[6]` | Strobe `HHOLD` |
| `ui_in[7]` | Host link PHY select, high for strobe, low for UART |
| `uo_out[3:0]` | Strobe `CD[3:0]` |
| `uo_out[4]` | Strobe `CSTB` |
| `uo_out[5]` | Strobe `CFRM` |
| `uo_out[6]` | Strobe `CHOLD` |
| `uo_out[7]` | UART TX |
| `uio[7:0]` | Protocol emulation pins, `NumPins` is 8 |

The two host link PHYs are mutually exclusive, so the UART RX pad shares a
strobe data pad. The strobe outputs are deliberately not shared: the bundled
data contract in `verif/strobe/README.md` requires them to come straight off
their output flops, and a pad multiplexer would break it. That is what leaves
the design without a spare output pad for status.

`ClkHz` on `tt_um_proto_emu` must match `clock_hz` in `info.yaml`; it sets the
UART divisor. The module name must be unique on the shuttle, so rename it (and
`TOP` in the Makefile) if `tt_um_proto_emu` is taken.

## Current state

`proto_emu` is an empty module and there is no packet layer yet, so
`proto_emu_top` runs a placeholder loopback: each byte received on the selected
PHY is echoed back as a single-byte packet. This exists to keep both PHYs
reachable through synthesis so the cell count means something. It is not the
intended host link behaviour.
