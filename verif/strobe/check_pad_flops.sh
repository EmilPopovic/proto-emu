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

# Usage: sh check_pad_flops.sh <Bender RTL-only source list>
set -eu

flist=$1
sv2v_bin=${SV2V:-sv2v}
yosys_bin=${YOSYS:-yosys}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

# Bender's plain flist contains one source path per line. Preserve spaces.
set --
while IFS= read -r source; do
  if [ -n "$source" ]; then set -- "$@" "$source"; fi
done < "$flist"
"$sv2v_bin" "$@" > "$work_dir/strobe.v"

for module in strobe_rx strobe_tx; do
  if [ "$module" = strobe_rx ]; then pads='chold_o'; else pads='cd_o cstb_o cfrm_o'; fi
  cat > "$work_dir/check.ys" <<EOF
read_verilog $work_dir/strobe.v
hierarchy -top $module
proc
opt
check -assert
select -module $module
EOF
  for pad in $pads; do
    # The one-level input cone of each pad may contain only flop cells, and
    # must contain at least one such driver (rather than a constant or input).
    printf 'select -assert-none o:%s %%ci1 t:* %%i t:$adff t:$adffe %%u %%d\n' "$pad" >> "$work_dir/check.ys"
    printf 'select -assert-any o:%s %%ci1 t:$adff t:$adffe %%u %%i\n' "$pad" >> "$work_dir/check.ys"
  done
  if ! "$yosys_bin" -Q -T -s "$work_dir/check.ys" > "$work_dir/synthesis.log" 2>&1; then
    cat "$work_dir/synthesis.log" >&2
    echo "FAIL: $module pad flop check" >&2
    exit 1
  fi
done

echo 'PASS: strobe pads are driven directly by flops'
