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

  flake.nixosModules.depnix = { config, lib, ... }:{
    options.depnix = {
      deploy = lib.mkOption {
        default = {};
        type = lib.types.submodule {
          options = {

            user = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };

            host = lib.mkOption {
              type = lib.types.str;
            };

            secret = lib.mkOption {
              type = lib.types.str;
              default = "~/.ssh/id_ed25519";
            };

            keydir = lib.mkOption {
              type = lib.types.path;
              default = ./hostkeys;
            };

          };
        };
      };

      rebuild = lib.mkOption {
        default = {};
        type = lib.types.submodule {
          options = {

            user = lib.mkOption {
              type = lib.types.str;
            };

            host = lib.mkOption {
              type = lib.types.str;
            };

            secret = lib.mkOption {
              type = lib.types.str;
              default = "~/.ssh/id_ed25519";
            };

          };
        };
      };

      ssh = lib.mkOption {
        default = {};
        type = lib.types.submodule {
          options = {

            user = lib.mkOption {
              type = lib.types.str;
              default = config.depnix.rebuild.user;
            };

            host = lib.mkOption {
              type = lib.types.str;
              default = config.depnix.rebuild.host;
            };

            id = lib.mkOption {
              type = lib.types.str;
              default = "~/.ssh/id_ed25519";
            };

            password = lib.mkOption {
              type = lib.types.str;
              default = "";
            };

          };
        };
      };

      elevated-ssh = lib.mkOption {
        default = {};
        type = lib.types.submodule {
          options = {

            user = lib.mkOption {
              type = lib.types.str;
              default = config.depnix.deploy.user;
            };

            host = lib.mkOption {
              type = lib.types.str;
              default = config.depnix.rebuild.host;
            };

            id = lib.mkOption {
              type = lib.types.str;
              default = "~/.ssh/id_ed25519";
            };

            password = lib.mkOption {
              type = lib.types.str;
              default = "";
            };

          };
        };
      };
    };
  };
}
