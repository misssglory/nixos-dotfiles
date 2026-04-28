{ config, lib, pkgs, ... }:

let
  cfg = config.services.rex;
in
{
  options.services.rex = {
    enable = lib.mkEnableOption "rex listener";

    projectDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/mg/gh/td";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
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

      path = [
        pkgs.proxychains
        pkgs.bash
        pkgs.coreutils
      ];

      unitConfig = {
        ConditionPathExists = "${cfg.projectDir}/example/cpp/build/td_channel_example/cpp/listener.json";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        WorkingDirectory = cfg.projectDir;

        ExecStart = ''
          ${pkgs.bash}/bin/bash -euo pipefail -c '
            : "''${TD_API_ID:?TD_API_ID is not set}"
            : "''${TD_API_HASH:?TD_API_HASH is not set}"
            exec ${pkgs.proxychains-ng}/bin/proxychains4 \
              ${cfg.projectDir}/example/cpp/build/td_channel_example/cpp/listener.json
          '
        '';

        Restart = "always";
        RestartSec = "${toString cfg.restartSec}s";
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
