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
        litefs = import ./litefs.nix { inherit lib pkgs self; };
        router = import ./router.nix { inherit lib pkgs routerCommon; };
      };
    };
}
