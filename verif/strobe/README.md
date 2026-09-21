# Strobe PHY verification and timing

Run `make regression-strobe` from the repository root in the Nix shell, or
`make regression` for all verification and lint. The source list, simulation,
parameter checks, and pad synthesis checks are managed by this directory's
Makefile. `make -C verif/strobe clean` removes generated files.

## Wire protocol

Each strobe transition transfers one nibble, low nibble first. Frame stays high
for a packet and low between packets. The strobe retains its level across idle
periods; there is no idle-polarity requirement. The first complete received byte
has `sof_o` asserted with `valid_o`. Empty frames deliver no bytes. Partial bytes,
out-of-frame strobes, and overlapping RX sampling windows pulse `err_o`; a timing
violation discards the rest of that frame. Bytes already delivered cannot be
retracted, so the packet layer must discard an errored packet.

Hold applies only at packet boundaries. TX synchronizes `hhold_i` and waits
before admitting a new packet; an active packet continues even if hold rises.
RX registers `hold_i` onto `chold_o` but continues accepting in-flight data. The
FIFO threshold must leave room for data already in flight and the active packet,
including the peer's hold synchronization latency. Hold is advisory, not a
per-byte ready signal.

## Timing and throughput

`cd_o`, `cstb_o`, `cfrm_o`, and `chold_o` are driven directly by flops. TX changes
data, waits `SetupCycles`, toggles the strobe, then holds data for
`CyclesPerNibble - SetupCycles` clocks. Consecutive bytes have no extra gap when
the producer keeps valid asserted. A packet ends after the final high nibble's
hold time, followed by exactly `FrameGuard` low-frame clocks before another
queued packet may start. Starvation between bytes keeps frame high and the data
and strobe unchanged. A byte and its `last_i` marker are captured together on
`valid_i && ready_o`.

The default TX rate is one nibble per four clocks (one byte per eight clocks).
The minimum TX period is two clocks with one setup clock and one hold clock.
These are digital cycle counts, not a claim of post-layout clock frequency.

RX uses matched `SyncStages` pipelines on data, frame, and strobe, with no noise
filter. After detecting a synchronized toggle, it samples synchronized data
`SampleDelay` clocks later. The source must establish all data bits before the
toggle and hold them for at least `SampleDelay + 1` receiver clock periods after
it, with additional margin for clock uncertainty, pad skew, and metastability.
Successive toggles must be more than `SampleDelay` receiver clocks apart, and
each strobe level and the low-frame gap must be long enough to be sampled.
The peer's timing must meet this contract; TX timing parameters alone cannot
guarantee an asynchronous receiver's timing. `SampleDelay=0` supports the
shortest nominal receive window. Data/control CDC paths still need physical
timing constraints when integrating the core.

Disabling RX aborts reception and waits for an idle frame before rearming, so
enabling during a packet does not publish its tail as a new packet. Disabling TX
drops frame on a clock edge and retains data/strobe, avoiding an extra toggle.
Reset initializes the pads and clears partial transfers.

## Checks

Four configurations cover the defaults, minimum TX timing with zero RX delay,
three synchronization stages with a longer sample delay, and odd counter periods.
Each checks all byte values, asynchronous input phases, back-to-back packets,
first-byte markers, advisory hold, malformed packets, disable/reset recovery,
producer starvation, and continuous TX/loopback. Every TX clock is checked for
data, setup/hold time, strobe timing, ready timing, and inter-packet guard time.
Pad changes outside rising clock edges are rejected except during reset.

Six invalid parameter combinations must fail elaboration. `check_pad_flops.sh`
converts the Bender-listed RTL with sv2v and uses Yosys to require flop drivers
and reject combinational drivers immediately before the outgoing pad ports.
