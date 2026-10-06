# emacs-camp image (ghcr.io/ajchemist/emacs-camp): `docker run -it`
# drops you into a shell with emacs-camp installed. The Killercoda scenario
# runs it. Emacs 31.1 is built from source: distro Emacs is too old for the
# package set (forge needs the built-in compat 31).
FROM debian:trixie-slim AS emacs
RUN apt-get update && apt-get -y install --no-install-recommends \
      build-essential pkg-config curl ca-certificates libgnutls28-dev libncurses-dev zlib1g-dev libtree-sitter-dev \
 && for m in https://ftpmirror.gnu.org https://mirrors.kernel.org/gnu https://mirror.csclub.uwaterloo.ca/gnu; do \
      curl -sSfL --retry 2 -o /tmp/emacs.tgz "$m/emacs/emacs-31.1.tar.gz" && break; done \
 && tar xzf /tmp/emacs.tgz -C /tmp \
 && cd /tmp/emacs-31.1 && ./configure --without-x --without-sound --without-makeinfo --without-native-compilation \
 && make -j"$(nproc)" && make install

FROM debian:trixie-slim
RUN apt-get update && apt-get -y install --no-install-recommends \
      ca-certificates git less libgnutls30t64 libncursesw6 libtree-sitter0.22 \
 && rm -rf /var/lib/apt/lists/* && useradd -m -s /bin/bash user
COPY --from=emacs /usr/local /usr/local
USER user
WORKDIR /home/user
COPY --chown=user:user lisp/ .config/emacs/
# extras/ (opt-in under the module) load as user files, so the demo shows them all.
COPY --chown=user:user extras/ .config/emacs/user/
COPY sync.el compile.el /tmp/
RUN emacs --batch -l /tmp/sync.el \
 && cd .config/emacs && emacs --batch -l /tmp/compile.el -f batch-byte-compile early-init.el init.el user/*.el
ENV TERM=xterm-256color LANG=C.UTF-8
CMD ["emacs"]
