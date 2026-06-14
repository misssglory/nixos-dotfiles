# modules/rex.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.rex;
  
  binaryPath = "${cfg.projectDir}/example/cpp/build/td_all_channels_listener";
  configPath = "${cfg.projectDir}/example/cpp/listener.json";

  rexWrapper = pkgs.writeShellScript "rex-wrapper" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    : "''${TD_API_ID:?TD_API_ID is not set}"
    : "''${TD_API_HASH:?TD_API_HASH is not set}"

    exec \
    # ${pkgs.proxychains}/bin/proxychains4 \
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

    # enableRsyslog = lib.mkOption {
    #   type = lib.types.bool;
    #   default = true;
    #   description = "Enable rsyslog for rex service logs with LZ4 compression.";
    # };
  };

  config = lib.mkIf cfg.enable {
    # 1. Enable rsyslog service
    # services.rsyslogd = lib.mkIf cfg.enableRsyslog {
    #   enable = true;
    #   extraConfig = ''
    #     # Create a dedicated log file for rex service
    #     local0.*    -/var/log/rex/rex.log
        
    #     $FileOwner ${cfg.user}
    #     $FileGroup ${cfg.user}
    #     $FileCreateMode 0640
    #   '';
    # };

    # 2. Install lz4
    # environment.systemPackages = lib.mkIf cfg.enableRsyslog [
    #   pkgs.lz4
    # ];

    # services.logrotate = lib.mkIf cfg.enableRsyslog {
    #   enable = true;
    #   settings = {
    #     rex = {
    #       files = "/var/log/rex/rex.log";
    #       frequency = "daily";
    #       rotate = 4;
    #       size = "100M";
    #       compress = true;
    #       delaycompress = true;
    #       missingok = true;
    #       notifempty = true;
    #       create = "0640 ${cfg.user} ${cfg.user}";
    #       sharedscripts = true;
    #       postrotate = "systemctl kill -s HUP rsyslogd.service >/dev/null 2>&1 || true";
    #     };
    #   };
    # };

    # 4. Configure systemd service to log to rsyslog
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

        # Send stdout/stderr to syslog
        StandardOutput = "syslog";
        StandardError = "syslog";
        SyslogIdentifier = "rex";
        SyslogFacility = "local0";
        
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };

    # 5. Create log directory with proper permissions
    # systemd.tmpfiles.rules = lib.mkIf cfg.enableRsyslog [
    #   "d /var/log/rex 0750 ${cfg.user} ${cfg.user} -"
    # ];
  };
}
