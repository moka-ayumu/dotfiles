{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-src = {
      url = "github:NixOS/nix/2.35.2";
      flake = false;
    };
  };

  outputs = { nixpkgs, nix-src, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      lib = pkgs.lib;

      basePkgs = import ./profiles/base.nix {
        inherit pkgs;
      };

      mkImage = tag: extraPkgs:
        pkgs.callPackage "${nix-src}/docker.nix" {
          name = "openshell";
          inherit tag extraPkgs;

          bundleNixpkgs = false;

          uid = 1000;
          gid = 1000;
          uname = "sandbox";
          gname = "sandbox";
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
          value = mkImage tag (basePkgs ++ profilePkgs);
        };

      profileImages =
        builtins.listToAttrs (map mkProfile profileFiles);

    in {
      packages.${system} =
        {
          base = mkImage "base" basePkgs;
        }
        // profileImages;
    };
}
