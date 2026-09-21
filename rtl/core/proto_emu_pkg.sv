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

package proto_emu_pkg;

  localparam int unsigned AddrWidth = 32;
  localparam int unsigned DataWidth = 32;
  localparam int unsigned BeWidth   = DataWidth / 8;

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [BeWidth-1:0]   be_t;

  /////////////////////
  // OBI definitions //
  /////////////////////

  typedef struct packed {
    addr_t addr;
    logic  we;
    be_t   be;
    data_t wdata;
  } proto_emu_obi_a_chan_t;

  typedef struct packed {
    data_t rdata;
    logic  err;
  } proto_emu_obi_r_chan_t;

  typedef struct packed {
    proto_emu_obi_a_chan_t a;
    logic                  req;
  } proto_emu_obi_req_t;

  typedef struct packed {
    proto_emu_obi_r_chan_t r;
    logic                  gnt;
    logic                  rvalid;
  } proto_emu_obi_rsp_t;

endpackage : proto_emu_pkg
