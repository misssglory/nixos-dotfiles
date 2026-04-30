{ config, ... }:

{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      keyFile = "/root/.config/sops/age/keys.txt";
      generateKey = true;
    };

    secrets."td/rex-env" = {
      owner = "mg";
      group = "users";
      mode = "0400";
    };
  };

  services.rex = {
    enable = true;
    projectDir = "/home/mg/gh/td";
    environmentFile = config.sops.secrets."td/rex-env".path;
    user = "mg";
    restartSec = 2;
  };
}