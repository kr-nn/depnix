{
  description = "simple script to deploy/update nixos machines as well as interact with them";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, agenix, disko, nixos-anywhere, nixpkgs, ... }:

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
      wrapProgram $out/bin/depnix --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nixos-anywhere pkgs.nixos-rebuild ] }
    '';
    };
  };
}
