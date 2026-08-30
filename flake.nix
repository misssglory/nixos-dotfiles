{
  description = "NixOS";

  inputs = {
    nixpkgs.url =
      "nixpkgs/nixos-26.05";

    nixpkgs-unstable.url =
      "nixpkgs/nixos-unstable";

    home-manager = {
      url =
        "github:nix-community/home-manager/release-26.05";

      inputs.nixpkgs.follows =
        "nixpkgs";
    };

    sops-nix = {
      url =
        "github:Mic92/sops-nix";

      inputs.nixpkgs.follows =
        "nixpkgs";
    };

    #
    # Public GitHub repository.
    #
    ocr-text = {
      url =
        "github:misssglory/ocr-test";

      #
      # Important:
      # build OCR using the same nixpkgs as the host.
      #
      inputs.nixpkgs.follows =
        "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      sops-nix,
      ocr-text,
      ...
    }:

    let
      system =
        "x86_64-linux";

      pkgs =
        nixpkgs.legacyPackages.${system};

      unstable =
        nixpkgs-unstable.legacyPackages.${system};

      wlroots =
        pkgs.wlroots_0_20;
    in
    {
      packages.${system} = {
        spl-token-cli =
          pkgs.callPackage
            ./pkgs/spl-token-cli.nix
            {};

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

              home.homeDirectory =
                "/home/mg";

              programs.home-manager.enable =
                true;
            }
          ];
        };

      #
      # Main NixOS host.
      #
      nixosConfigurations.nixos-btw =
        nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit
              self
              sops-nix
              unstable
              ocr-text
              ;
          };

          modules = [
            ./configuration.nix

            ./modules/postgres.nix

            ./modules/bundle.nix

            home-manager.nixosModules.home-manager

            ./modules/xray.nix

            #
            # Module implementation comes
            # directly from GitHub OCR flake.
            #
            ocr-text.nixosModules.default

            #
            # Local machine-specific settings.
            #
            ./modules/ocr-text.nix

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
                useGlobalPkgs =
                  true;

                useUserPackages =
                  true;

                users.mg =
                  import ./home.nix;

                backupFileExtension =
                  "backup";

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