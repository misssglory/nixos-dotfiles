# modules/xray.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.xray-client;
in {
  options.services.xray-client = {
    enable = lib.mkEnableOption "Xray client service";
    
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to Xray configuration file";
    };
    
    user = lib.mkOption {
      type = lib.types.str;
      default = "xray";
      description = "User to run Xray as";
    };
    
    group = lib.mkOption {
      type = lib.types.str;
      default = "xray";
      description = "Group to run Xray as";
    };
    
    logLevel = lib.mkOption {
      type = lib.types.enum [ "debug" "info" "warning" "error" "none" ];
      default = "info";
      description = "Xray log level";
    };
    
    useRealityAssets = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use Xray's built-in Reality assets";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create xray user and group
    users.users.xray = {
      isSystemUser = true;
      group = "xray";
      createHome = false;
      home = "/var/empty";
      shell = "${pkgs.shadow}/bin/nologin";
    };
    users.groups.xray = {};
    
    # Add xray to system packages
    environment.systemPackages = with pkgs; [ xray ];
    
    # Create log directory with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/log/xray 0755 ${cfg.user} ${cfg.group} -"
    ];
    
    # Create systemd service
    systemd.services.xray-client = {
      description = "Xray Client Service with Reality Support";
      documentation = [ "https://xtls.github.io/" ];
      after = [ "network.target" "nss-lookup.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "5s";
        
        # Security hardening - less restrictive to allow logging
        NoNewPrivileges = true;
        PrivateTmp = true;
        # Change from "strict" to "full" to allow writing to /var/log
        ProtectSystem = "full";
        ProtectHome = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictRealtime = true;
        
        # Allow writing to /var/log
        ReadWritePaths = [ "/var/log/xray" ];
        
        # Resource limits
        LimitNOFILE = 65536;
        LimitNPROC = 512;
        
        # ExecStart with configuration file
        ExecStart = let
          configArg = if cfg.configFile != null 
            then "-config ${cfg.configFile}"
            else "";
        in "${pkgs.xray}/bin/xray run ${configArg}";
      };
      
      # Environment variables for xray
      environment = {
        # XRAY_LOCATION_ASSET = "${pkgs.xray}/share/xray";
        XRAY_LOCATION_ASSET = "/etc/xray";
        XRAY_LOG_LEVEL = cfg.logLevel;
      } // lib.optionalAttrs cfg.useRealityAssets {
        XRAY_UTLS_FINGERPRINT = "chrome";
      };
    };
  };
}
