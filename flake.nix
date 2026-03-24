{
  description = "NixOS";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dwl = {
      url = "github:misssglory/dwl-setup/7d355da52dbca82affe36c8254a249d6695094d5";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, home-manager, dwl, ... }: 
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      # Use wlroots 0.18 explicitly
      wlroots = pkgs.wlroots_0_18;
    in {
      packages.${system}.dwl = pkgs.callPackage ./dwl.nix {
        src = dwl;
        inherit wlroots;
        xorg = pkgs.xorg;
        libxkbcommon = pkgs.libxkbcommon;
        pixman = pkgs.pixman;
      };
      
      nixosConfigurations.nixos-btw = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            environment.systemPackages = [ self.packages.${system}.dwl ];
            
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.mg = import ./home.nix;
              backupFileExtension = "backup";
            };
          }
        ];
      };
    };
}
