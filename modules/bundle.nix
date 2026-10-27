{ config, lib, ... }:

let
  enableTelegram = builtins.pathExists ./telegram-enabled;
in
{
  imports =
    [
      ./sops.nix
      ./token-info-server.nix
      # ./chatgpt-ctl.nix
      ./hermes.nix
      ./llama-vulkan.nix
    ]
    ++ lib.optionals enableTelegram [
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
