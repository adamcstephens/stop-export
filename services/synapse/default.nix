{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.services.synapse;
in
{
  options.stop.services.synapse = {
    enable = lib.mkEnableOption "host becomes a synapse server";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.synapse-secret = {
      file = ./synapse-secret.yaml.age;
      owner = "matrix-synapse";
    };

    age.secrets.sliding-sync = lib.mkIf config.services.matrix-sliding-sync.enable {
      file = ./sliding-sync.env.age;
      owner = "matrix-sliding-sync";
    };

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_14; # 15 requires some public schema access not supported by module (ownership works...)
      settings.listen_addresses = lib.mkForce "";
      ensureUsers = [
        {
          name = "matrix-synapse";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = [ "matrix-synapse" ];
      initdbArgs = [
        "--locale=C"
        "--encoding=UTF8"
      ];
    };

    services.matrix-synapse = {
      enable = true;

      settings = {
        server_name = config.robins.zone;
        public_baseurl = "https://${config.robins.hostnames.matrix}/";
        web_client_location = "https://${config.robins.hostnames.chat}/";
        # serve_server_wellknown = true; # doesn't support matrix.zone

        database.name = "psycopg2";
        enable_metrics = true;
        listeners = [
          {
            port = 8008;
            resources = [
              {
                compress = false;
                names = [
                  "client"
                  "federation"
                ];
              }
            ];
            tls = false;
            type = "http";
            x_forwarded = true;
            bind_addresses = [ "127.0.0.1" ];
          }
          {
            port = 9008;
            resources = [ ];
            tls = false;
            bind_addresses = [ "127.0.0.1" ];
            type = "metrics";
          }
        ];

        # see secret file oidc_providers = [];

        # we'll trust matrix.org implicitly
        suppress_key_server_warning = true;

        allow_guest_access = false;
        enable_registration = false;
        url_preview_enabled = true;
        expire_access_token = true;
      };

      extras = [ "oidc" ];

      extraConfigFiles = [ config.age.secrets.synapse-secret.path ];
    };

    services.matrix-sliding-sync = {
      enable = true;
      environmentFile = config.age.secrets.sliding-sync.path;
      createDatabase = true;
      settings.SYNCV3_SERVER = "https://${config.robins.hostnames.matrix}";
    };

    services.nginx = {
      enable = true;
      defaultHTTPListenPort = 8080;
      defaultListenAddresses = [ "127.0.0.1" ];

      virtualHosts = {
        "${config.robins.zone}" = {
          serverAliases = [ config.robins.hostnames.matrix ];

          locations = {
            "/.well-known/matrix/server" =
              let
                return = {
                  "m.server" = "${config.robins.hostnames.matrix}:443";
                };
              in
              {
                extraConfig = ''
                  return 200 '${builtins.toJSON return}';
                  default_type application/json;
                  add_header Access-Control-Allow-Origin *;
                '';
              };

            "/.well-known/matrix/client" =
              let
                return =
                  {
                    "m.server".base_url = "https://${config.robins.hostnames.matrix}";
                    "m.homeserver".base_url = "https://${config.robins.hostnames.matrix}";
                  }
                  // (lib.optionalAttrs config.services.matrix-sliding-sync.enable {
                    "org.matrix.msc3575.proxy".url = "https://${config.robins.hostnames.matrix-sliding-sync}";
                  });
              in
              {
                extraConfig = ''
                  return 200 '${builtins.toJSON return}';
                  default_type application/json;
                  add_header Access-Control-Allow-Origin *;
                '';
              };
          };
        };

        "${config.robins.hostnames.chat}" = {
          root = pkgs.element-web.override {
            conf = {
              default_server_name = config.robins.zone;
              sso_redirect_options.immediate = true;
            };
          };
        };
      };
    };

    stop.services.pomerium.enable = true;
    services.pomerium.settings = {
      service = "proxy";
      routes =
        [
          {
            from = "https://${config.robins.hostnames.matrix}";
            to = "http://127.0.0.1:8080";
            prefix = "/.well-known/matrix";
            allow_public_unauthenticated_access = true;
          }
          {
            from = "https://${config.robins.hostnames.matrix}";
            to = "http://127.0.0.1:8008";
            # policy.allow.and = [{accept = true;}];
            allow_public_unauthenticated_access = true;
          }
          {
            from = "https://${config.robins.hostnames.chat}";
            to = "http://127.0.0.1:8080";
            policy.allow.and = [ { domain.is = config.robins.zone; } ];
          }
          {
            from = "https://${config.robins.zone}";
            to = "http://127.0.0.1:8080";
            prefix = "/.well-known/matrix";
            allow_public_unauthenticated_access = true;
          }
        ]
        ++ (lib.optional config.services.matrix-sliding-sync.enable {
          from = "https://${config.robins.hostnames.matrix-sliding-sync}";
          to = "http://127.0.0.1:8009";
          # regex = "^/(client/|_matrix/client/unstable/org.matrix.msc3575/sync).*";
          allow_public_unauthenticated_access = true;
        });
    };

    users.groups.matrix-sliding-sync = lib.mkIf config.services.matrix-sliding-sync.enable { };
    users.users.matrix-sliding-sync = lib.mkIf config.services.matrix-sliding-sync.enable {
      isSystemUser = true;
      group = "matrix-sliding-sync";
    };
  };
}
