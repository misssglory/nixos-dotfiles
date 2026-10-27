# modules/llama-vulkan.nix
{ pkgs, lib, ... }:

let
  llama = pkgs.llama-cpp-vulkan;

  model = "google/gemma-4-12B-it-qat-q4_0-gguf:Q4_0";
in
{
  hardware.graphics.enable = true;

  environment.systemPackages = [
    llama
    pkgs.vulkan-tools
  ];

  systemd.services.llama-vulkan = {
    description = "Gemma 4 12B Vulkan inference server";

    wantedBy = [ "multi-user.target" ];

    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      LLAMA_CACHE = "/home/mg/.cache/llama.cpp";
    };

    serviceConfig = {
      Type = "simple";

      User = "mg";
      Group = "users";

      SupplementaryGroups = [ "video" "render" ];

      ExecStart = lib.escapeShellArgs [
        "${llama}/bin/llama-server"

        "-hf" model

        "--host" "127.0.0.1"
        "--port" "18080"

        "--ctx-size" "32768"
        "--n-gpu-layers" "99"

        "--alias" "gemma4-12b"
        "--jinja"
      ];

      Restart = "on-failure";
      RestartSec = "3s";
    };
  };
}
