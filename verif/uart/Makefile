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

.DEFAULT_GOAL := regression
.DELETE_ON_ERROR:

FLIST = sources.f
BUILD_DIR = obj_dir

$(FLIST): ../../Bender.yml ../../Bender.lock
	bender script flist-plus -t uart_test > $@

.PHONY: regression
regression: $(FLIST)
	verilator --binary --timing --no-sched-zero-delay --assert --build -j 2 --Wall \
		--top-module uart_tb \
		--timescale 1ns/1ps --Mdir $(BUILD_DIR) -f $(FLIST) -o uart_tb
	./$(BUILD_DIR)/uart_tb
	sh check_uart_parameters.sh $(abspath $(FLIST))

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) $(FLIST)
