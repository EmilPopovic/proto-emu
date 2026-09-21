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
  // Cycles after edge detect before latching HD
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
  input  logic hold_i,  // RX FIFO above threshold
  output logic err_o    // Pulse on error
);

endmodule : strobe_rx
