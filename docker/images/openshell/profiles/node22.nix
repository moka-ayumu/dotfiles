{ pkgs }:

let
  # Playwright can't use its downloaded browsers on Nix, so ship the
  # nixpkgs-built ones instead. The project's playwright version must match
  # pkgs.playwright-driver.version for the browser revisions to line up.
  upstreamBrowsers = pkgs.playwright-driver.browsers.override {
    withFirefox = false;
  };

  # Chromium's zygote drops capabilities in every forked child even with
  # --no-sandbox, and the OpenShell sandbox rejects that with EPERM, so the
  # GPU process never starts and the browser aborts. --no-zygote makes chromium
  # fork/exec children directly; playwright already passes the --no-sandbox it
  # requires.
  playwrightBrowsers = pkgs.runCommand "playwright-browsers-openshell" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p $out
    for link in ${upstreamBrowsers}/*; do
      name=$(basename "$link")
      src=$(readlink -f "$link")
      case "$name" in
        chromium_headless_shell-*) bin=chrome-headless-shell-linux64/chrome-headless-shell ;;
        chromium-*) bin=chrome-linux64/chrome ;;
        *) ln -s "$src" "$out/$name"; continue ;;
      esac
      # The real binary locates its resources via /proc/self/exe, so the
      # wrapper can live in a symlink copy of the directory.
      cp -rs "$src" "$out/$name"
      chmod -R u+w "$out/$name"
      rm "$out/$name/$bin"
      makeWrapper "$src/$bin" "$out/$name/$bin" --add-flags --no-zygote
    done
  '';

  # chrome-headless-shell and webkit are not wrapped with a fontconfig file
  # upstream, and the image has no /etc/fonts.
  fontsConf = pkgs.makeFontsConf {
    fontDirectories = [ ];
  };

  # Sourced from /etc/profile.d/nix.sh (see Dockerfile).
  playwrightEnv = pkgs.writeTextDir "etc/profile.d/playwright.sh" ''
    export PLAYWRIGHT_BROWSERS_PATH=${playwrightBrowsers}
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
    # Pins the webkit revision lookup to the build nixpkgs ships.
    export PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu-24.04
    export FONTCONFIG_FILE=''${FONTCONFIG_FILE:-${fontsConf}}
  '';
in
with pkgs; [
  nodejs_22
  pnpm
  playwrightEnv
]
