{ lib, config, pkgs, osConfig ? null, ... }:
let
  cfg = config.emacs-camp;
  emacs = import ./lib/emacs.nix { inherit lib; };
  from = if osConfig != null && osConfig ? emacs-camp then osConfig.emacs-camp else null;
in
{
  options.emacs-camp = emacs.options { inherit pkgs cfg from; };

  config = lib.mkIf (cfg.enable && from == null) {
    home.packages = [ cfg.package ];
  };
}
