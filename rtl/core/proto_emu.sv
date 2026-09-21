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

module proto_emu
  import proto_emu_pkg::*;
#(
  // Number of pins usable for protocol emulation
  parameter int unsigned NumPins = 8,

  // OBI bus default types, can be overridden by the user
  parameter type obi_req_t = proto_emu_obi_req_t,
  parameter type obi_rsp_t = proto_emu_obi_rsp_t
) (
  input  logic clk_i,
  input  logic rst_ni,

  // Subordinate bus interface
  input  obi_req_t s_obi_req_i,
  output obi_rsp_t s_obi_rsp_o,
  // Manager bus interface
  output obi_req_t m_obi_req_o,
  input  obi_rsp_t m_obi_rsp_i,

  // Protocol emulation pins
  output logic [NumPins-1:0] proto_o,
  input  logic [NumPins-1:0] proto_i,
  output logic [NumPins-1:0] proto_oe_o
);

endmodule : proto_emu
