{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.exabgp;
  envFormat = pkgs.formats.ini { };
  envFile = envFormat.generate "exabgp.env" cfg.environment;
in
{
  options.services.exabgp = {
    enable = lib.mkEnableOption "exabgp service";

    config = lib.mkOption {
      type = lib.types.lines;
      description = lib.mdDoc ''
        exabgp configuration file
      '';
    };

    environment = lib.mkOption {
      type = lib.types.submodule { freeformType = envFormat.type; };
      description = lib.mdDoc "exabgp environment values. See `exabgp --help` or `exabgp --full-ini`";
      default = {
        "exabgp.log" = {
          all = true;
          level = "DEBUG";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."exabgp/exabgp.env".source = envFile;

    environment.etc."exabgp/exabgp.conf".source = pkgs.writeTextFile {
      name = "exabgp";
      text = cfg.config;
    };

    environment.systemPackages = [ pkgs.exabgp ];

    systemd.services.exabgp = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        DynamicUser = true;
        RuntimeDirectory = "exabgp";
        # ProtectSystem = true;
        ExecStart = "${lib.getExe pkgs.exabgp} --env /etc/exabgp/exabgp.env /etc/exabgp/exabgp.conf";
      };
    };

    systemd.sockets.exabgp-in = {
      wantedBy = [ "multi-user.target" ];
      before = [ "exabgp.service" ];
      requiredBy = [ "exabgp.service" ];

      socketConfig = {
        SocketUser = "exabgp";
        SocketGroup = "exabgp";
        SocketMode = "0600";
        Service = "exabgp.service";
        ListenFIFO = "/run/exabgp/exabgp.in";
      };
    };

    systemd.sockets.exabgp-out = {
      wantedBy = [ "multi-user.target" ];
      before = [ "exabgp.service" ];
      requiredBy = [ "exabgp.service" ];

      socketConfig = {
        SocketUser = "exabgp";
        SocketGroup = "exabgp";
        SocketMode = "0600";
        Service = "exabgp.service";
        ListenFIFO = "/run/exabgp/exabgp.out";
      };
    };

    systemd.tmpfiles.settings."10-exabgp" = {
      "/run/exabgp".d = {
        user = "exabgp";
        group = "exabgp";
        mode = "0750";
      };
    };

    users.users.exabgp = {
      group = "exabgp";
      isSystemUser = true;
    };

    users.groups.exabgp = { };
  };
}
