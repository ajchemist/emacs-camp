# Home Manager and nix-darwin configurations for the checks and the CI
# deploy, from the upstream builders. Not a flake output: a downstream builds
# its own system and adds this flake's modules to it.
{ nixpkgs, home-manager, nix-darwin }:
{
  home = { user, system ? "x86_64-linux", homeDirectory ? "/home/${user}", modules ? [ ] }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [ {
        home.username = user;
        home.homeDirectory = homeDirectory;
        home.stateVersion = "25.05";
      } ] ++ modules;
    };

  darwin = { user, system ? "aarch64-darwin", modules ? [ ] }:
    nix-darwin.lib.darwinSystem {
      modules = [ home-manager.darwinModules.home-manager {
        nixpkgs.hostPlatform = system;
        # The Determinate installer owns the nix daemon, on runners as on hosts.
        nix.enable = false;
        # /etc/zshrc puts the system profile on PATH for later CI steps.
        programs.zsh.enable = true;
        documentation.enable = false;
        system.stateVersion = 6;
        system.primaryUser = user;
        users.users.${user}.home = "/Users/${user}";
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${user}.home.stateVersion = "25.05";
      } ] ++ modules;
    };
}
