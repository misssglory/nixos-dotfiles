# modules/rex.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.rex;
  
  binaryPath = "${cfg.projectDir}/example/cpp/build/td_all_channels_solana_listener";
  configPath = "${cfg.projectDir}/example/cpp/listener.json";

  rexWrapper = pkgs.writeShellScript "rex-wrapper" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    : "''${TD_API_ID:?TD_API_ID is not set}"
    : "''${TD_API_HASH:?TD_API_HASH is not set}"

    exec ${pkgs.proxychains}/bin/proxychains4 \
      "${binaryPath}" "${configPath}"
  '';
in
{
  options.services.rex = {
    enable = lib.mkEnableOption "rex listener";

    projectDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/mg/gh/td";
      description = "Path to the TDLib checkout containing the already-built listener binary.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Env file with TD_API_ID=... and TD_API_HASH=...";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mg";
      description = "User that runs the listener.";
    };

    restartSec = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Restart delay in seconds.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.rex = {
      description = "TDLib rex listener";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      unitConfig.ConditionPathExists = [
        binaryPath
        configPath
      ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        WorkingDirectory = cfg.projectDir;

        ExecStart = rexWrapper;

        Restart = "always";
        RestartSec = toString cfg.restartSec;

        NoNewPrivileges = false;
        PrivateTmp = false;
        ProtectSystem = "off";
        ProtectHome = "no";
        MemoryDenyWriteExecute = false;
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}