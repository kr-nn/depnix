{ inputs, ... }:{

  flake.nixosConfigurations.test-system = inputs.nixpkgs.lib.nixosSystem {
    modules = [ inputs.agenix.nixosModules.default inputs.self.nixosModules.test-system inputs.self.nixosModules.depnix ];
  };

  flake.nixosModules.test-system = { config, lib, pkgs, modulesPath, ... }: {

    depnix.deploy = {
      user = "root";
      host = "10.0.10.140";
      secret = "~/.ssh/id_ed25519";
      keydir = ./sshkeys;
    };

    depnix.rebuild = {
      user = "kyle";
      host = "10.0.10.140";
      secret = "~/.ssh/id_ed25519";
    };

    depnix.ssh = {
      user = "kyle";
      host = "10.0.10.140";
      id = "~/.ssh/id_ed25519";
    };

    system.stateVersion = "25.05";

    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Networking
    networking.hostName = "test-system";
    networking.networkmanager = { enable = true; };

    # time/language
    time.timeZone = "America/Toronto";
    i18n.defaultLocale = "en_CA.UTF-8";

    # useful
    security.sudo.execWheelOnly = true;

    # user
    users.groups.kyle = { };
    users.users.kyle = {
      isNormalUser = true;
      group = "kyle";
      description = "kyle";
      initialPassword = "testpassword";

      extraGroups = [ "networkmanager" "wheel" ];
    };

    # boot
    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.configurationLimit = 10;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages;
    security.rtkit.enable = true;

    # Hardware ===================================================================================================
    imports =
      [ (modulesPath + "/profiles/qemu-guest.nix")
      ];

    boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ ];
    boot.extraModulePackages = [ ];

    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    networking.useDHCP = lib.mkDefault true;
    # networking.interfaces.ens18.useDHCP = lib.mkDefault true;

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  };

  flake.diskoConfigurations.test-system.disko.devices = {
    disk.main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            size = "1G";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
          swap = {
            size = "4G";
            content = {
              type = "swap";
              discardPolicy = "both";
            };
          };
        };
      };
    };
  };

}
