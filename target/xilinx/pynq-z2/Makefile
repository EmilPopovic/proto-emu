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

REPO_ROOT := $(abspath ../../..)
BUILD     ?= build
PART      ?= xc7z020clg400-1
BOARD     ?= tul.com.tw:pynq-z2:part0:1.0
TOP       ?= fpga_top
VIVADO    ?= vivado

BIT   := $(BUILD)/$(TOP).bit
FLIST := sources.f

VIV_ENV = OUTDIR=$(CURDIR)/$(BUILD) FLIST=$(CURDIR)/$(FLIST) PART=$(PART) BOARD=$(BOARD) TOP=$(TOP)

.PHONY: all
all: bitstream

$(FLIST): $(REPO_ROOT)/Bender.yml $(REPO_ROOT)/Bender.lock $(wildcard src/*.v)
	bender script flist-plus -t rtl -t synthesis -t fpga -t xilinx > $@
	echo "$(CURDIR)/src/tc_sram.sv" >> $@
	echo "$(CURDIR)/src/$(TOP).sv" >> $@

$(BUILD):
	mkdir -p $@

DEPS := $(FLIST) $(wildcard src/*.sv src/*.v) constraints/$(TOP).xdc

.PHONY: synth impl bitstream
synth impl bitstream: $(DEPS) | $(BUILD)
	$(VIV_ENV) STAGE=$@ $(VIVADO) -mode batch -notrace -nojournal \
		-log $(BUILD)/vivado_$@.log -source vivado/build.tcl

.PHONY: program
program:
	scripts/program.sh $(BIT)

.PHONY: clean
clean:
	rm -rf $(BUILD) $(FLIST) .Xil clockInfo.txt tight_setup_hold_pins.txt
