{ pkgs }:

let
  # Playwright can't use its downloaded browsers on Nix, so ship the
  # nixpkgs-built ones instead. The project's playwright version must match
  # pkgs.playwright-driver.version for the chromium revision to line up.
  playwrightBrowsers = pkgs.playwright-driver.browsers.override {
    withFirefox = false;
    withWebkit = false;
  };

  # Sourced from /etc/profile.d/nix.sh (see Dockerfile).
  playwrightEnv = pkgs.writeTextDir "etc/profile.d/playwright.sh" ''
    export PLAYWRIGHT_BROWSERS_PATH=${playwrightBrowsers}
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
  '';
in
with pkgs; [
  nodejs_22
  pnpm
  playwrightEnv
]
