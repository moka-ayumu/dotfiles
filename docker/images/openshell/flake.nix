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

      # docker.nix puts /etc/{passwd,group,shadow,...} in as absolute symlinks
      # into /nix/store. OpenShell's image-prep touches these files outside a
      # chroot, so they must be real files in the image root.
      dockerTools = pkgs.dockerTools // {
        buildLayeredImageWithNixDb = args:
          pkgs.dockerTools.buildLayeredImageWithNixDb (args // {
            fakeRootCommands = (args.fakeRootCommands or "") + ''
              find etc -type l | while IFS= read -r link; do
                target="$(readlink "$link")"
                case "$target" in
                  /nix/store/*)
                    rm "$link"
                    cp -rL "$target" "$link"
                    chmod -R u+w "$link"
                    ;;
                esac
              done

              chmod 0644 etc/passwd etc/group
              chmod 0600 etc/shadow
            '';
          });
      };

      mkImage = tag: extraPkgs:
        pkgs.callPackage "${nix-src}/docker.nix" {
          name = "openshell";
          inherit tag extraPkgs dockerTools;

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
