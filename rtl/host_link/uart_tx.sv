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

// Raw UART byte stream: 8 data bits, no parity, one stop bit, LSB first.
module uart_tx #(
  parameter int unsigned Baud = 115200,
  parameter int unsigned FClk = 48_000_000
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic en_i,

  // Byte stream from PHY select
  input  logic [7:0] data_i,   // Latched on valid_i && ready_o
  input  logic       valid_i,
  input  logic       last_i,   // Unused: packet boundaries do not change UART framing
  output logic       ready_o,

  // UART TX pad
  output logic tx_o,

  // Status
  output logic hold_o,  // Always low; UART has no remote flow-control input
  output logic busy_o   // High through the entire stop bit
);

  localparam int unsigned BitCycles  = (Baud > 0) ? (FClk + Baud / 2) / Baud : 0;
  localparam int unsigned TimerWidth = (BitCycles > 1) ? $clog2(BitCycles) : 1;

  logic [TimerWidth-1:0] timer_q;
  logic [9:0] frame_q;
  logic [3:0] bits_left_q;

  // Consume the shared PHY packet marker in the constant-low hold output:
  // UART has neither a packet-boundary signal nor remote flow control.
  assign hold_o = &{1'b0, last_i};
  assign busy_o = en_i && (bits_left_q != '0);
  assign tx_o   = en_i ? frame_q[0] : 1'b1;

  // Accept the next byte as the stop bit finishes, allowing gapless frames.
  assign ready_o = en_i && ((bits_left_q == '0) ||
                           ((bits_left_q == 4'd1) && (timer_q == '0)));

  // The shift register includes start and stop bits. Disabling the PHY aborts
  // any in-flight byte and returns the pad to its idle-high level.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      timer_q <= '0;
      frame_q <= '1;
      bits_left_q <= '0;
    end else if (!en_i) begin
      timer_q <= '0;
      frame_q <= '1;
      bits_left_q <= '0;
    end else if (valid_i && ready_o) begin
      timer_q <= TimerWidth'(BitCycles - 1);
      frame_q <= {1'b1, data_i, 1'b0};
      bits_left_q <= 4'd10;
    end else if (bits_left_q != '0) begin
      if (timer_q == '0) begin
        timer_q <= TimerWidth'(BitCycles - 1);
        frame_q <= {1'b1, frame_q[9:1]};
        bits_left_q <= bits_left_q - 1'b1;
      end else begin
        timer_q <= timer_q - 1'b1;
      end
    end
  end

  if (Baud == 0) begin : gen_invalid_baud
    $fatal(1, "Baud must be positive");
  end else if (BitCycles < 8) begin : gen_invalid_bit_cycles
    $fatal(1, "UART TX requires at least 8 clocks per bit");
  end

endmodule : uart_tx
