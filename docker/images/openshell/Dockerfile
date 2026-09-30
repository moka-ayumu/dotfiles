# OpenShell sandbox image: OpenShell's default workload image + single-user Nix.
#
# Toolchains come from the flake profile selected by PROFILE and are installed
# into /nix/var/nix/profiles/default. /nix is owned by the sandbox user so
# projects can add more with `nix shell` / `nix profile` at runtime.

FROM nvcr.io/nvidia/base/ubuntu:24.04

ARG PROFILE=base

ENV DEBIAN_FRONTEND=noninteractive

# iproute2: network namespace management; nftables: bypass detection.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        iproute2 \
        nftables \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu images ship an `ubuntu` account at 1000; OpenShell expects `sandbox`.
RUN if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi \
    && groupadd --gid 1000 sandbox \
    && useradd --uid 1000 --gid sandbox --home-dir /sandbox --shell /bin/bash sandbox \
    && install -d -o sandbox -g sandbox /nix /sandbox

# Single-user Nix: no daemon, no build users. Sandbox builds are disabled
# because neither docker build nor the OpenShell sandbox provide user namespaces.
#
# filter-syscalls: OpenShell already applies seccomp; nix's own filter fails to load.
# substitute: nix sees only `lo`, assumes offline and disables the binary cache.
# download-attempts / connect-timeout: offline mode zeroes retries, but the proxy
#   drops its synthetic DNS mapping after ~30s (libcurl caches for 60s).
RUN mkdir -p /etc/nix \
    && printf '%s\n' \
        'experimental-features = nix-command flakes' \
        'build-users-group =' \
        'sandbox = false' \
        'filter-syscalls = false' \
        'substitute = true' \
        'download-attempts = 10' \
        'connect-timeout = 10' \
        > /etc/nix/nix.conf

ENV USER=sandbox \
    HOME=/sandbox \
    PATH=/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin \
    NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

USER sandbox
WORKDIR /sandbox

RUN curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --no-modify-profile

COPY --chown=sandbox:sandbox flake.nix flake.lock /tmp/openshell/
COPY --chown=sandbox:sandbox profiles/ /tmp/openshell/profiles/

# Install the profile (which includes nix itself), then drop the installer's
# per-user profile so only the default profile is rooted.
RUN /sandbox/.nix-profile/bin/nix profile add \
        --profile /nix/var/nix/profiles/default \
        "path:/tmp/openshell#${PROFILE}" \
    && rm -rf /tmp/openshell /sandbox/.nix-profile /sandbox/.local/state/nix /sandbox/.cache/nix \
    && nix store gc

USER root

# `openshell sandbox exec` runs `bash -lc`, which resets PATH via /etc/profile.
# nix's own profile.d script sets NIX_SSL_CERT_FILE to the system CA, which lacks
# the OpenShell proxy CA; point it at the injected SSL_CERT_FILE instead.
RUN printf '%s\n' \
        'export PATH="/nix/var/nix/profiles/default/bin:$PATH"' \
        'for f in /nix/var/nix/profiles/default/etc/profile.d/*.sh; do' \
        '  [ -r "$f" ] && . "$f"' \
        'done' \
        'if [ -n "${SSL_CERT_FILE:-}" ]; then' \
        '  export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"' \
        'fi' \
        > /etc/profile.d/nix.sh

# The sandbox starts with an empty /etc/hosts, so `localhost` does not resolve
# (e.g. vite fails with ENOTFOUND). Docker bind-mounts its own /etc/hosts at
# build time, so a plain RUN write is discarded; bake the file in via COPY.
COPY hosts /etc/hosts

COPY policy.yaml /etc/openshell/policy.yaml

USER sandbox

CMD ["/bin/bash"]
