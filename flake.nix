
{
  description = "NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #
    # Public GitHub OCR repository.
    #
    ocr-text = {
      url = "github:misssglory/ocr-test";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #
    # Token Info Server from GitHub.
    #
    token-info-server = {
      url = "github:misssglory/token-info-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      sops-nix,
      ocr-text,
      token-info-server,
      ...
    }:

    let
      system = "x86_64-linux";

      pkgs = nixpkgs.legacyPackages.${system};

      unstable = nixpkgs-unstable.legacyPackages.${system};

      wlroots = pkgs.wlroots_0_20;
    in
    {
      #
      # Local packages.
      #
      packages.${system} = {
        spl-token-cli =
          pkgs.callPackage ./pkgs/spl-token-cli.nix {};

        # zed-latest =
        #   zed.packages.${system}.default;
      };

      #
      # Standalone Home Manager configuration.
      #
      homeConfigurations."mg" =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit
              unstable
              ocr-text
              ;
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

      #
      # Main NixOS host.
      #
      nixosConfigurations.nixos-btw =
        nixpkgs.lib.nixosSystem {
          inherit system;

          #
          # Arguments available to imported NixOS modules.
          #
          specialArgs = {
            inherit
              self
              sops-nix
              unstable
              ocr-text
              token-info-server
              inputs
              ;
          };

          modules = [
            ./configuration.nix

            ./modules/postgres.nix

            #
            # Imports rex.nix, sops.nix and
            # token-info-server.nix as configured.
            #
            ./modules/bundle.nix

            home-manager.nixosModules.home-manager

            ./modules/xray.nix

            #
            # OCR module from GitHub.
            #
            ocr-text.nixosModules.default

            #
            # Local OCR settings.
            #
            ./modules/ocr-text.nix

            #
            # SOPS module.
            #
            sops-nix.nixosModules.sops

            {
              environment.systemPackages =
                with pkgs;
                [
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
                  inherit
                    unstable
                    ocr-text
                    ;
                };
              };
            }
          ];
        };
    };
}
