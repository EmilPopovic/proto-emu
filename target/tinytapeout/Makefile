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

.DEFAULT_GOAL := verilog
.DELETE_ON_ERROR:

REPO_ROOT := $(abspath ../..)
BUILD     ?= build
TOP       ?= tt_um_proto_emu

SV2V  ?= sv2v
YOSYS ?= yosys

FLIST   := sources.f
VERILOG := $(BUILD)/$(TOP).v

################
# Source lists #
################

# sv2v takes bare source paths, so use the plain flist rather than flist-plus.
$(FLIST): $(REPO_ROOT)/Bender.yml $(REPO_ROOT)/Bender.lock $(wildcard src/*.sv)
	bender script flist -t rtl -t synthesis -t tinytapeout > $@
	echo "$(CURDIR)/src/$(TOP).sv" >> $@

.PHONY: sources
sources: $(FLIST)

##############
# Generation #
##############

$(BUILD):
	mkdir -p $@

# One self-contained Verilog-2005 file, to be committed to the Tiny Tapeout
# project repository and listed in its info.yaml source_files.
$(VERILOG): $(FLIST) $(wildcard src/*.sv) | $(BUILD)
	$(SV2V) -DASSERTS_OFF --top=$(TOP) $$(cat $(FLIST)) > $@

.PHONY: verilog
verilog: $(VERILOG)

#########
# Check #
#########

# The generated file must elaborate and synthesize on its own, with no
# SystemVerilog left behind. stat reports the cell count for the area budget.
.PHONY: check
check: $(VERILOG)
	$(YOSYS) -Q -T -p 'read_verilog $(VERILOG); hierarchy -check -top $(TOP); synth -top $(TOP); stat'

.PHONY: clean
clean:
	rm -rf $(BUILD) $(FLIST)
