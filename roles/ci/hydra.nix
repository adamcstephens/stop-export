{
  config,
  lib,
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
    age.secrets.hydra-pgpass = {
      file = ./hydra-pgpass.age;
      owner = "hydra";
    };

    services.hydra = {
      enable = true;

      # buildMachinesFiles = [ ];
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
      "L+ '/var/lib/hydra/pgpass-queue-runner' - - - - ${config.age.secrets.hydra-pgpass.path}"
      "L+ '/var/lib/hydra/pgpass-www' - - - - ${config.age.secrets.hydra-pgpass.path}"
    ];
  };
}
