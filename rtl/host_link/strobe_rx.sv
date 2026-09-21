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

module strobe_rx #(
  parameter int unsigned SyncStages  = 2,
  // Cycles after synchronized edge detection before sampling synchronized HD
  parameter int unsigned SampleDelay = 1
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic en_i,    // From PHY select, strobe mode active

  // Pads, asynchronous to clk_i
  input  logic [3:0] hd_i,     // Low nibble first
  input  logic       hstrb_i,  // Toggle strobe, one nibble per edge
  input  logic       hfrm_i,   // High for the duration of a packet
  output logic       chold_o,  // Chip hold

  // Byte stream to PHY select
  output logic [7:0] data_o,
  output logic       valid_o,
  output logic       sof_o,    // Qualifies valid_o, first byte after HFRM rise

  // Packet layer
  input  logic hold_i,  // Advisory hold; FIFO must reserve space for in-flight packets
  output logic err_o    // Pulse on error
);

  localparam int unsigned DelayWidth = (SampleDelay > 1) ? $clog2(SampleDelay) : 1;

  typedef enum logic [1:0] {
    StWaitIdle, StIdle, StFrame, StDrop
  } state_e;

  // Match the data/control pipelines. The host must keep HD stable for at least
  // SampleDelay + 1 receiver clocks after each toggle, plus CDC timing margin.
  // There is no debounce or glitch filter on any pad.
  (* async_reg = "true" *) logic [SyncStages-1:0]      hstrb_sync_q, hfrm_sync_q;
  (* async_reg = "true" *) logic [SyncStages-1:0][3:0] hd_sync_q;

  logic [SyncStages:0]   sync_valid_q;
  logic [DelayWidth-1:0] delay_d, delay_q;

  logic       last_strobe_q, strobe_edge, frame;
  logic [3:0] nibble_d, nibble_q;
  logic       half_d, half_q, first_d, first_q;
  logic       pending_d, pending_q, sample;
  logic [7:0] data_d;
  logic       valid_d, sof_d, err_d;

  state_e state_d, state_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hstrb_sync_q  <= '0;
      hfrm_sync_q   <= '0;
      hd_sync_q     <= '0;
      sync_valid_q  <= '0;
      last_strobe_q <= 1'b0;
    end else begin
      hstrb_sync_q[0] <= hstrb_i;
      hfrm_sync_q[0]  <= hfrm_i;
      hd_sync_q[0]    <= hd_i;
      for (int unsigned i = 1; i < SyncStages; i++) begin
        hstrb_sync_q[i] <= hstrb_sync_q[i-1];
        hfrm_sync_q[i]  <= hfrm_sync_q[i-1];
        hd_sync_q[i]    <= hd_sync_q[i-1];
      end
      sync_valid_q  <= {sync_valid_q[SyncStages-1:0], 1'b1};
      last_strobe_q <= hstrb_sync_q[SyncStages-1];
    end
  end

  assign strobe_edge = hstrb_sync_q[SyncStages-1] ^ last_strobe_q;
  assign frame       = hfrm_sync_q[SyncStages-1];

  always_comb begin
    state_d   = state_q;
    nibble_d  = nibble_q;
    half_d    = half_q;
    first_d   = first_q;
    pending_d = pending_q;
    delay_d   = delay_q;
    data_d    = data_o;
    valid_d   = 1'b0;
    sof_d     = 1'b0;
    err_d     = 1'b0;
    sample    = 1'b0;

    case (state_q)
      StWaitIdle: begin
        if (sync_valid_q[SyncStages] && !frame) state_d = StIdle;
      end
      StIdle: begin
        if (frame) state_d = StFrame;
        else if (strobe_edge) err_d = 1'b1;
      end
      StFrame, StDrop: begin
        if (!frame) state_d = StIdle;
      end
      default: state_d = StWaitIdle;
    endcase

    if ((state_q == StFrame) || ((state_q == StIdle) && frame)) begin
      if (pending_q) begin
        if (delay_q == '0) begin
          sample    = 1'b1;
          pending_d = 1'b0;
        end else begin
          delay_d = delay_q - 1'b1;
        end
      end

      if (strobe_edge) begin
        // A new edge while still waiting to sample is a timing violation.
        // Even a coincident sample/edge is ambiguous: both refer to the same HD.
        if (!frame || pending_q) begin
          err_d = 1'b1;
        end else if (SampleDelay == 0) begin
          sample = 1'b1;
        end else begin
          pending_d = 1'b1;
          delay_d   = DelayWidth'(SampleDelay - 1);
        end
      end

      if (sample) begin
        half_d = !half_q;
        if (half_q) begin
          data_d  = {hd_sync_q[SyncStages-1], nibble_q};
          valid_d = 1'b1;
          sof_d   = first_q;
          first_d = 1'b0;
        end else begin
          nibble_d = hd_sync_q[SyncStages-1];
        end
      end

      if (!frame) begin
        // Allow a pending final sample on the falling-frame clock, but never
        // carry an incomplete byte or delayed sample into the next packet.
        if (half_d || pending_d) err_d = 1'b1;
        half_d    = 1'b0;
        pending_d = 1'b0;
        first_d   = 1'b1;
      end

      if (err_d) begin
        state_d   = frame ? StDrop : StIdle;
        data_d    = data_o;
        valid_d   = 1'b0;
        sof_d     = 1'b0;
        half_d    = 1'b0;
        pending_d = 1'b0;
        first_d   = 1'b1;
      end
    end

    if (!en_i) begin
      state_d   = StWaitIdle;
      data_d    = data_o;
      half_d    = 1'b0;
      pending_d = 1'b0;
      first_d   = 1'b1;
      valid_d   = 1'b0;
      sof_d     = 1'b0;
      err_d     = 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q   <= StWaitIdle;
      nibble_q  <= '0;
      half_q    <= 1'b0;
      first_q   <= 1'b1;
      pending_q <= 1'b0;
      delay_q   <= '0;
      data_o    <= '0;
      valid_o   <= 1'b0;
      sof_o     <= 1'b0;
      err_o     <= 1'b0;
      chold_o   <= 1'b1;
    end else begin
      state_q   <= state_d;
      nibble_q  <= nibble_d;
      half_q    <= half_d;
      first_q   <= first_d;
      pending_q <= pending_d;
      delay_q   <= delay_d;
      data_o    <= data_d;
      valid_o   <= valid_d;
      sof_o     <= sof_d;
      err_o     <= err_d;
      // Advisory backpressure: in-flight data is accepted even while held.
      chold_o <= !en_i || hold_i || (state_q == StWaitIdle);
    end
  end

  if (SyncStages < 2) begin : gen_invalid_sync_stages
    $fatal(1, "SyncStages must be at least 2");
  end

endmodule : strobe_rx
