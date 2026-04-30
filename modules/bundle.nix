# modules/bundle.nix
{ config, lib, pkgs, ... }:

let
  # Check if we should enable telegram features
  # You can also check for file existence
  enableTelegram = builtins.pathExists ./telegram-enabled;
in
{
  imports = lib.optionals enableTelegram [
    ./sops.nix
    ./rex.nix
  ];

  config = lib.mkIf enableTelegram {
    services.rex = {
      enable = true;
      projectDir = "/home/mg/gh/td";
      environmentFile = config.sops.secrets."td/rex-env".path;
      user = "mg";
      restartSec = 2;
    };
  };
}