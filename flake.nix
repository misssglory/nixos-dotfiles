{
  description = "NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dwl = {
      url = "github:misssglory/dwl-setup/5d93ed64d446a38e8be689eb7ab7ecbcd5ffa192";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, dwl, sops-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      unstable = nixpkgs-unstable.legacyPackages.${system};
      wlroots = pkgs.wlroots_0_20;
    in {
      packages.${system} = {
        dwl = pkgs.callPackage ./dwl.nix {
          src = dwl;
          inherit wlroots;
          xorg = pkgs.xorg;
          libxkbcommon = pkgs.libxkbcommon;
          pixman = pkgs.pixman;
        };

        spl-token-cli = pkgs.callPackage ./pkgs/spl-token-cli.nix {};

        # zed-latest = zed.packages.${system}.default;
      };

      homeConfigurations."mg" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        extraSpecialArgs = {
          inherit unstable;
        };

        modules = [
          ./home.nix
          {
            home.username = "mg";
            home.homeDirectory = "/home/mg";
            programs.home-manager.enable = true;
          }
        ];
      };

      nixosConfigurations.nixos-btw = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self sops-nix unstable; };

        modules = [
          ./configuration.nix
          ./modules/postgres.nix
          ./modules/bundle.nix
          home-manager.nixosModules.home-manager
          ./modules/xray.nix
          sops-nix.nixosModules.sops

          {
            environment.systemPackages = with pkgs; [
              self.packages.${system}.dwl
              self.packages.${system}.spl-token-cli
              pkg-config
              openssl
            ];

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.mg = import ./home.nix;
              backupFileExtension = "backup";

              extraSpecialArgs = {
                inherit unstable;
              };
            };
          }
        ];
      };
    };
}
