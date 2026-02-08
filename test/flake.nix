{
  description = "Test configuration for nixos-autoupdate module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-autoupdate.url = "path:..";
  };

  outputs = { self, nixpkgs, nixos-autoupdate }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # Test configuration 1: Local flake
      nixosConfigurations.test-local = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-autoupdate.nixosModules.default
          {
            system.autoupdate = {
              enable = true;
              localFlake = true;
              schedule = "daily";
            };
            
            # Minimal system config for testing
            boot.loader.grub.enable = false;
            fileSystems."/".device = "/dev/sda1";
            system.stateVersion = "23.11";
          }
        ];
      };

      # Test configuration 2: Laptop with all features
      nixosConfigurations.test-laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-autoupdate.nixosModules.default
          {
            system.autoupdate = {
              enable = true;
              localFlake = true;
              onlyOnACPower = true;
              
              wakeup = {
                enable = true;
                wakeupTime = "03:55";
                autoSuspendAfter = true;
              };
              
              notification = {
                enable = true;
                urgency = "normal";
                timeout = 30000;
              };
              
              schedule = "04:00";
            };
            
            # Minimal system config for testing
            boot.loader.grub.enable = false;
            fileSystems."/".device = "/dev/sda1";
            system.stateVersion = "23.11";
          }
        ];
      };

      # Test configuration 3: Git-based (without sops for basic structure test)
      nixosConfigurations.test-git = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-autoupdate.nixosModules.default
          {
            system.autoupdate = {
              enable = true;
              flake = "git+https://github.com/example/repo";
              # No sops configured - just testing structure
              
              notification = {
                enable = true;
              };
              
              schedule = "04:00";
            };
            
            # Minimal system config for testing
            boot.loader.grub.enable = false;
            fileSystems."/".device = "/dev/sda1";
            system.stateVersion = "23.11";
          }
        ];
      };
    };
}
