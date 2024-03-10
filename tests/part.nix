{ inputs, self, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      routerCommon = import ./router-common.nix { inherit inputs lib self; };
    in
    {
      checks = {
        # grid = import ./grid.nix {
        #   inherit
        #     inputs
        #     lib
        #     pkgs
        #     self
        #     system
        #     ;
        # };
        bgp = import ./bgp.nix {
          inherit
            lib
            pkgs
            routerCommon
            self
            ;
        };

        home-manager-managed = import ./home-manager-managed.nix { inherit inputs lib pkgs; };
        home-manager-unmanaged = import ./home-manager-unmanaged.nix { inherit inputs lib pkgs; };

        litefs = import ./litefs.nix {
          inherit
            inputs
            lib
            pkgs
            self
            ;
        };
        router = import ./router.nix { inherit lib pkgs routerCommon; };
      };
    };
}
