{
  description = "NixOS";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dwl = {
      url = "github:misssglory/dwl-setup/e68cd32395202c98678062557875ca0099c66637";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, dwl, sops-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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
        specialArgs = { inherit self; };
        modules = [
          ./configuration.nix
          ./sops.nix
          ./modules/rex.nix
          home-manager.nixosModules.home-manager
          ./modules/xray.nix
          sops-nix.nixosModules.sops
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