{ config, pkgs, lib, inputs, ... }:

let
  host = "127.0.0.1";
  port = 9002;

  address = "${host}:${toString port}";

  package =
    inputs.token-info-server.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  environment.variables = {
    TOKEN_INFO_SERVER_ADDR = address;
  };

  systemd.services.token-info-server = {
    description = "Token Info Server";

    wantedBy = [
      "multi-user.target"
    ];

    after = [
      "network-online.target"
      "postgresql.service"
      "sops-nix.service"
    ];

    wants = [
      "network-online.target"
    ];

    requires = [
      "postgresql.service"
    ];

    environment = {
      RUST_LOG = "info";

      HOST = host;
      PORT = toString port;

      TOKEN_INFO_SERVER_ADDR = address;

      TCP_ENDPOINT_ENABLED = "false";

      ROBINHOOD_RPC =
        "https://rpc.mainnet.chain.robinhood.com";
    };

    serviceConfig = {
      Type = "simple";

      User = "mg";
      Group = "users";

      WorkingDirectory = "/home/mg";

      ExecStart = ''
        ${lib.getExe package} \
          --config /dev/null \
          --host ${host} \
          --port ${toString port}
      '';

      EnvironmentFile =
        config.sops.secrets."token-info-server/env".path;

      Restart = "always";
      RestartSec = 2;

      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}