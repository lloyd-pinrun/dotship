# dotship

## Credit

This implementation was forked from: [@schradert's](https://github.com/schradert) [canivete](https://github.com/schradert/dotship)

They have obviously an incredible understanding of Nix & NixOS, and their code provided a great foundation from which I could learn the language and ecosystem.

As per [canivete](https://github.com/schradert/canivete)'s `README`, you can start a new project with:

```bash
nix flake init --template github:schradert/canivete
```

## About

Nix framework for common development and infrastructure tooling like:

1. Managing infrastructure declaratively with OpenTofu through terranix
2. Administering kubernetes clusters with kubenix
3. Deploying Nix profiles (i.e. NixOS, nix-darwin, home-manager, etc.)
4. ~Package derivations with dream2nix~
5. Container building and running with docker-compose through arion
6. Running packages as services locally using process-compose
7. Running development commands easily with just shorthand
8. Configure git hooks with pre-commit

## Requirements

1. [Nix](https://nixos.org/download/)
2. [Git](https://git-scm.com/), which can be installed easily through Nix

## Usage

1. Start a new project with `nix flake init --template github:lloyd-pinrun/dotship`
2. Open the project shell by entering project directory and running `nix develop`
3. See available commands by running `just`

## Notes

This repo supports building and deploy system configurations with `nixos`, `nix-darwin`, and `home-manager`.
Initial installation is slightly trickier, but this is accomplished in the following ways:

- On Linux, we use `nixos-anywhere` to install `nixos` profiles with `disko` partitioning remotely
- On Darwin and Linux without `nixos`, we assume `nix` is already installed

In each case, SSH access is necessary and `nixos-anywhere` requires root access

## Todo

- [ ] Extract `just` modules into its own flake
  - primarily for use in some other flakes that I'm working on
- [ ] Extract `pre-commit` into its own flake\
  - similar to the reasoning for `just`; I'd prefer a transportable `pre-commit` configuration over its inclusion with [canivete](https://github.com/schradert/canivete)
- [ ] Might restructure where the `dotship.lib` is located with `_module.args`
  - It could potentially be located under `config.lib.dotship`
  - Similar to how [nixvim](https://github.com/nix-community/nixvim) & [stylix](https://github.com/danth/stylix) handle their included helper library
- [ ] Potentially integrate [Fly](https://fly.io) as a remote deployment alternative to k8s and OpenTofu
  - I'm more knowledgable of deploying applications with Fly than I am with @schradert's existing modules
  - Another potential alternative that I am more familiar with is ECS
