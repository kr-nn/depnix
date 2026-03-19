{ inputs, ... }:
{
  perSystem = { pkgs, ... }:{
    packages.default = pkgs.stdenv.mkDerivation {
      pname = "depnix";
      version = "1.0";
      unpackPhase = "true";
      buildInputs = [ pkgs.makeWrapper ];
      src = ./depnix;
      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/depnix
        chmod +x $out/bin/depnix
        wrapProgram $out/bin/depnix --prefix PATH : ${pkgs.lib.makeBinPath [ inputs.ssher.packages.x86_64-linux.default pkgs.nixos-anywhere pkgs.nixos-rebuild ] }
      '';
      };
  };
}
