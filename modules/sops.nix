{ ... }:

{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      keyFile = "/root/.config/sops/age/keys.txt";
      generateKey = true;
    };

    secrets = {
      "td/rex-env" = {
        owner = "mg";
        group = "users";
        mode = "0400";
      };

      "token-info-server/env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };
}