{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (utils.systemdUtils.lib) mkPathSafeName;

  cfg = config.services.litefs;

  yamlType = pkgs.formats.yaml { };

  mkConfig = name: settings: yamlType.generate "litefs.yml" settings;

  services =
    lib.mapAttrs'
      (
        name: v:
        lib.nameValuePair "litefs-${name}" {
          wantedBy = [ "multi-user.target" ];
          requires = [ "network-online.target" ];
          after = [ "network-online.target" ];

          path = [ "/run/wrappers" ];

          serviceConfig = {
            # StateDirectory = v.settings.data.dir;
            User = v.user;
            Group = "users";
            ExecStart = "${lib.getExe pkgs.litefs} mount -config ${mkConfig name v.settings}";
          };
        }
      )
      cfg.mounts;

  tmpfiles =
    lib.mapAttrs'
      (
        name: v:
        lib.nameValuePair "10-litefs-${name}" {
          "${v.settings.data.dir}".d = {
            user = v.user;
            mode = "0700";
          };
          "${v.settings.fuse.dir}".d = {
            user = v.user;
            mode = "0700";
          };
        }
      )
      cfg.mounts;
in
{
  options.services.litefs = {
    package = lib.mkOption {
      type = lib.types.package;
      description = "litefs package";
      default = pkgs.litefs;
    };
    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              user = lib.mkOption {
                type = lib.types.str;
                description = "user which the service will run as and will be used for the database mount";
              };

              settings = lib.mkOption {
                type = lib.types.submodule ({
                  freeformType = yamlType.type;

                  options = {
                    fuse.dir = lib.mkOption {
                      type = lib.types.str;
                      description = "path for litefs fuse mount";
                    };

                    data.dir = lib.mkOption {
                      type = lib.types.str;
                      description = "path for node-specific state";
                      default = "/var/lib/litefs/${name}";
                    };
                  };
                });
                description = "litefs.yml configuration. See https://github.com/superfly/litefs/blob/main/cmd/litefs/etc/litefs.yml";
                default = { };
              };
            };
          }
        )
      );
      description = "";
      default = { };
    };
  };

  config = lib.mkIf (cfg.mounts != { }) {
    systemd.services = services;
    systemd.tmpfiles.settings = tmpfiles;
  };
}
