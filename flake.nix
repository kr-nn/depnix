{
  description = "script to deploy/update nixos machines as well as interact with them";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, agenix, disko, nixpkgs, ... }:

  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
  packages.${system}.default = pkgs.stdenv.mkDerivation {
    pname = "depnix";
    version = "1.0";
    unpackPhase = "true";
    src = ./depnix.sh;
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/depnix
      chmod +x $out/bin/depnix
    '';
    };
  };
}
