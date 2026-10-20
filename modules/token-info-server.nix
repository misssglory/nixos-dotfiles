{ config, lib, pkgs, inputs, ... }:

let
  tokenInfoHost = "127.0.0.1";
  tokenInfoPort = 9002;

  tokenInfoAddress =
    "${tokenInfoHost}:${toString tokenInfoPort}";

  serverPackage =
    inputs.token-info-server.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # Available to user sessions and programs
  environment.variables = {
    TOKEN_INFO_SERVER_ADDR = tokenInfoAddress;
  };

  systemd.services.token-info-server = {
    description = "Token Info Server";

    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      HOST = tokenInfoHost;
      PORT = toString tokenInfoPort;

      RUST_LOG = "info";

      # Keep your existing database/RPC settings here.
    };

    serviceConfig = {
      Type = "simple";
      User = "mg";
      Group = "users";

      ExecStart = ''
        ${lib.getExe serverPackage} --config /dev/null
      '';

      Restart = "always";
      RestartSec = "2s";
    };
  };
}