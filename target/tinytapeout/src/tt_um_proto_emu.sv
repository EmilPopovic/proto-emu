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

`default_nettype none

// Tiny Tapeout top level for the IHP 130nm CMOS5L shuttle.
//
//   ui_in[3:0]  strobe HD[3:0]; ui_in[0] doubles as the UART RX pad
//   ui_in[4]    strobe HSTRB
//   ui_in[5]    strobe HFRM
//   ui_in[6]    strobe HHOLD
//   ui_in[7]    host link PHY select, high for strobe, low for UART
//
//   uo_out[3:0] strobe CD[3:0]
//   uo_out[4]   strobe CSTB
//   uo_out[5]   strobe CFRM
//   uo_out[6]   strobe CHOLD
//   uo_out[7]   UART TX
//
//   uio[7:0]    protocol emulation pins
//
// The two host link PHYs are mutually exclusive, so the UART RX pad is shared
// with a strobe data pad. The strobe output pads are not shared: the bundled
// data contract requires them to come straight off their output flops, which
// a pad multiplexer would break.
module tt_um_proto_emu #(
  // Must match clock_hz in the Tiny Tapeout info.yaml
  parameter int unsigned ClkHz    = 50_000_000,
  parameter int unsigned UartBaud = 115200
) (
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // Bidirectional pads, input path
  output wire [7:0] uio_out,  // Bidirectional pads, output path
  output wire [7:0] uio_oe,   // Bidirectional pads, output enable, high drives
  input  wire       ena,      // High while the design is powered
  input  wire       clk,
  input  wire       rst_n
);

  proto_emu_top #(
    .NumPins (8),
    .UartBaud(UartBaud),
    .UartFClk(ClkHz)
  ) i_proto_emu_top (
    .clk_i (clk),
    .rst_ni(rst_n),

    .phy_sel_i(ui_in[7]),

    .hd_i   (ui_in[3:0]),
    .hstrb_i(ui_in[4]),
    .hfrm_i (ui_in[5]),
    .chold_o(uo_out[6]),
    .cd_o   (uo_out[3:0]),
    .cstb_o (uo_out[4]),
    .cfrm_o (uo_out[5]),
    .hhold_i(ui_in[6]),

    .uart_rx_i(ui_in[0]),
    .uart_tx_o(uo_out[7]),

    .proto_o   (uio_out),
    .proto_i   (uio_in),
    .proto_oe_o(uio_oe)
  );

  // ena is always high while the design is powered and carries no information.
  wire _unused = &{ena, 1'b0};

endmodule : tt_um_proto_emu

`default_nettype wire
