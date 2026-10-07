# emacs-camp image (ghcr.io/ajchemist/emacs-camp): `docker run -it` drops you
# into a shell with emacs-camp installed. The Killercoda scenario runs it.
# Built by the Home Manager module itself (homeConfigurations.sandbox-*):
# the same links, extras-default.el, compile and package sync as any deploy.
# Only the result ships: the home and its /nix/store closure on scratch, no
# Nix and no distribution.
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
 && mkdir -p /out/nix/store /out/tmp /out/etc \
 && cp -a $(nix-store -qR /hm) /out/nix/store/ \
 && chmod 1777 /out/tmp \
 && echo 'root:x:0:0::/root:/bin/sh' > /out/etc/passwd \
 && echo 'user:x:1000:1000::/home/user:/home/user/.local/state/nix/profiles/home-manager/home-path/bin/bash' >> /out/etc/passwd \
 && printf 'root:x:0:\nuser:x:1000:\n' > /out/etc/group

# Two finals from the same build, both on ghcr: `debian` (tag :debian) adds a
# distribution (apt, /bin/sh) around the closure; the last stage, `scratch`
# (tag :latest), is nothing but the closure, which carries its own glibc,
# shell and tools.
FROM debian:trixie-slim AS debian
RUN useradd -m -u 1000 -s /bin/bash user
COPY --from=build /out/nix /nix
COPY --from=build --chown=user:user /home/user /home/user
USER user
WORKDIR /home/user
ENV PATH=/home/user/.local/state/nix/profiles/home-manager/home-path/bin:$PATH \
    TERM=xterm-256color LANG=C.UTF-8
CMD ["emacs"]

FROM scratch AS scratch
COPY --from=build /out /
COPY --from=build --chown=1000:1000 /home/user /home/user
USER user
WORKDIR /home/user
# The generation's own packages; no Nix profile ships.
ENV PATH=/home/user/.local/state/nix/profiles/home-manager/home-path/bin \
    SSL_CERT_FILE=/home/user/.local/state/nix/profiles/home-manager/home-path/etc/ssl/certs/ca-bundle.crt \
    HOME=/home/user SHELL=/home/user/.local/state/nix/profiles/home-manager/home-path/bin/bash \
    TERM=xterm-256color LANG=C.UTF-8
CMD ["emacs"]
