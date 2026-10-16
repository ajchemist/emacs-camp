# Patching Emacs source

`lib/emacs.nix` selects the nixpkgs Emacs major and build variant. Add reviewed
patch files under `patches/` and pass them through `emacs-camp.patches`, or
`lib.emacsPackage { system = "aarch64-darwin"; patches = [ ./fix.patch ]; }`.
The builder appends them to nixpkgs' existing patches, preserving order, in
`overrideAttrs.patches`. The standard Nix patch phase runs before configure,
byte compilation, native compilation and installation. The changed derivation
is also the Emacs used to compile and synchronize the runtime configuration.

Keep each patch tied to an upstream issue/commit and affected source version.
Document its rationale and removal condition beside the file. Patch failure
must fail the build; never silently skip an incompatible patch. A patch applies
to all selected GUI/nox and native/non-native variants; use explicit platform
conditions at the consumer if it is platform-specific. Validate every affected
variant before publishing a changed pin. The fixture under `ci/` checks only
that a patch reaches the derivation's patch list; it does not build a patched
Emacs, and released packages do not carry it.

Packages from package.el are a separate matter: their versions come from the
pinned archive snapshot (docs/adr/0004-package-snapshot-pin.md), and a fix to
one of them is Lisp loaded at runtime, not a source patch here.
