{
  description = "NixOS Auto-Update Module - Automatic system updates with advanced features";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    {
      nixosModules.default = import ./module.nix;
      
      # Alias for backwards compatibility
      nixosModules.autoupdate = self.nixosModules.default;
    };
}
