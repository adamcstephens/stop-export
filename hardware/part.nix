{ lib, ... }:
let
  importDirs =
    dir:
    builtins.listToAttrs (
      builtins.map (d: {
        name = "hardware-${d}";
        value = import "${dir}/${d}";
      }) (builtins.attrNames (lib.filterAttrs (n: t: t == "directory") (builtins.readDir dir)))
    );
in
{
  flake.nixosModules = importDirs ./.;
}
