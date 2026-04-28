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
      "td/api_id" = { owner = "mg"; group = "users"; mode = "0400"; };
      "td/api_hash" = { owner = "mg"; group = "users"; mode = "0400"; };
    };
  };
}
