# flake.nix
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
    ocr-text = {
      url = "github:misssglory/ocr-test";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    token-info-server = {
      url = "github:misssglory/token-info-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local path while developing, or GitHub after you push:
    chatgpt-ctl = {
      url = "path:/home/mg/gh/chatgpt-history-watcher";
      # url = "github:misssglory/chatgpt-ctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wcc = {
      url = "github:misssglory/wcc";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
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
      chatgpt-ctl,
      wcc,
      hermes-agent,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      unstable = nixpkgs-unstable.legacyPackages.${system};
    in
    {
      packages.${system} = {
        spl-token-cli = pkgs.callPackage ./pkgs/spl-token-cli.nix { };
      };

      homeConfigurations."mg" =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit unstable ocr-text chatgpt-ctl wcc hermes-agent;
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

      nixosConfigurations.nixos-btw =
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              self
              sops-nix
              unstable
              ocr-text
              token-info-server
              chatgpt-ctl
              hermes-agent
              inputs
              ;
          };
          modules = [
            ./configuration.nix
            ./modules/postgres.nix
            ./modules/bundle.nix
            home-manager.nixosModules.home-manager
            ./modules/xray.nix
            ocr-text.nixosModules.default
            ./modules/ocr-text.nix
            sops-nix.nixosModules.sops
            hermes-agent.nixosModules.default

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
                  inherit unstable ocr-text chatgpt-ctl wcc hermes-agent;
                };
              };
            }
          ];
        };
    };
}
