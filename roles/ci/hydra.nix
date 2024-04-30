{
  config,
  lib,
  pkgs,
  site,
  ...
}:
let
  cfg = config.stop.roles.ci.hydra;
in
{
  options.stop.roles.ci.hydra = {
    enable = lib.mkEnableOption "hydra service";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.builderKey.owner = "hydra-queue-runner";

    age.secrets.hydra-pgpass = {
      file = ./hydra-pgpass.age;
      owner = "hydra";
    };

    age.secrets.hydra-pgpass-queue-runner = {
      file = ./hydra-pgpass.age;
      owner = "hydra-queue-runner";
    };

    age.secrets.hydra-pgpass-www = {
      file = ./hydra-pgpass.age;
      owner = "hydra-www";
    };

    nix = {
      # package = pkgs.nixVersions.nix_2_21;
      settings.allowed-uris = [
        "github:"
        "https:"
      ];
    };

    services.hydra = {
      enable = true;

      # package = pkgs.hydra_unstable.override { nix = pkgs.nixVersions.nix_2_21; };

      buildMachinesFiles = [ "/etc/nix/machines" ];
      dbi = "dbi:Pg:dbname=hydra;host=127.0.0.1;port=3125;user=hydra;";
      extraEnv.PGPASSFILE = config.age.secrets.hydra-pgpass.path;
      hydraURL = "https://${site.services.hydra}";
      listenHost = "127.0.0.1";
      notificationSender = "hydra@${site.zone}";
      port = 3124;
      useSubstitutes = true;
    };

    services.consul.services.hydra = {
      hostnames = [ site.services.hydra ];

      address = config.stop.roles.grid.ip.internal.ipv4;
      port = 3124;

      overrides = {
        checks = [
          {
            http = "http://localhost:3124";
            interval = "5s";
          }
        ];
      };

      sidecar = {
        enable = true;
        adminBindPort = 19033;
        authenticate = true;

        upstreams = [
          {
            destination_name = "patroni";
            local_bind_port = 3125;
          }
        ];
      };
    };

    stop.roles.builder.client.enable = true;

    # https://github.com/NixOS/nixpkgs/blob/58a1abdbae3217ca6b702f03d3b35125d88a2994/nixos/modules/services/continuous-integration/hydra/default.nix#L33
    systemd.tmpfiles.rules = [
      "L+ '/var/lib/hydra/pgpass' - - - - ${config.age.secrets.hydra-pgpass.path}"
      "L+ '/var/lib/hydra/pgpass-queue-runner' - - - - ${config.age.secrets.hydra-pgpass-queue-runner.path}"
      "L+ '/var/lib/hydra/pgpass-www' - - - - ${config.age.secrets.hydra-pgpass-www.path}"
    ];

    services.grafana-agent.settings.metrics.configs = [
      {
        name = "hydra";
        scrape_configs = [
          {
            job_name = "hydra-queue-runner";
            metrics_path = "/metrics";
            static_configs = [ { targets = [ "localhost:9198" ]; } ];
          }
          {
            job_name = "hydra-www";
            metrics_path = "/metrics";
            static_configs = [
              {
                targets = [ "${config.services.hydra.listenHost}:${builtins.toString config.services.hydra.port}" ];
              }
            ];
          }
        ];

        remote_write =
          let
            remoteWriteTargets = builtins.map (p: {
              url = p;
              # put hostname in instance instead of localhost:1234
              write_relabel_configs = [
                {
                  replacement = config.networking.hostName;
                  target_label = "instance";
                  action = "replace";
                }
              ];
            }) site.promRemoteWriteEndpoints;
          in
          remoteWriteTargets;
      }
    ];
  };
}
