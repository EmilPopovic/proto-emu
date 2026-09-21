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

sources.f: Bender.yml Bender.lock
	rm sources.f || true
	bender script flist-plus -t rtl -t synthesis > $@

###########
# Linting #
###########

SLANG_SUPPRESS := .bender/...

SLANG_LINT_FLAGS := --top proto_emu_top --timescale 1ns/1ps \
                    -Wno-duplicate-definition \
                    -Wno-case-redundant-default \
                    --suppress-warnings $(SLANG_SUPPRESS) \
                    -Weverything -Werror

VERILATOR_LINT_FLAGS := --lint-only --top-module proto_emu +define+ASSERTS_OFF

.PHONY: lint
lint: lint-slang lint-verilator

.PHONY: lint-slang
lint-slang: sources.f
	slang -f sources.f $(SLANG_LINT_FLAGS)

.PHONY: lint-verilator
lint-verilator: sources.f
	verilator $(VERILATOR_LINT_FLAGS) verilator_lint.vlt -f sources.f

.PHONY: regression
regression: regression-uart regression-strobe regression-tinytapeout lint

.PHONY: regression-uart
regression-uart:
	$(MAKE) -C verif/uart regression

.PHONY: regression-strobe
regression-strobe:
	$(MAKE) -C verif/strobe regression

.PHONY: regression-tinytapeout
regression-tinytapeout:
	$(MAKE) -C target/tinytapeout check
