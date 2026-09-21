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

module strobe_case #(
  parameter int unsigned CyclesPerNibble = 4,
  parameter int unsigned SetupCycles = 2,
  parameter int unsigned FrameGuard = 4,
  parameter int unsigned SyncStages = 2,
  parameter int unsigned SampleDelay = 1
) (
  output bit done_o
);
  timeunit 1ns;
  timeprecision 1ps;
  localparam time ClockPeriod = 10ns;
  localparam int unsigned DrainCycles = SyncStages + SampleDelay + 5;
  localparam int unsigned HoldCycles = CyclesPerNibble - SetupCycles;

  bit clk;
  bit rst_n = 1'b0;
  bit rx_en = 1'b0;
  bit rx_hold = 1'b0;
  bit [3:0] host_data = '0;
  bit host_strobe = 1'b0;
  bit host_frame = 1'b0;
  bit loopback = 1'b0;
  logic [7:0] rx_data;
  logic rx_valid, rx_sof, rx_err, rx_chip_hold;
  bit tx_en = 1'b0;
  bit [7:0] tx_data = '0;
  bit tx_valid = 1'b0;
  bit tx_last = 1'b0;
  bit host_hold = 1'b1;
  logic [3:0] tx_pins;
  logic tx_strobe, tx_frame, tx_ready, tx_hold, tx_busy;
  bit [8:0] expected_rx[$];
  int unsigned expected_errors = 0;
  int unsigned received_errors;
  int unsigned received_bytes;
  time last_clock;

  initial begin
    clk = 1'b0;
    forever #(ClockPeriod / 2) clk = ~clk;
  end
  initial forever begin
    @(posedge clk);
    last_clock = $time;
  end

  strobe_rx #(.SyncStages(SyncStages), .SampleDelay(SampleDelay)) i_rx (
    .clk_i(clk), .rst_ni(rst_n), .en_i(rx_en),
    .hd_i(loopback ? tx_pins : host_data),
    .hstrb_i(loopback ? tx_strobe : host_strobe),
    .hfrm_i(loopback ? tx_frame : host_frame), .chold_o(rx_chip_hold),
    .data_o(rx_data), .valid_o(rx_valid), .sof_o(rx_sof), .hold_i(rx_hold), .err_o(rx_err)
  );
  strobe_tx #(
    .CyclesPerNibble(CyclesPerNibble), .SetupCycles(SetupCycles),
    .FrameGuard(FrameGuard), .SyncStages(SyncStages)
  ) i_tx (
    .clk_i(clk), .rst_ni(rst_n), .en_i(tx_en), .data_i(tx_data), .valid_i(tx_valid),
    .last_i(tx_last), .ready_o(tx_ready), .cd_o(tx_pins), .cstb_o(tx_strobe),
    .cfrm_o(tx_frame), .hhold_i(host_hold), .hold_o(tx_hold), .busy_o(tx_busy)
  );

  // Pad transitions may only occur at a rising clock edge or during reset.
  initial forever begin
    @(tx_pins, tx_strobe, tx_frame, rx_chip_hold);
    if (rst_n) assert ($time == last_clock) else $fatal(1, "%m asynchronous pad transition");
  end

  initial begin : monitor
    bit [8:0] expected;
    bit previous_valid, previous_error;
    logic [7:0] previous_data;
    previous_valid = 1'b0;
    previous_error = 1'b0;
    previous_data = '0;
    received_errors = 0;
    received_bytes = 0;
    forever begin
      @(posedge clk);
      #1ns;
      if (!rst_n) begin
        assert (!rx_valid && !rx_err && !rx_sof && rx_data == '0)
            else $fatal(1, "%m RX reset");
        previous_valid = 1'b0;
        previous_error = 1'b0;
        previous_data = '0;
      end else begin
        assert (!(rx_valid && rx_err) && (!rx_sof || rx_valid))
            else $fatal(1, "%m RX status");
        assert (!(rx_valid && previous_valid) && !(rx_err && previous_error))
            else $fatal(1, "%m RX pulse width");
        if (rx_valid) begin
          assert (rx_en && expected_rx.size() != 0) else $fatal(1, "%m unexpected RX byte");
          expected = expected_rx.pop_front();
          assert ({rx_sof, rx_data} == expected)
              else $fatal(1, "%m RX expected %03x, got %03x", expected, {rx_sof, rx_data});
          received_bytes++;
        end else begin
          assert (rx_data == previous_data) else $fatal(1, "%m data changed without valid");
        end
        if (rx_err) begin
          received_errors++;
          assert (received_errors <= expected_errors) else $fatal(1, "%m unexpected RX error");
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

  task automatic drain();
    cycles(DrainCycles);
    assert (expected_rx.size() == 0) else $fatal(1, "%m missing RX bytes");
    assert (received_errors == expected_errors) else $fatal(1, "%m missing RX error");
  endtask

  task automatic rx_nibble(input bit [3:0] value);
    host_data = value;
    #(SetupCycles * ClockPeriod);
    host_strobe = !host_strobe;
    #(HoldCycles * ClockPeriod);
  endtask

  task automatic rx_byte(input byte unsigned value, input bit first);
    expected_rx.push_back({first, value});
    rx_nibble(value[3:0]);
    rx_nibble(value[7:4]);
  endtask

  task automatic rx_packet(input byte unsigned value);
    host_frame = 1'b1;
    rx_byte(value, 1'b1);
    host_frame = 1'b0;
    #(FrameGuard * ClockPeriod);
  endtask

  // Check every output clock against the pin protocol. This also enforces the
  // exact nibble rate across byte boundaries, rather than just decoded data.
  task automatic tx_byte(input byte unsigned value, input bit last);
    bit old_strobe;
    bit expected_strobe;
    old_strobe = tx_strobe;
    for (int unsigned nibble = 0; nibble < 2; nibble++) begin
      for (int unsigned cycle_index = 0; cycle_index < CyclesPerNibble; cycle_index++) begin
        expected_strobe = old_strobe ^ (nibble != 0) ^ (cycle_index >= SetupCycles);
        assert (tx_frame && tx_busy && tx_strobe == expected_strobe)
            else $fatal(1, "%m TX strobe/frame timing at nibble %0d cycle %0d", nibble, cycle_index);
        assert (tx_pins == ((nibble == 0) ? value[3:0] : value[7:4]))
            else $fatal(1, "%m TX data expected %02x", value);
        assert (tx_ready == (!last && nibble == 1 && cycle_index == CyclesPerNibble - 1))
            else $fatal(1, "%m TX inserted a byte-boundary bubble or asserted ready early");
        cycles(1);
      end
    end
  endtask

  task automatic wait_ready();
    for (int unsigned i = 0; i < DrainCycles + FrameGuard; i++) begin
      if (tx_ready) return;
      cycles(1);
    end
    $fatal(1, "%m TX ready timeout");
  endtask

  initial begin : stimulus
    bit saved_strobe;
    cycles(3);
    assert (!tx_frame && !tx_busy && !tx_ready && rx_chip_hold) else $fatal(1, "%m reset pads");
    rst_n = 1'b1;
    tx_en = 1'b1;
    rx_en = 1'b1;
    cycles(DrainCycles);
    assert (!tx_ready && tx_hold && !rx_chip_hold) else $fatal(1, "%m initial hold");

    // All values at full rate within one packet, with asynchronous source phase.
    #3ns;
    host_frame = 1'b1;
    for (int unsigned value = 0; value < 256; value++) rx_byte(8'(value), value == 0);
    host_frame = 1'b0;
    drain();
    // Short packets exercise SOF and the minimum frame gap at every clock phase.
    for (int unsigned phase = 0; phase < 10; phase++) begin
      if (phase != 0) #(phase * 1ns);
      for (int unsigned value = 0; value < 8; value++) rx_packet(8'(value * 33));
      drain();
    end

    // CHOLD is registered advisory backpressure; a packet already on the wire
    // still completes, even if hold rises between its nibbles.
    host_frame = 1'b1;
    expected_rx.push_back({1'b1, 8'h69});
    rx_nibble(4'h9);
    rx_hold = 1'b1;
    rx_nibble(4'h6);
    cycles(DrainCycles);
    assert (rx_chip_hold) else $fatal(1, "%m CHOLD did not assert");
    rx_byte(8'h87, 1'b0);
    host_frame = 1'b0;
    drain();
    rx_hold = 1'b0;
    cycles(1);
    assert (!rx_chip_hold) else $fatal(1, "%m CHOLD did not clear");

    // First strobe and frame rise may coincide if data was set up beforehand.
    host_data = 4'ha;
    #(ClockPeriod);
    host_frame = 1'b1;
    host_strobe = !host_strobe;
    #(HoldCycles * ClockPeriod);
    expected_rx.push_back({1'b1, 8'hba});
    rx_nibble(4'hb);
    host_frame = 1'b0;
    drain();

    // Empty frames are harmless. An orphan edge and an odd nibble count are not.
    host_frame = 1'b1;
    #(CyclesPerNibble * ClockPeriod);
    host_frame = 1'b0;
    drain();
    expected_errors++;
    host_strobe = !host_strobe;
    drain();
    host_frame = 1'b1;
    rx_nibble(4'hf);
    expected_errors++;
    host_frame = 1'b0;
    drain();
    rx_packet(8'h42);
    drain();

    if (SampleDelay != 0) begin
      // Overlapping sample windows invalidate the packet, once, without
      // leaking partial data; toggles in the rest of the packet are discarded.
      host_frame = 1'b1;
      cycles(DrainCycles);
      expected_errors++;
      host_strobe = !host_strobe;
      cycles(1);
      host_strobe = !host_strobe;
      cycles(1);
      host_strobe = !host_strobe;
      cycles(DrainCycles);
      host_frame = 1'b0;
      drain();
      rx_packet(8'h24);
      drain();
    end

    for (int unsigned reset_case = 0; reset_case < 2; reset_case++) begin
      host_frame = 1'b1;
      rx_nibble(4'h1);
      cycles(DrainCycles);
      if (reset_case != 0) rst_n = 1'b0;
      else rx_en = 1'b0;
      cycles(DrainCycles);
      rst_n = 1'b1;
      rx_en = 1'b1;
      cycles(DrainCycles);
      // Enabling during an active packet must wait for the next frame.
      rx_nibble(4'h2);
      rx_nibble(4'h3);
      host_frame = 1'b0;
      drain();
      rx_packet(8'h81);
      drain();
    end

    // Continuous TX, independent pin timing checks and RX loopback. HHOLD rises
    // mid-packet but must not reduce throughput or prevent packet completion.
    host_hold = 1'b0;
    rx_en = 1'b0;
    cycles(DrainCycles);
    loopback = 1'b1;
    cycles(DrainCycles);
    rx_en = 1'b1;
    cycles(DrainCycles);
    for (int unsigned value = 0; value < 256; value++)
      expected_rx.push_back({(value == 0), 8'(value)});
    tx_data = '0;
    tx_last = 1'b0;
    tx_valid = 1'b1;
    cycles(1);
    for (int unsigned value = 0; value < 256; value++) begin
      tx_data = 8'(value + 1);
      tx_last = (value == 254);
      if (value == 128) host_hold = 1'b1;
      tx_byte(8'(value), value == 255);
    end
    assert (!tx_frame) else $fatal(1, "%m packet did not end after last byte");
    cycles(DrainCycles + FrameGuard);
    assert (!tx_ready && !tx_frame && !tx_busy && tx_hold) else $fatal(1, "%m packet hold");
    drain();
    tx_data = 8'h69;
    tx_last = 1'b1;
    host_hold = 1'b0;
    wait_ready();
    expected_rx.push_back({1'b1, 8'h69});
    cycles(1);
    tx_valid = 1'b0;
    tx_byte(8'h69, 1'b1);
    drain();

    // Consecutive one-byte packets: exact low-frame guard with queued input.
    for (int unsigned packet = 0; packet < 4; packet++)
      expected_rx.push_back({1'b1, 8'(packet + 16)});
    tx_data = 8'h10;
    tx_last = 1'b1;
    tx_valid = 1'b1;
    wait_ready();
    cycles(1);
    for (int unsigned packet = 0; packet < 4; packet++) begin
      tx_data = 8'(packet + 17);
      tx_valid = (packet != 3);
      tx_byte(8'(packet + 16), 1'b1);
      for (int unsigned i = 0; i < FrameGuard; i++) begin
        assert (!tx_frame && tx_ready == (i == FrameGuard - 1))
            else $fatal(1, "%m frame guard timing");
        cycles(1);
      end
    end
    drain();

    // Producer starvation holds frame/data/strobe steady, then resumes without
    // treating the resumed byte as a new packet, even under asserted HHOLD.
    expected_rx.push_back({1'b1, 8'hab});
    tx_data = 8'hab;
    tx_last = 1'b0;
    tx_valid = 1'b1;
    cycles(1);
    tx_valid = 1'b0;
    tx_byte(8'hab, 1'b0);
    saved_strobe = tx_strobe;
    host_hold = 1'b1;
    cycles(DrainCycles);
    assert (tx_frame && tx_busy && tx_ready && tx_strobe == saved_strobe && tx_pins == 4'ha)
        else $fatal(1, "%m starved packet state");
    expected_rx.push_back({1'b0, 8'hcd});
    tx_data = 8'hcd;
    tx_last = 1'b1;
    tx_valid = 1'b1;
    cycles(1);
    tx_valid = 1'b0;
    tx_byte(8'hcd, 1'b1);
    drain();
    // Switching a mux while idle must not create an orphan strobe in the test.
    host_strobe = tx_strobe;
    loopback = 1'b0;
    host_hold = 1'b0;
    cycles(DrainCycles);

    // Abort during setup, each nibble, and a packet stalled for producer data.
    for (int unsigned phase = 0; phase < 4; phase++) begin
      for (int unsigned reset_case = 0; reset_case < 2; reset_case++) begin
        tx_data = 8'h96;
        tx_last = 1'b0;
        tx_valid = 1'b1;
        wait_ready();
        cycles(1);
        tx_valid = 1'b0;
        cycles(phase * CyclesPerNibble);
        saved_strobe = tx_strobe;
        // Disable off the active edge: combinational pad gating must fail.
        #1ns;
        if (reset_case != 0) rst_n = 1'b0;
        else tx_en = 1'b0;
        cycles(1);
        assert (!tx_frame && !tx_busy) else $fatal(1, "%m TX abort");
        if (reset_case == 0) begin
          assert (tx_strobe == saved_strobe && !tx_ready) else $fatal(1, "%m abort strobe");
        end
        rst_n = 1'b1;
        tx_en = 1'b1;
        cycles(DrainCycles);
      end
    end
    drain();
    $display("PASS %m: nibble=%0d setup=%0d guard=%0d sync=%0d sample=%0d bytes=%0d errors=%0d",
             CyclesPerNibble, SetupCycles, FrameGuard, SyncStages, SampleDelay,
             received_bytes, received_errors);
    done_o = 1'b1;
  end
endmodule : strobe_case
