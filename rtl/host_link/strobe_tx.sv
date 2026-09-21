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

  // Pads
  output logic [3:0] cd_o,
  output logic       cstb_o,
  output logic       cfrm_o,
  input  logic       hhold_i,  // Asynchronous

  // Status
  output logic hold_o,
  output logic busy_o
);

endmodule : strobe_tx
