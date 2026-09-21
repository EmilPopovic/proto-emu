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

module strobe_tx #(
  parameter int unsigned CyclesPerNibble = 4,
  parameter int unsigned SetupCycles     = 2,
  parameter int unsigned FrameGuard      = 4,
  parameter int unsigned SyncStages      = 2
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic en_i,

  // Byte stream from PHY select
  input  logic [7:0] data_i,   // Low nibble first
  input  logic       valid_i,
  input  logic       last_i,   // Final byte of the packet
  output logic       ready_o,  // Held low at packet boundaries while HHOLD is set

  // Pads, driven directly by output flops
  output logic [3:0] cd_o,
  output logic       cstb_o,
  output logic       cfrm_o,
  input  logic       hhold_i,  // Asynchronous

  // Status
  output logic hold_o,
  output logic busy_o
);

  localparam int unsigned HoldCycles = (CyclesPerNibble > SetupCycles) ?
                                       CyclesPerNibble - SetupCycles : 1;
  localparam int unsigned MaxCycles  = (CyclesPerNibble > FrameGuard) ?
                                       CyclesPerNibble : FrameGuard;
  localparam int unsigned TimerWidth = (MaxCycles > 1) ? $clog2(MaxCycles) : 1;

  typedef enum logic [2:0] {
    StIdle, StSetup, StHold, StWaitData, StGuard
  } state_e;

  (* async_reg = "true" *) logic [SyncStages-1:0] hhold_sync_q;
  logic [TimerWidth-1:0] timer_q;
  logic [3:0] high_nibble_q;
  logic high_q, last_q;
  state_e state_q;

  // Conservative reset: do not start a packet until HHOLD has synchronized.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      hhold_sync_q <= '1;
    end else begin
      hhold_sync_q[0] <= hhold_i;
      for (int unsigned i = 1; i < SyncStages; i++) begin
        hhold_sync_q[i] <= hhold_sync_q[i-1];
      end
    end
  end

  assign hold_o  = hhold_sync_q[SyncStages-1];
  assign busy_o  = (state_q != StIdle);
  assign ready_o = en_i && (
      (((state_q == StIdle) || ((state_q == StGuard) && (timer_q == '0))) && !hold_o) ||
      (state_q == StWaitData) ||
      ((state_q == StHold) && high_q && !last_q && (timer_q == '0)));

  // Each nibble gets SetupCycles before its toggle and HoldCycles afterwards.
  // The next byte can be accepted on the same edge that the old byte finishes;
  // no byte-boundary bubble is inserted. HHOLD only gates packet admission.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= StIdle;
      timer_q <= '0;
      high_nibble_q <= '0;
      high_q <= 1'b0;
      last_q <= 1'b0;
      cd_o   <= '0;
      cstb_o <= 1'b0;
      cfrm_o <= 1'b0;
    end else if (!en_i) begin
      state_q <= StIdle;
      timer_q <= '0;
      high_nibble_q <= '0;
      high_q <= 1'b0;
      last_q <= 1'b0;
      cfrm_o <= 1'b0;
      // Retain data and strobe on abort, avoiding a spurious transfer edge.
    end else if (valid_i && ready_o) begin
      cd_o <= data_i[3:0];
      high_nibble_q <= data_i[7:4];
      last_q <= last_i;
      high_q <= 1'b0;
      cfrm_o <= 1'b1;
      timer_q <= TimerWidth'(SetupCycles - 1);
      state_q <= StSetup;
    end else begin
      case (state_q)
        StIdle, StWaitData: ;
        StSetup: begin
          if (timer_q == '0) begin
            cstb_o <= ~cstb_o;
            timer_q <= TimerWidth'(HoldCycles - 1);
            state_q <= StHold;
          end else begin
            timer_q <= timer_q - 1'b1;
          end
        end
        StHold: begin
          if (timer_q != '0) begin
            timer_q <= timer_q - 1'b1;
          end else if (!high_q) begin
            cd_o    <= high_nibble_q;
            high_q  <= 1'b1;
            timer_q <= TimerWidth'(SetupCycles - 1);
            state_q <= StSetup;
          end else if (last_q) begin
            cfrm_o  <= 1'b0;
            timer_q <= TimerWidth'(FrameGuard - 1);
            state_q <= StGuard;
          end else begin
            state_q <= StWaitData;
          end
        end
        StGuard: begin
          if (timer_q == '0) state_q <= StIdle;
          else timer_q <= timer_q - 1'b1;
        end
        default: begin
          state_q <= StIdle;
          cfrm_o <= 1'b0;
        end
      endcase
    end
  end

  if (SyncStages < 2) begin : gen_invalid_sync_stages
    $fatal(1, "SyncStages must be at least 2");
  end
  if ((SetupCycles == 0) || (SetupCycles >= CyclesPerNibble)) begin : gen_invalid_timing
    $fatal(1, "SetupCycles must be positive and less than CyclesPerNibble");
  end
  if (FrameGuard == 0) begin : gen_invalid_frame_guard
    $fatal(1, "FrameGuard must be positive");
  end

endmodule : strobe_tx
