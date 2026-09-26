{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      lib = pkgs.lib;

      basePkgs = import ./profiles/base.nix {
        inherit pkgs;
      };

      # Installed into /nix/var/nix/profiles/default by the Dockerfile.
      # nix itself is included so the image does not depend on the
      # installer's per-user profile under /sandbox.
      mkEnv = tag: extraPkgs:
        pkgs.buildEnv {
          name = "openshell-${tag}";
          paths = [ pkgs.nix ] ++ extraPkgs;
        };

      profileEntries = builtins.readDir ./profiles;

      profileFiles =
        builtins.filter
          (file:
            file != "base.nix"
            && profileEntries.${file} == "regular"
            && lib.hasSuffix ".nix" file)
          (builtins.attrNames profileEntries);

      mkProfile = file:
        let
          tag = lib.removeSuffix ".nix" file;

          profilePkgs = import (./profiles + "/${file}") {
            inherit pkgs;
          };
        in
        {
          name = tag;
          value = mkEnv tag (basePkgs ++ profilePkgs);
        };

      profileEnvs =
        builtins.listToAttrs (map mkProfile profileFiles);

    in {
      packages.${system} =
        {
          base = mkEnv "base" basePkgs;
        }
        // profileEnvs;
    };
}
