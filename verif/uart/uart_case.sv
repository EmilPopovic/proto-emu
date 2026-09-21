// Copyright 2026 Emil Popovic, Matej Jurasic
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Emil Popovic <mail@emilpopovic.me>

// Independent pin-level stimulus and checks; no DUT internals are referenced.
module uart_case #(
  parameter int unsigned FClk = 48_000_000,
  parameter int unsigned Baud = 115200,
  parameter int unsigned FilterCycles = 3,
  parameter bit FilterEnable = 1'b1
) (
  output bit done_o
);
  timeunit 1ns;
  timeprecision 1ps;

  localparam int unsigned BitCycles = (FClk + Baud / 2) / Baud;
  localparam time ClockPeriod = 10ns;
  localparam time BitPeriod = BitCycles * ClockPeriod;

  bit clk;
  bit rst_n = 1'b0;
  bit rx_en = 1'b0;
  bit rx_pad = 1'b1;
  bit rx_hold = 1'b0;
  bit loopback = 1'b0;
  logic [7:0] rx_data;
  logic rx_valid, rx_sof, rx_err;
  bit tx_en = 1'b0;
  bit [7:0] tx_data = '0;
  bit tx_valid = 1'b0;
  bit tx_last = 1'b0;
  logic tx_ready, tx_pad, tx_hold, tx_busy;

  byte unsigned expected_rx[$];
  int unsigned expected_errors = 0;
  int unsigned received_errors;
  int unsigned received_bytes;
  bit previous_valid;
  bit previous_error;
  logic [7:0] previous_data;

  initial begin
    clk = 1'b0;
    forever #(ClockPeriod / 2) clk = ~clk;
  end

  uart_rx #(
    .FClk(FClk), .Baud(Baud), .FilterCycles(FilterCycles), .FilterEnable(FilterEnable)
  ) i_rx (
    .clk_i(clk), .rst_ni(rst_n), .en_i(rx_en), .rx_i(loopback ? tx_pad : rx_pad),
    .data_o(rx_data), .valid_o(rx_valid), .sof_o(rx_sof), .hold_i(rx_hold), .err_o(rx_err)
  );

  uart_tx #(.FClk(FClk), .Baud(Baud)) i_tx (
    .clk_i(clk), .rst_ni(rst_n), .en_i(tx_en), .data_i(tx_data), .valid_i(tx_valid),
    .last_i(tx_last), .ready_o(tx_ready), .tx_o(tx_pad), .hold_o(tx_hold), .busy_o(tx_busy)
  );

  // Sample after nonblocking updates, separately from the stimulus tasks.
  initial begin : monitor_rx
    byte unsigned expected;
    received_errors = 0;
    received_bytes = 0;
    previous_valid = 1'b0;
    previous_error = 1'b0;
    previous_data = '0;
    forever begin
      @(posedge clk);
      #1ns;
      if (!rst_n) begin
        assert (!rx_valid && !rx_err && rx_data == '0) else $fatal(1, "%m RX reset");
        previous_valid = 1'b0;
        previous_error = 1'b0;
        previous_data = '0;
      end else begin
        assert (!rx_sof && !tx_hold) else $fatal(1, "%m unexpected packet/hold status");
        assert (!(rx_valid && rx_err)) else $fatal(1, "%m valid and error together");
        assert (!(rx_valid && previous_valid)) else $fatal(1, "%m valid pulse too long");
        assert (!(rx_err && previous_error)) else $fatal(1, "%m error pulse too long");
        if (rx_valid) begin
          assert (rx_en && expected_rx.size() != 0) else $fatal(1, "%m unexpected RX byte");
          expected = expected_rx.pop_front();
          assert (rx_data == expected)
              else $fatal(1, "%m RX expected %02x, got %02x", expected, rx_data);
          received_bytes++;
        end else begin
          assert (rx_data == previous_data) else $fatal(1, "%m data changed without valid");
        end
        if (rx_err) begin
          received_errors++;
          assert (rx_en && received_errors <= expected_errors)
              else $fatal(1, "%m unexpected RX error");
        end
        previous_valid = rx_valid;
        previous_error = rx_err;
        previous_data = rx_data;
      end
    end
  end

  task automatic cycles(input int unsigned count);
    repeat (count) begin
      @(posedge clk);
      #2ns;
    end
  endtask

  task automatic settle();
    rx_pad = 1'b1;
    cycles(12 * BitCycles);
    assert (expected_rx.size() == 0) else $fatal(1, "%m missing RX bytes");
    assert (received_errors == expected_errors) else $fatal(1, "%m missing RX errors");
  endtask

  task automatic rx_frame(input byte unsigned value, input time period = BitPeriod,
                          input bit stop_bit = 1'b1, input int unsigned noise_cycles = 0);
    rx_pad = 1'b0;
    #(period);
    for (int unsigned bit_index = 0; bit_index < 8; bit_index++) begin
      rx_pad = value[bit_index];
      if (noise_cycles != 0) begin
        #(period / 2);
        rx_pad = ~value[bit_index];
        #(noise_cycles * ClockPeriod);
        rx_pad = value[bit_index];
        #(period - period / 2 - noise_cycles * ClockPeriod);
      end else begin
        #(period);
      end
    end
    rx_pad = stop_bit;
    #(period);
  endtask

  // Called immediately after the byte's ready/valid handshake. Check every
  // clock of the pin waveform, including the full stop bit and next handshake.
  task automatic tx_frame(input byte unsigned value);
    bit expected_pin;
    for (int unsigned bit_index = 0; bit_index < 10; bit_index++) begin
      if (bit_index == 0) expected_pin = 1'b0;
      else if (bit_index == 9) expected_pin = 1'b1;
      else expected_pin = value[bit_index - 1];
      for (int unsigned cycle_index = 0; cycle_index < BitCycles; cycle_index++) begin
        assert (tx_pad == expected_pin && tx_busy)
            else $fatal(1, "%m TX %02x bit %0d cycle %0d", value, bit_index, cycle_index);
        assert (tx_ready == ((bit_index == 9) && (cycle_index == BitCycles - 1)))
            else $fatal(1, "%m TX ready timing");
        cycles(1);
      end
    end
  endtask

  initial begin : stimulus
    cycles(3);
    assert (tx_pad && !tx_busy && !tx_ready) else $fatal(1, "%m disabled TX reset");
    rst_n = 1'b1;
    rx_en = 1'b1;
    tx_en = 1'b1;
    cycles(2 * BitCycles);
    assert (tx_pad && tx_ready && !tx_busy) else $fatal(1, "%m idle TX");

    // All byte values, continuous frames, and varying asynchronous edge phase.
    #3ns;
    for (int unsigned value = 0; value < 256; value++) begin
      expected_rx.push_back(8'(value));
      rx_frame(8'(value));
    end
    settle();
    for (int unsigned phase = 0; phase < 10; phase++) begin
      if (phase != 0) #(phase * 1ns);
      expected_rx.push_back(8'h96);
      rx_frame(8'h96);
      settle();
    end

    // Independent sender running approximately +/-2% away from nominal baud.
    for (int unsigned value = 0; value < 16; value++) begin
      expected_rx.push_back(8'(value * 17));
      rx_frame(8'(value * 17), BitPeriod - BitPeriod / 50);
    end
    settle();
    for (int unsigned value = 0; value < 16; value++) begin
      expected_rx.push_back(8'(value * 17));
      rx_frame(8'(value * 17), BitPeriod + BitPeriod / 50);
    end
    settle();

    // False starts must not deliver a byte or report an error.
    rx_pad = 1'b0;
    #(BitPeriod / 4);
    settle();

    // Put noise at the data sampling point. The filtered configurations reject
    // every pulse shorter than FilterCycles. Bypass / one-sample configurations
    // must actually see the pulse, proving that the filter can be disabled.
    for (int unsigned width = 1;
         width < ((FilterEnable && FilterCycles > 1) ? FilterCycles : 2); width++) begin
      @(posedge clk);
      #1ns;
      expected_rx.push_back((FilterEnable && FilterCycles > 1) ? 8'ha5 : 8'h5a);
      rx_frame(8'ha5, BitPeriod, 1'b1, width);
      settle();
    end

    // Stop-bit framing error followed by a sustained break gives one error.
    expected_errors++;
    rx_frame(8'h53, BitPeriod, 1'b0);
    #(20 * BitPeriod);
    settle();
    expected_rx.push_back(8'h42);
    rx_frame(8'h42);
    settle();

    // A completed frame is dropped while held; the following byte is accepted.
    rx_hold = 1'b1;
    expected_errors++;
    rx_frame(8'hde);
    cycles(BitCycles);
    rx_hold = 1'b0;
    expected_rx.push_back(8'had);
    rx_frame(8'had);
    settle();
    // Hold is sampled at completion, not latched at the start of a byte.
    rx_hold = 1'b1;
    rx_pad = 1'b0;
    #(BitPeriod);
    rx_hold = 1'b0;
    rx_pad = 1'b1;
    expected_rx.push_back(8'hff);
    #(9 * BitPeriod);
    settle();

    // Abort in start, data, and stop bits, through both disable and reset.
    for (int unsigned phase = 0; phase < 3; phase++) begin
      for (int unsigned use_reset = 0; use_reset < 2; use_reset++) begin
        rx_pad = 1'b0;
        case (phase)
          0: #(BitPeriod / 4);
          1: #(4 * BitPeriod);
          2: #(9 * BitPeriod + BitPeriod / 4);
          default: $fatal(1, "%m invalid test phase");
        endcase
        if (use_reset != 0) rst_n = 1'b0;
        else rx_en = 1'b0;
        cycles(2 * BitCycles);
        rst_n = 1'b1;
        rx_en = 1'b1;
        // Enabling into a break must wait for idle, without producing a byte.
        cycles(12 * BitCycles);
        settle();
        expected_rx.push_back(8'h81);
        rx_frame(8'h81);
        settle();
      end
    end

    // Exhaustive TX waveform check plus loopback. Holding valid throughout
    // stresses back-to-back handshakes; changing data during busy checks latching.
    loopback = 1'b1;
    cycles(2 * BitCycles);
    for (int unsigned value = 0; value < 256; value++) expected_rx.push_back(8'(value));
    tx_valid = 1'b1;
    tx_data = 8'h00;
    cycles(1);
    for (int unsigned value = 0; value < 256; value++) begin
      tx_data = 8'(value + 1);
      tx_last = (value % 3 == 0);
      tx_valid = (value != 255);
      tx_frame(8'(value));
    end
    assert (tx_pad && tx_ready && !tx_busy) else $fatal(1, "%m TX completion");
    settle();
    loopback = 1'b0;

    for (int unsigned phase = 0; phase < 3; phase++) begin
      for (int unsigned use_reset = 0; use_reset < 2; use_reset++) begin
        tx_data = 8'h00;
        tx_valid = 1'b1;
        cycles(1);
        tx_valid = 1'b0;
        case (phase)
          0: cycles(BitCycles / 4);
          1: cycles(4 * BitCycles);
          2: cycles(9 * BitCycles + BitCycles / 4);
          default: $fatal(1, "%m invalid test phase");
        endcase
        if (use_reset != 0) rst_n = 1'b0;
        else tx_en = 1'b0;
        cycles(2);
        assert (tx_pad && !tx_busy) else $fatal(1, "%m TX abort");
        if (use_reset == 0) begin
          tx_valid = 1'b1;
          cycles(BitCycles);
          assert (!tx_ready && tx_pad) else $fatal(1, "%m disabled TX accepted data");
          tx_valid = 1'b0;
        end
        rst_n = 1'b1;
        tx_en = 1'b1;
        cycles(1);
        assert (tx_pad && tx_ready && !tx_busy) else $fatal(1, "%m TX re-enable");
        tx_data = 8'h69;
        tx_valid = 1'b1;
        cycles(1);
        tx_valid = 1'b0;
        tx_data = 8'hff;
        tx_frame(8'h69);
      end
    end
    settle();
    $display("PASS %m: clocks/bit=%0d filter=%0b/%0d, bytes=%0d errors=%0d",
             BitCycles, FilterEnable, FilterCycles, received_bytes, received_errors);
    done_o = 1'b1;
  end
endmodule : uart_case
