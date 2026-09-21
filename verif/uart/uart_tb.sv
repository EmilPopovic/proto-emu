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

module uart_tb;
  timeunit 1ns;
  timeprecision 1ps;
  wire [4:0] done;

  uart_case i_default (.done_o(done[0]));
  uart_case #(.FClk(8_000_000), .Baud(1_000_000)) i_minimum (.done_o(done[1]));
  uart_case #(.FClk(17_000_000), .Baud(1_000_000), .FilterCycles(4))
      i_odd (.done_o(done[2]));
  uart_case #(.FClk(16_000_000), .Baud(1_000_000), .FilterEnable(1'b0), .FilterCycles(0))
      i_bypass (.done_o(done[3]));
  uart_case #(.FClk(16_000_000), .Baud(1_000_000), .FilterCycles(1))
      i_one_sample (.done_o(done[4]));

  initial begin
    wait (&done);
    $display("PASS: UART regression");
    $finish;
  end
  initial begin
    #100ms;
    $fatal(1, "UART regression timed out");
  end
endmodule : uart_tb
