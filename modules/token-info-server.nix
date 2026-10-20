{ config, lib, pkgs, inputs, ... }:

let
  serverPackage =
    inputs.token-info-server.packages.${pkgs.stdenv.hostPlatform.system}.default;

in
{
  systemd.services.token-info-server = {
    description = "Token Info Server";
    wantedBy = [ "multi-user.target" ];

    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "postgresql.service"
    ];

    environment = {
      # HTTP server
      HOST = "127.0.0.1";
      PORT = "9002";

      # Logging
      RUST_LOG = "info";
      RUST_BACKTRACE = "1";
      LOG_LEVEL = "info";

      # RPC
      SOLANA_RPC = "https://api.mainnet-beta.solana.com";
      ETHEREUM_RPC = "https://ethereum-rpc.publicnode.com";
      BSC_RPC = "https://bsc-rpc.publicnode.com";

      # PostgreSQL cache
      DB_HOST = "127.0.0.1";
      DB_PORT = "5432";
      DB_NAME = "token_cache";
      DB_USER = "postgres";
      DB_MAX_CONNECTIONS = "10";
      CACHE_TTL_SECONDS = "86400";

      # TCP forwarder
      TCP_ENDPOINT_ENABLED = "true";
      TCP_ENDPOINT_HOST = "127.0.0.1";
      TCP_ENDPOINT_PORT = "1266";
      TCP_FORWARD_TOKENS = "true";
    };

    # Unlimited restart attempts, including repeated failures.
    unitConfig = {
      StartLimitIntervalSec = 0;
    };

    serviceConfig = {
      Type = "simple";

      User = "mg";
      Group = "users";

      # AppConfig::from_env() is used if the config
      # file cannot be parsed. /dev/null is empty,
      # intentionally selecting the environment mode.
      ExecStart = ''
        ${lib.getExe serverPackage} --config /dev/null
      '';

      Restart = "always";
      RestartSec = "2s";

      # A private writable working directory.
      StateDirectory = "token-info-server";
      WorkingDirectory = "/var/lib/token-info-server";

      # Optional secrets.
      # The leading "-" means systemd can start without it.
      EnvironmentFile = "-/etc/token-info-server.env";

      NoNewPrivileges = true;
      PrivateTmp = true;

      TimeoutStopSec = "15s";
    };
  };
}
