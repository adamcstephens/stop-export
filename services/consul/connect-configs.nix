{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.services.consul;

  consulServices = lib.foldlAttrs (
    acc: name: val:
    acc
    // (lib.optionalAttrs (
      val.config.services.consul.services != null
    ) val.config.services.consul.services)
  ) { } self.nixosConfigurations;

  sidecarServices = lib.filterAttrs (_: svc: svc.sidecar.enable) consulServices;

  serviceDefaults = lib.mapAttrs' (
    _: svc:
    lib.nameValuePair "svc_defaults_${svc.name}" {
      kind = "service-defaults";
      name = svc.name;
      config_json = builtins.toJSON (
        {
          Protocol = svc.sidecar.protocol;
          TransparentProxy = { };
          MeshGateway = { };
          LocalRequestTimeoutMs = 30000;
        }
        // (lib.optionalAttrs svc.sidecar.authenticate {
          EnvoyExtensions = [
            {
              Name = "builtin/ext-authz";
              Required = true;
              Arguments = {
                ProxyType = "connect-proxy";

                Config.HttpService = {
                  Target.Service.Name = "oauth2-proxy";
                  Target.Timeout = "1s";

                  AuthorizationRequest = {
                    AllowedHeaders = [ { SafeRegex = ".*"; } ];
                    HeadersToAdd = [
                      {
                        Key = "x-auth-request-redirect";
                        Value = svc.sidecar.authenticateRedirect;
                      }
                    ];
                  };

                  AuthorizationResponse.AllowedClientHeaders = [ { SafeRegex = ".*"; } ];
                  AuthorizationResponse.AllowedUpstreamHeadersToAppend = [
                    {
                      Prefix = "x-";
                      IgnoreCase = true;
                    }
                  ];
                };
              };
            }
          ];
        })
      );
    }
  ) sidecarServices;

  serviceHttpRoutes =
    lib.mapAttrs'
      (
        _: svc:
        lib.nameValuePair "http_route_${svc.name}" {
          kind = "http-route";
          name = svc.name;
          config_json = builtins.toJSON {
            Hostnames = svc.hostnames;
            Parents = [
              {
                SectionName = svc.sidecar.gatewayListener;
                Name = "api-gateway";
                Kind = "api-gateway";
              }
            ];
            Rules =
              [
                {
                  Filters = lib.optionalAttrs (svc.sidecar.requestTimeoutSec != null) {
                    TimeoutFilter = {
                      RequestTimeout = "${builtins.toString svc.sidecar.requestTimeoutSec}s";
                    };
                  };
                  Matches = [
                    {
                      Path = {
                        Match = "prefix";
                        Value = svc.pathPrefix;
                      };
                    }
                  ];
                  Services = [ { Name = svc.name; } ];
                }
              ]
              ++ lib.optional svc.sidecar.authenticate {
                Matches = [
                  {
                    Path = {
                      Match = "prefix";
                      Value = "/oauth2";
                    };
                  }
                ];
                Services = [ { Name = "oauth2-proxy"; } ];
              };
          };
        }
      )
      (
        lib.filterAttrs (
          k: v: v.sidecar.protocol == "http" && v.sidecar.gatewayListener != null
        ) sidecarServices
      );

  serviceTcpRoutes =
    lib.mapAttrs'
      (
        _: svc:
        lib.nameValuePair "tcp_route_${svc.name}" {
          kind = "tcp-route";
          name = svc.name;
          config_json = builtins.toJSON {
            Parents = [
              {
                SectionName = svc.sidecar.gatewayListener;
                Name = "api-gateway";
                Kind = "api-gateway";
              }
            ];
            Services = [ { Name = svc.name; } ];
          };
        }
      )
      (
        lib.filterAttrs (
          k: v: v.sidecar.protocol == "tcp" && v.sidecar.gatewayListener != null
        ) sidecarServices
      );

  serviceIntentions = lib.mapAttrs' (
    _: svc:
    lib.nameValuePair "svc_intention_${svc.name}" {
      kind = "service-intentions";
      name = svc.name;
      config_json = builtins.toJSON {
        Sources =
          [
            {
              Action = "allow";
              Name = "api-gateway";
              Type = "consul";
            }
          ]
          ++ (lib.optional svc.sidecar.allowAll {
            Name = "*";
            Action = "allow";
            Type = "consul";
            Description = "allow-all";
          });
      };
    }
  ) sidecarServices;

  serviceResolvers = lib.mapAttrs' (
    _: svc:
    lib.nameValuePair "svc_resolver_${svc.name}" {
      kind = "service-resolver";
      name = svc.name;
      config_json = builtins.toJSON { loadBalancer = svc.sidecar.loadBalancer; };
    }
  ) (lib.filterAttrs (_: svc: svc.sidecar.loadBalancer != { }) sidecarServices);
in
{
  options = {
    services.consul.createConnectConfigs = lib.mkEnableOption (
      lib.mdDoc "creation of consul connect configurations using tfyolo"
    );
  };

  config = lib.mkIf (cfg.createConnectConfigs) {
    tfyolo = {
      settings = {
        terraform.required_providers.consul.source = "registry.terraform.io/hashicorp/consul";
        provider.consul = { };

        resource.consul_config_entry =
          serviceDefaults // serviceIntentions // serviceHttpRoutes // serviceTcpRoutes // serviceResolvers;
      };
    };
  };
}
