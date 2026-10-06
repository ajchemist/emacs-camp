# mybinder.org demo: JupyterLab with a terminal; run `emacs` there.
# Emacs 31 (what basecamp ships) is built from source: distro Emacs is too
# old for the package set (forge needs the built-in compat 31).
FROM quay.io/jupyter/minimal-notebook:latest
USER root
RUN apt-get update && apt-get -y install --no-install-recommends \
      build-essential pkg-config libgnutls28-dev libncurses-dev zlib1g-dev libtree-sitter-dev git \
 && curl -sSfL https://mirrors.kernel.org/gnu/emacs/emacs-31.1.tar.gz | tar xz -C /tmp \
 && cd /tmp/emacs-31.1 && ./configure --without-x --without-sound --without-makeinfo --without-native-compilation \
 && make -j"$(nproc)" && make install && rm -rf /tmp/emacs-31.1 /var/lib/apt/lists/*
USER ${NB_USER}
COPY --chown=${NB_UID}:${NB_GID} lisp/ /home/${NB_USER}/.config/emacs/
COPY --chown=${NB_UID}:${NB_GID} sync.el compile.el /tmp/
RUN emacs --batch -l /tmp/sync.el
RUN cd ~/.config/emacs && emacs --batch -l /tmp/compile.el -f batch-byte-compile early-init.el init.el
