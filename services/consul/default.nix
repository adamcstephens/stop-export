{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.consul;

  jsonType = {
    freeformType = (pkgs.formats.json { }).type;
  };

  sidecarServices = lib.filterAttrs (_: svc: svc.sidecar.enable) cfg.services;
in
{
  imports = [ ./connect-configs.nix ];

  options.services.consul = {
    envoyPackage = lib.mkOption {
      type = lib.types.package;
      description = "envoy package to use for consul connect proxies and sidecars.";
      default = pkgs.envoy;
    };

    services = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.attrsOf (
          lib.types.submodule (
            { name, config, ... }:
            {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Service name";
                  default = name;
                };

                address = lib.mkOption {
                  type = lib.types.str;
                  description = "service address";
                  default = "127.0.0.1";
                };

                hostnames = lib.mkOption {
                  type = lib.types.nullOr (lib.types.listOf lib.types.str);
                  description = "List of hostnames to route requests for consul connect services.";
                  default = null;
                };

                overrides = lib.mkOption {
                  type = lib.types.submodule jsonType;
                  description = "Overrides to merge on top of default service configuration.";
                  default = { };
                };

                pathPrefix = lib.mkOption {
                  type = lib.types.str;
                  description = "path prefix for http route";
                  default = "/";
                };

                port = lib.mkOption {
                  type = lib.types.port;
                  description = "Service port";
                };

                sidecar = {
                  enable = lib.mkEnableOption (lib.mdDoc "envoy sidecar proxy");

                  adminBindAddress = lib.mkOption {
                    type = lib.types.str;
                    description = "Envoy admin bind address.";
                    default = "127.0.0.1";
                  };

                  adminBindPort = lib.mkOption {
                    type = lib.types.port;
                    description = "Envoy admin bind port. Each service should have a unique port.";
                    default = 19000;
                  };

                  allowAll = lib.mkEnableOption (
                    lib.mdDoc "the service intention to allow a source of all services to the this service."
                  );

                  authenticate = lib.mkEnableOption (lib.mdDoc "authentication requirement on service.");

                  authenticateRedirect = lib.mkOption {
                    type = lib.types.str;
                    description = "URL to redirect to after authentication";
                    default = "https://${builtins.head config.hostnames}";
                  };

                  envoyLocalCluster = lib.mkOption {
                    type = lib.types.nullOr (lib.types.submodule jsonType);
                    description = "Envoy local cluster replacement json. See https://developer.hashicorp.com/consul/docs/connect/proxies/envoy#envoy_local_cluster_json";
                    default = null;
                  };

                  gatewayListener = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    description = "name of api-gateway listener to bind http/tcp route to, or `null` for no listener";
                    default = "listener-one";
                  };

                  loadBalancer = lib.mkOption {
                    type = lib.types.submodule jsonType;
                    description = "load balancers to pass to service resolver";
                    default = { };
                  };

                  localServiceAddress = lib.mkOption {
                    type = lib.types.str;
                    description = "proxy.local_service_address";
                    default = "127.0.0.1";
                  };

                  protocol = lib.mkOption {
                    type = lib.types.enum [
                      "grpc"
                      "http"
                      "http2"
                      "tcp"
                    ];
                    description = "protocol of service defaults";
                    default = "http";
                  };

                  requestTimeoutSec = lib.mkOption {
                    type = lib.types.nullOr lib.types.int;
                    description = "Increase envoy request timeouts (default 15s) for service path, in seconds.";
                    default = null;
                  };

                  serviceName = lib.mkOption {
                    type = lib.types.str;
                    description = "Sidecar proxy service name";
                    default = "${name}-sidecar-proxy";
                  };

                  systemd = lib.mkOption {
                    type = lib.types.attrsOf lib.types.anything;
                    description = "settings to merge with sidecar systemd service";
                    default = { };
                  };

                  upstreams = lib.mkOption {
                    type = lib.types.listOf (lib.types.submodule jsonType);
                    description = "extra sidecar upstreams to add";
                    default = [ ];
                  };
                };

                settings = lib.mkOption {
                  type = lib.types.submodule jsonType;
                  description = "Final settings to be written to consul service file.";
                };
              };
              config = {
                settings = {
                  service = [
                    (lib.mkMerge [
                      {
                        id = name;
                        name = name;
                        address = config.address;
                        port = config.port;

                        connect = lib.mkIf config.sidecar.enable {
                          sidecar_service.proxy = {
                            config = {
                              # ensure other nodes can reach this sidecar
                              # set address for public_listener, no ipv4_compat available
                              bind_address = "0.0.0.0";

                              envoy_local_cluster_json = lib.mkIf (config.sidecar.envoyLocalCluster != null) (
                                builtins.toJSON config.sidecar.envoyLocalCluster
                              );

                              local_request_timeout_ms = lib.mkIf (config.sidecar.requestTimeoutSec != null) (
                                config.sidecar.requestTimeoutSec * 1000
                              );
                            };

                            local_service_address = config.sidecar.localServiceAddress;

                            upstreams = lib.mkMerge [
                              config.sidecar.upstreams
                              (lib.mkIf config.sidecar.authenticate [
                                {
                                  destination_name = "oauth2-proxy";
                                  local_bind_port = 10000;
                                }
                              ])
                            ];
                          };
                        };
                      }
                      config.overrides
                    ])
                  ];
                };
              };
            }
          )
        )
      );
      description = "";
      default = null;
    };
  };

  config = lib.mkIf (cfg.services != null) {
    environment.etc = lib.mapAttrs' (
      _: svc: lib.nameValuePair "consul.d/${svc.name}.json" { text = builtins.toJSON svc.settings; }
    ) cfg.services;

    systemd.services = lib.mapAttrs' (
      _: svc:
      lib.nameValuePair svc.sidecar.serviceName (
        lib.mkMerge [
          {
            wantedBy = [ "multi-user.target" ];
            requires = [
              "consul.service"
              "network-online.target"
            ];
            after = [
              "consul.service"
              "network-online.target"
            ];

            path = [
              cfg.envoyPackage

              pkgs.bash
              pkgs.curl
              pkgs.jq
            ];

            serviceConfig = {
              # bash | tee to fix envoy unable to write to /dev/stdout
              ExecStart = "${lib.getExe pkgs.bash} -o pipefail -c '${lib.getExe pkgs.consul} connect envoy -proxy-id=${svc.sidecar.serviceName} -ignore-envoy-compatibility=true -admin-bind ${svc.sidecar.adminBindAddress}:${builtins.toString svc.sidecar.adminBindPort} | tee'";
              ExecStartPost = "${lib.getExe (
                pkgs.writeShellScriptBin "${svc.sidecar.serviceName}-start-post" ''
                  timeout 120 bash -c 'while [ "$(curl -s http://${svc.sidecar.adminBindAddress}:${builtins.toString svc.sidecar.adminBindPort}/server_info | jq .state -r)" != "LIVE" ]; do sleep 1; echo "Waiting for sidecar to go LIVE"; done'
                ''
              )}";

              DynamicUser = true;
              CacheDirectory = svc.sidecar.serviceName;
              StateDirectory = svc.sidecar.serviceName;

              # consul service can be started but not accepting api connections, slow the retry to allow for service to recover
              Restart = "always";
              RestartSec = "1s";
            };
          }
          svc.sidecar.systemd
        ]
      )
    ) sidecarServices;
  };
}
