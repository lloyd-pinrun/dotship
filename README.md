# Canivete

Nix framework for common development and infrastructure tooling like:

1. Managing infrastructure declaratively with OpenTofu through terranix
2. Administering kubernetes clusters with kubenix
3. Deploying Nix profiles (i.e. NixOS, nix-darwin, home-manager, etc.)
4. Package derivations with dream2nix
5. Container building and running with docker-compose through arion
6. Running packages as services locally using process-compose
7. Running development commands easily with just shorthand
8. Configure git hooks with pre-commit

## Requirements

1. [Nix](https://nixos.org/download/)
2. [Git](https://git-scm.com/), which can be installed easily through Nix

## Usage

1. Start a new project with `nix flake init --template github:schradert/canivete`
2. Open the project shell by entering project directory and running `nix develop`
3. See available commands by running `just`
