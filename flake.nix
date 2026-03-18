{
  description = "simple script to deploy/update nixos machines as well as interact with them";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    ssher.url = "github:kr-nn/ssher";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, agenix, disko, ssher, nixos-anywhere, nixpkgs, ... }:

  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
  packages.${system}.default = pkgs.stdenv.mkDerivation {
    pname = "depnix";
    version = "1.0";
    unpackPhase = "true";
    buildInputs = [ pkgs.makeWrapper ];
    src = ./depnix.sh;
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/depnix
      chmod +x $out/bin/depnix
      wrapProgram $out/bin/depnix --prefix PATH : ${pkgs.lib.makeBinPath [ ssher.packages.${system}.default pkgs.nixos-anywhere pkgs.nixos-rebuild ] }
    '';
    };
  };
}
