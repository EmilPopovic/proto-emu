# Copyright 2026 Emil Popovic, Matej Jurasic
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at
#
#     https://solderpad.org/licenses/SHL-2.1/
#
# Unless required by applicable law or agreed to in writing, any work
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Emil Popovic <mail@emilpopovic.me>

# Usage: sh check_uart_parameters.sh <Bender UART source list>
set -eu

flist=$1
verilator_bin=${VERILATOR:-verilator}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

expect_rejection() {
  module=$1
  diagnostic=$2
  shift 2
  if "$verilator_bin" --lint-only --timing --no-sched-zero-delay --timescale 1ns/1ps \
      --top-module "$module" -f "$flist" "$@" > "$work_dir/elaboration.log" 2>&1; then
    echo "FAIL: $module accepted invalid parameters: $*" >&2
    exit 1
  fi
  if ! grep -F "$diagnostic" "$work_dir/elaboration.log" > /dev/null; then
    cat "$work_dir/elaboration.log" >&2
    echo "FAIL: $module failed without the expected diagnostic: $diagnostic" >&2
    exit 1
  fi
}

for module in uart_rx uart_tx; do
  expect_rejection "$module" 'Baud must be positive' -GBaud=0
  expect_rejection "$module" 'requires at least 8 clocks per bit' -GFClk=7000000 -GBaud=1000000
done
expect_rejection uart_rx 'FilterCycles must be positive' -GFilterCycles=0
expect_rejection uart_rx 'less than half a bit period' \
    -GFClk=8000000 -GBaud=1000000 -GFilterCycles=4

echo 'PASS: UART parameter checks (6 invalid configurations rejected)'
