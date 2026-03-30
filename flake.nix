{
  description = "Minimal deployment/rebuild/management framework built ontop of nixos-anywhere/nixos-rebuild/ssher";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    ssher.url = "github:kr-nn/ssher";
    disko.url = "github:nix-community/disko";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree [
      inputs.disko.flakeModules.default
      #(inputs.import-tree.filterNot (inputs.nixpkgs.lib.hasInfix "hardware-config") ./modules)
      (inputs.import-tree.matchNot ''.*/hardware-config\.nix'' ./modules) # Import everything except hardware configurations
    ]);
}
