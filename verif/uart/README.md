# UART verification

Run `make regression` from the repository root in the Nix dev shell. This runs UART verification and the existing RTL lint gate. For UART verification alone, run `make regression-uart`. CI uses `make -k regression` so both stages run even if one fails.

`uart_tb.sv` instantiates five `uart_case.sv` scenarios: the default 48 MHz / 115200 baud configuration, the minimum eight clocks per bit, an odd 17-clock period with a four-sample filter, filtering disabled with `FilterCycles=0`, and a one-sample filter. Each scenario checks:

- All 256 received byte values using independent serial stimulus, back-to-back frames, asynchronous edge phases, and approximately ±2% sender baud mismatch.
- False starts and glitches at data sampling points. The filter must reject pulses shorter than its threshold; bypass and one-sample modes must observe them.
- Framing errors, a sustained break without repeated errors, held/dropped bytes, and reception after recovery.
- Reset and disable during start, data, and stop bits, including enabling RX while the input is low.
- Every TX bit's value and duration for all 256 byte values, back-to-back ready/valid handshakes, input-data latching, status, and loopback reception.
- One-cycle RX valid/error pulses, stable data between valid pulses, and no unexpected bytes or errors.

The testbench has a simulation timeout, and assertions are enabled in the Verilator build. `check_uart_parameters.sh` also requires six invalid parameter configurations to fail elaboration with the intended diagnostic.

Bender's `uart_test` target supplies the source list. All UART verification sources,
scripts, documentation, and build rules live in `verif/uart/`. The generated
`sources.f` and `obj_dir/` in that directory are ignored;
`make -C verif/uart clean` removes them.
