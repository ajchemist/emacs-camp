# emacs-camp image (ghcr.io/ajchemist/emacs-camp): `docker run -it` drops you
# into a shell with emacs-camp installed. The Killercoda scenario runs it.
# Built by the Home Manager module itself (homeConfigurations.sandbox-*):
# the same links, extras-default.el, compile and package sync as any deploy.
# Only the result ships: the home and its /nix/store closure, no Nix.
FROM nixos/nix AS build
ENV NIX_CONFIG="experimental-features = nix-command flakes"
# Emacs without native compilation is not in the binary cache. Build it in a
# layer that depends on flake.lock alone, so the GHA layer cache keeps it
# until the lock moves (same derivation as the sandbox's).
COPY flake.nix flake.lock /src/
RUN nix build --impure --no-link --expr \
      '(builtins.getFlake "path:/src").inputs.basecamp.lib.emacsPackage { system = builtins.currentSystem; nativeComp = false; }'
COPY . /src
RUN nix build "path:/src#homeConfigurations.sandbox-$(uname -m)-linux.activationPackage" -o /hm \
 && mkdir -p /home/user/.local/state/nix/profiles \
 && HOME=/home/user USER=user /hm/activate \
 && mkdir -p /out/nix/store \
 && cp -a $(nix-store -qR /hm) /out/nix/store/

FROM debian:trixie-slim
RUN useradd -m -s /bin/bash user
COPY --from=build /out/nix /nix
COPY --from=build --chown=user:user /home/user /home/user
USER user
WORKDIR /home/user
# The generation's own packages; no Nix profile ships.
ENV PATH=/home/user/.local/state/nix/profiles/home-manager/home-path/bin:$PATH TERM=xterm-256color LANG=C.UTF-8
CMD ["emacs"]
