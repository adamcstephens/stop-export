{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.stop.services.synapse;
  site = config.stop.sites.${config.stop.site};
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

    security.acme = {
      acceptTerms = true;

      defaults.email = config.stop.acme.email;

      certs.synapse = {
        domain = config.robins.zone;
        extraDomainNames = [
          site.services.chat
          site.services.cinny
          config.robins.hostnames.matrix
          config.robins.hostnames.matrix-sliding-sync
        ];

        listenHTTP = ":80";

        group = "traefik";

        reloadServices = [ "traefik.service" ];
      };
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
        web_client_location = "https://${site.services.chat}/";
        # serve_server_wellknown = true; # doesn't support matrix.zone

        # these were manually copied
        app_service_config_files = [ "/var/lib/matrix-synapse/telegram-registration.yaml" ];

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

        "${site.services.chat}" = {
          root = pkgs.element-web.override {
            conf = {
              default_server_name = config.robins.zone;
              sso_redirect_options.immediate = true;
            };
          };
        };

        "${site.services.cinny}" = {
          root = pkgs.cinny.override {
            conf = {
              defaultHomeserver = 0;
              homeserverList = [ config.robins.zone ];
            };
          };
        };
      };
    };

    stop.services.traefik.enable = true;
    services.traefik.staticConfigOptions.api = lib.mkForce false;
    services.traefik.dynamicConfigOptions = {
      tls.certificates = [
        {
          certFile = "/var/lib/acme/synapse/fullchain.pem";
          keyFile = "/var/lib/acme/synapse/key.pem";
        }
      ];

      http.routers = {
        synapse = {
          entryPoints = [ "websecure" ];
          rule = "Host(`${config.robins.hostnames.matrix}`)";
          service = "synapse";
          tls = true;
        };
        matrix-wellknown = {
          entryPoints = [ "websecure" ];
          rule = "(Host(`${config.robins.hostnames.matrix}`) || Host(`${config.robins.zone}`)) && PathPrefix(`/.well-known/matrix`)";
          service = "nginx";
          tls = true;
        };
        element = {
          entryPoints = [ "websecure" ];
          rule = "Host(`${site.services.chat}`)";
          service = "nginx";
          tls = true;
        };
        cinny = {
          entryPoints = [ "websecure" ];
          rule = "Host(`${site.services.cinny}`)";
          service = "nginx";
          tls = true;
        };
      };

      http.services = {
        nginx.loadBalancer.servers = [ { url = "http://127.0.0.1:8080"; } ];
        synapse.loadBalancer.servers = [ { url = "http://127.0.0.1:8008"; } ];
      };
    };

    users.groups.matrix-sliding-sync = lib.mkIf config.services.matrix-sliding-sync.enable { };
    users.users.matrix-sliding-sync = lib.mkIf config.services.matrix-sliding-sync.enable {
      isSystemUser = true;
      group = "matrix-sliding-sync";
    };
  };
}
