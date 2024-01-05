{ config, lib, ... }:
let
  cfg = config.stop.roles.grid.bgp;
in
{
  options.stop.roles.grid.bgp = {
    enable = lib.mkEnableOption "exabgp service";
  };

  config = lib.mkIf cfg.enable {
    services.exabgp = {
      enable = true;
      config = ''
        template {
          neighbor v4 {
            router-id 192.168.1.1;
            local-address 192.168.1.1;
            local-as 65002;
            peer-as 65001;
            hold-time 6;
            family {
              ipv4 unicast;
            }
          }
        }

        # First router
        neighbor 192.168.1.2 {
          inherit v4;
        }
      '';
    };
  };
}
