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
RTL_FLIST = sources_rtl.f
BUILD_DIR = obj_dir

$(FLIST): ../../Bender.yml ../../Bender.lock
	bender script flist-plus -t strobe_test > $@

$(RTL_FLIST): ../../Bender.yml ../../Bender.lock
	bender script flist -t strobe_test -t synthesis > $@

.PHONY: regression
regression: $(FLIST) $(RTL_FLIST)
	verilator --binary --timing --no-sched-zero-delay --assert --build -j 0 --Wall \
		--top-module strobe_tb \
		--timescale 1ns/1ps --Mdir $(BUILD_DIR) -f $(FLIST) -o strobe_tb
	./$(BUILD_DIR)/strobe_tb
	sh check_strobe_parameters.sh $(abspath $(FLIST))
	sh check_pad_flops.sh $(abspath $(RTL_FLIST))

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) $(FLIST) $(RTL_FLIST)
