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

################
# Source lists #
################

CORE_TOP   = proto_emu_verilator
FLIST_CORE = sources_core.f

$(FLIST_CORE): ../../Bender.yml ../../Bender.lock $(wildcard rtl/*.sv)
	bender script flist-plus -t rtl -t synthesis > $@
	echo "$(CURDIR)/rtl/$(CORE_TOP).sv" >> $@

.PHONY: sources
sources: $(FLIST_CORE)

#################
# Build targets #
#################

CORE_DIR = obj_dir_core

$(CORE_DIR):
	mkdir -p $@

.PHONY: core
core: sources_core.f
	verilator --cc --exe --build -j 0 --top-module $(CORE_TOP) -Wno-fatal --timescale 1ns/1ps \
		+define+ASSERTS_OFF \
		--Mdir $(CORE_DIR) -f $(FLIST_CORE) $(CORE_CPP) -o proto_emu

.PHONY: clean
clean:
	rm -rf $(CORE_DIR) $(FLIST_CORE)

.PHONY: all
all: core
