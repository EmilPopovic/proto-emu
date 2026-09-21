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

module uart_rx (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic en_i,    // From PHY select, strobe mode active

  // RX pad
  input  logic rx_i,

  // Byte stream to PHY select
  output logic [7:0] data_o,
  output logic       valid_o,
  output logic       sof_o,    // Qualifies valid_o, first byte after HFRM rise

  // Packet layer
  input  logic hold_i,  // RX FIFO above threshold
  output logic err_o    // Pulse on error
);

endmodule : uart_rx
