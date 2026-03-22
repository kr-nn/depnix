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
        wrapProgram $out/bin/depnix --prefix PATH : ${pkgs.lib.makeBinPath [ inputs.ssher.packages.x86_64-linux.default pkgs.nixos-anywhere pkgs.nixos-rebuild pkgs.jq pkgs.gum pkgs.age ] }
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
              example = "john";
              description = ''
                The username to ssh as when deploying.
              '';
            };

            host = lib.mkOption {
              type = lib.types.str;
              example = "10.0.0.5 | myserver.domain.com";
              description = ''
                The IP address or dns name to ssh to when deploying.
              '';
            };

            encryptionKey = lib.mkOption {
              type = lib.types.str;
              example = "ssh-ed25519 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
              default = "";
              description = ''
                The public key used to encrypt the ssh_host_keys.
                Can be an SSH key or an AGE key
              '';
            };
            decryptionKeyFile = lib.mkOption {
              type = lib.types.str;
              example = "~/.ssh/my_custom_id_ed25519";
              default = "~/.ssh/id_ed25519";
              description = ''
                The private key used to decrypt the ssh_host_keys.
                Can be an SSH key or an AGE key
              '';
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
