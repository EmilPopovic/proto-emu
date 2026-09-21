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

{
  description = "Protocol emulator toolchain";

  nixConfig = {
    extra-substituters = [ "https://nix-cache.fossi-foundation.org" ];
    extra-trusted-public-keys = [
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs="
    ];
  };

  inputs = {
    nix-eda.url = "github:fossi-foundation/nix-eda";
    nixpkgs.follows = "nix-eda/nixpkgs";
    nixpkgs-slang.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

    outputs = { self, nixpkgs, nixpkgs-slang, nix-eda }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nix-eda.overlays.default ];
          };
          sv-lang = nixpkgs-slang.legacyPackages.${system}.sv-lang;
          yosys-full = nix-eda.packages.${system}.yosysFull;
        in {
          default = pkgs.mkShell {
            name = "proto-emu";
            packages = (with pkgs; [
              iverilog
              verilator
              bender
              gtkwave
              haskellPackages.sv2v
            ]) ++ [
              sv-lang
              yosys-full
            ];
          };
        });
    };
}