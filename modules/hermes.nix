# modules/hermes.nix
{ config, ... }:

{
  services.hermes-agent = {
    enable = true;

    addToSystemPackages = false;

    # settings.model.default = "openrouter/auto";

    # environmentFiles = [
    #   config.sops.secrets."hermes/env".path
    # ];

    # Native NixOS execution.
    container.enable = false;
  };
}
