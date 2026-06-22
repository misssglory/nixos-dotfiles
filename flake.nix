{
  description = "NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dwl = {
      url = "github:misssglory/dwl-setup/21e5350d7823d5fbeaa8235dd5cc8ca081e8ac08";
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
      wlroots = pkgs.wlroots_0_18;
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
