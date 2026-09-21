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

module proto_emu_top
  import proto_emu_pkg::*;
#(
  parameter int unsigned NumPins = 8
) (
  input  logic clk_i,
  input  logic rst_ni,

  // Protocol emulation pins
  output logic [NumPins-1:0] proto_o,
  input  logic [NumPins-1:0] proto_i,
  output logic [NumPins-1:0] proto_oe_o

);

  /////////////////////////////
  // Host link - Strobe PHYs //
  /////////////////////////////

  strobe_rx i_strobe_rx (
    .clk_i,
    .rst_ni
  );

  strobe_tx i_strobe_tx (
    .clk_i,
    .rst_ni
  );

  ///////////////////////////
  // Host link - UART PHYs //
  ///////////////////////////

  uart_rx i_uart_rx (
    .clk_i,
    .rst_ni
  );

  uart_tx i_uart_tx (
    .clk_i,
    .rst_ni
  );

  ////////////////////////////
  // Host link - PHY select //
  ////////////////////////////

  //////////////////////////
  // Portable IP instance //
  //////////////////////////

  proto_emu #(
    .NumPins(NumPins)
  ) i_proto_emu (
    .clk_i,
    .rst_ni,
    .proto_o,
    .proto_i,
    .proto_oe_o
  );

endmodule : proto_emu_top
