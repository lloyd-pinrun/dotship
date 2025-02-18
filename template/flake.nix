{
  inputs.canivete.url = github:schradert/canivete;
  # Argumenmts are:
  # 1. flake-parts module args
  # 2. directories where every .nix file recursively is a flake-parts module
  # 3. root flake-parts module
  outputs = inputs: inputs.canivete.lib.mkFlake {inherit inputs;} [] {};
}
