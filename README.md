# Programmable Protocol Emulator

This project is a programmable protocol emulator designed for the Jane Street protocol emulator ASIC competition (task in [TASK.md](docs/TASK.md)).

## Setup

The toolchain is provided by Nix and additional tool installations (except Vivado) should not be required. This should work on all Linux distros, including WSL, but was only tested on ubuntu 26.04 LTS and Arch using zsh.

**Prerequisites:**

- **`curl`** to bootstrap the Nix installer
- **`direnv`** for automatic activation, usually `<pkg-manager> install direnv`
- **Vivado 2025.2** for use with Xilinx FPGAs (optional)

Clone and run the setup script:

```sh
git clone https://github.com/EmilPopovic/proto-emu.git
cd proto-emu
./setup.sh
```

`setup.sh` will:

1. Install Nix if it is not present (a one-time step that asks for `sudo`).
2. Generate `flake.lock`.
3. Install and hook up nix-direnv so the environment auto-activates.

**Activating the environment:**

Make sure your shell has the direnv hook (add to your shell rc):

```sh
eval "$(direnv hook zsh)"   # zsh  -> ~/.zshrc
eval "$(direnv hook bash)"  # bash -> ~/.bashrc
```

Then, in the repo root:

```sh
direnv allow
```

The first activation downloads the prebuilt tools (a few minutes). After that, `cd`-ing into the repo puts every tool on your `PATH` automatically.
