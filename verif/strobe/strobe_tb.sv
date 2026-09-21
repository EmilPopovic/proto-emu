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

module strobe_tb;
  timeunit 1ns;
  timeprecision 1ps;
  wire [3:0] done;
  strobe_case i_default (
    .done_o(done[0])
  );
  strobe_case #(
    .CyclesPerNibble(2),
    .SetupCycles    (1),
    .FrameGuard     (1),
    .SampleDelay    (0)
  ) i_fast (
    .done_o(done[1])
  );
  strobe_case #(
    .CyclesPerNibble(6),
    .SetupCycles    (2),
    .FrameGuard     (3),
    .SyncStages     (3),
    .SampleDelay    (2)
  ) i_deep (
    .done_o(done[2])
  );
  strobe_case #(
    .CyclesPerNibble(5),
    .SetupCycles    (1),
    .FrameGuard     (1),
    .SampleDelay    (2)
  ) i_odd (
    .done_o(done[3])
  );
  initial begin
    wait (&done);
    $display("PASS: strobe regression");
    $finish;
  end
  initial begin
    #10ms;
    $fatal(1, "Strobe regression timed out");
  end
endmodule : strobe_tb
