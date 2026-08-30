{ config, pkgs, lib, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;

    extensions = with pkgs.postgresql17Packages; [
      # timescaledb
    ];

    ensureDatabases = [ "quotes" "tcp_router" ];

    ensureUsers = [
      {
        name = "quotes";
        ensureDBOwnership = true;
      }
    ];

    settings = {
      # shared_preload_libraries = "timescaledb";
      max_connections = 100;
      shared_buffers = "512MB";
      effective_cache_size = "2GB";
      maintenance_work_mem = "256MB";
      work_mem = "16MB";
      wal_level = "replica";
      max_worker_processes = 16;
      max_parallel_workers = 8;
      max_parallel_workers_per_gather = 4;
    };

    authentication = ''
      local all all trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128 trust
    '';

    initialScript = pkgs.writeText "init-quotes.sql" ''
      CREATE ROLE quotes WITH LOGIN;
      CREATE DATABASE quotes OWNER quotes;
    '';
  };

  systemd.services.postgresql-timescaledb-init = {
    description = "Enable TimescaleDB extension in quotes database";
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
    };

    script = ''
      ${pkgs.postgresql}/bin/psql -d quotes -c 'CREATE EXTENSION IF NOT EXISTS timescaledb;'
    '';
  };
}
