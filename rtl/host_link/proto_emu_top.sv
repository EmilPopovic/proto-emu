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

module proto_emu_top #(
  parameter int unsigned NumPins = 8,

  // UART fallback PHY timing. FClk must match the frequency of clk_i.
  parameter int unsigned UartBaud = 115200,
  parameter int unsigned UartFClk = 48_000_000
) (
  input  logic clk_i,
  input  logic rst_ni,

  // Host link PHY select: high selects the strobe PHY, low the UART fallback
  input  logic phy_sel_i,

  // Host link - strobe pads
  input  logic [3:0] hd_i,
  input  logic       hstrb_i,
  input  logic       hfrm_i,
  output logic       chold_o,
  output logic [3:0] cd_o,
  output logic       cstb_o,
  output logic       cfrm_o,
  input  logic       hhold_i,

  // Host link - UART pads
  input  logic uart_rx_i,
  output logic uart_tx_o,

  // Protocol emulation pins
  output logic [NumPins-1:0] proto_o,
  input  logic [NumPins-1:0] proto_i,
  output logic [NumPins-1:0] proto_oe_o

);

  logic strobe_en, uart_en;

  // Byte stream towards the packet layer, after PHY select
  logic [7:0] rx_data;
  logic       rx_valid;
  logic       rx_hold;

  // Byte stream from the packet layer, before PHY select
  logic [7:0] tx_data;
  logic       tx_valid;
  logic       tx_last;
  logic       tx_ready;

  logic [7:0] strobe_rx_data, uart_rx_data;
  logic       strobe_rx_valid, uart_rx_valid;
  logic       strobe_tx_ready, uart_tx_ready;

  /////////////////////////////
  // Host link - Strobe PHYs //
  /////////////////////////////

  strobe_rx i_strobe_rx (
    .clk_i,
    .rst_ni,
    .en_i   (strobe_en),
    .hd_i,
    .hstrb_i,
    .hfrm_i,
    .chold_o,
    .data_o (strobe_rx_data),
    .valid_o(strobe_rx_valid),
    .sof_o  (),  // TODO: packet layer
    .hold_i (rx_hold),
    .err_o  ()   // TODO: packet layer
  );

  strobe_tx i_strobe_tx (
    .clk_i,
    .rst_ni,
    .en_i   (strobe_en),
    .data_i (tx_data),
    .valid_i(tx_valid && strobe_en),
    .last_i (tx_last),
    .ready_o(strobe_tx_ready),
    .cd_o,
    .cstb_o,
    .cfrm_o,
    .hhold_i,
    .hold_o (),  // TODO: packet layer
    .busy_o ()   // TODO: packet layer
  );

  ///////////////////////////
  // Host link - UART PHYs //
  ///////////////////////////

  uart_rx #(
    .Baud(UartBaud),
    .FClk(UartFClk)
  ) i_uart_rx (
    .clk_i,
    .rst_ni,
    .en_i   (uart_en),
    .rx_i   (uart_rx_i),
    .data_o (uart_rx_data),
    .valid_o(uart_rx_valid),
    .sof_o  (),  // Tied low by uart_rx; framing is the packet layer's job
    .hold_i (rx_hold),
    .err_o  ()   // TODO: packet layer
  );

  uart_tx #(
    .Baud(UartBaud),
    .FClk(UartFClk)
  ) i_uart_tx (
    .clk_i,
    .rst_ni,
    .en_i   (uart_en),
    .data_i (tx_data),
    .valid_i(tx_valid && uart_en),
    .last_i (tx_last),
    .ready_o(uart_tx_ready),
    .tx_o   (uart_tx_o),
    .hold_o (),  // Tied low by uart_tx; UART has no remote flow control
    .busy_o ()   // TODO: packet layer
  );

  ////////////////////////////
  // Host link - PHY select //
  ////////////////////////////

  // Exactly one PHY is enabled at a time. The deselected PHY holds its pads,
  // so both sets of pads may share package pins where the pad count is tight.
  assign strobe_en = phy_sel_i;
  assign uart_en   = ~phy_sel_i;

  assign rx_data  = phy_sel_i ? strobe_rx_data  : uart_rx_data;
  assign rx_valid = phy_sel_i ? strobe_rx_valid : uart_rx_valid;
  assign tx_ready = phy_sel_i ? strobe_tx_ready : uart_tx_ready;

  ////////////////////////////////
  // Packet layer - placeholder //
  ////////////////////////////////

  // TODO: every received byte is echoed back to the host as a single-byte
  // packet. The packet layer and the bridge onto the subordinate OBI port of
  // proto_emu replace this.
  assign tx_data  = rx_data;
  assign tx_valid = rx_valid;
  assign tx_last  = 1'b1;
  assign rx_hold  = ~tx_ready;

  //////////////////////////
  // Portable IP instance //
  //////////////////////////

  proto_emu #(
    .NumPins(NumPins)
  ) i_proto_emu (
    .clk_i,
    .rst_ni,
    // TODO: driven by the host link packet layer
    .s_obi_req_i('0),
    .s_obi_rsp_o(),
    // TODO: connected to the SoC interconnect
    .m_obi_req_o(),
    .m_obi_rsp_i('0),
    .proto_o,
    .proto_i,
    .proto_oe_o
  );

endmodule : proto_emu_top
