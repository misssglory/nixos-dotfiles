{ config, lib, pkgs, ... }:

let
  enableTelegram = builtins.pathExists ./telegram-enabled;
in
{
  imports = [
    ./token-info-server.nix
  ] ++ lib.optionals enableTelegram [
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