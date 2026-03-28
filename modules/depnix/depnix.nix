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
        wrapProgram $out/bin/depnix --prefix PATH : ${pkgs.lib.makeBinPath [ inputs.ssher.packages.x86_64-linux.default pkgs.nixos-anywhere pkgs.nixos-rebuild pkgs.jq pkgs.gum pkgs.age pkgs.git ] }
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

            port = lib.mkOption {
              type = lib.types.port;
              default = 22;
              example = 222;
              description = ''
                The custom port for ssh
              '';
            };

            host = lib.mkOption {
              type = lib.types.str;
              example = "10.0.0.5 | myserver.domain.com";
              description = ''
                The IP address or dns name to ssh to when deploying.
              '';
            };

            hardwareConfigFile = lib.mkOption {
              type = lib.types.str;
              example = "./modules/host/hardware-config.nix";
              description = ''
                The path to where nixos-anywhere will install the hardware-config.nix relative to the git root
                This path is called for deployment
              '';
            };

            sshHostKeyDir = lib.mkOption {
              type = lib.types.str;
              example = "./modules/host";
              description = ''
                The path to where depnix will store the ssh host keys relative to the git root path
                This path is called for generation, re-keying, and deployment
              '';
            };

            id = lib.mkOption {
              type = lib.types.str;
              default = "~/.ssh/id_ed25519";
              example = "~/.ssh/my_custom_id_ed25519";
              description = ''
                The ssh key used to connect to the remote host for deployment.
                This is also used for installation, so ensure that your nixosConfiguration includes this as the authorized key
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
              default = config.depnix.deploy.decryptionKeyFile;
              description = ''
                The private key used to decrypt the ssh_host_keys.
                Can be an SSH key or an AGE key
              '';
            };

            sshOptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              example = [ "StrictHostKeyChecking=no" "jumphost=x.x.x.x" ];
              default = [];
              description = ''
                Pass arbitrary ssh options to nixosAnywhere
              '';
            };

            nixOptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              example = [ "--impure" "--extra-experimental-features ..." ];
              default = [];
              description = ''
                Pass nix options to nix build commands
              '';
            };

            nixosAnywhereOptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              example = [ "--debug" "--show-trace" ];
              default = [];
              description = ''
                Pass other nixos-anywhere options
              '';
            };

            buildOn= lib.mkOption {
              type = lib.types.str;
              example = "remote";
              default = "auto";
              description = ''
                * --build-on auto|remote|local
                  sets the build on settings to auto, remote or local. Default is auto.
                  auto: tries to figure out, if the build is possible on the local host, if not falls back gracefully to remote build
                  local: will build on the local host
                  remote: will build on the remote host
              '';
            };

            passwordPrompt = lib.mkOption {
              type = lib.types.bool;
              example = true;
              default = false;
              description = ''
                Whether we should prompt for --env-password
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
