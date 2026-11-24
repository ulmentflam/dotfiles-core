# Defaults for a standalone Home Manager configuration (lib.mkHome): no
# nix-darwin or NixOS underneath, so Home Manager manages itself.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  home = {
    homeDirectory = lib.mkDefault (
      if pkgs.stdenv.hostPlatform.isDarwin then
        "/Users/${config.home.username}"
      else
        "/home/${config.home.username}"
    );
    sessionVariables = {
      # Silence zoxide's "init must be last" doctor warning. Set here (not in
      # zshrc) so it lands in .zshenv via hm-session-vars.sh, which is sourced
      # BEFORE zshrc.
      _ZO_DOCTOR = "0";
    };
  };

  programs.home-manager.enable = true;
}
