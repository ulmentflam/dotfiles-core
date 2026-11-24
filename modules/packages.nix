# Installs lib/packages.nix. A nix-darwin or NixOS consumer that builds its own
# home.packages leaves this module out and calls the function instead.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.packages;
in
{
  options.dotfiles.packages = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the core CLI package list.";
    };
    homebrewCli = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        On macOS, leave the tools whose nixpkgs release trails Homebrew's
        (gh, awscli, just, sqlite, llvm, ...) to Homebrew formulae you declare
        elsewhere. Off, Nix provides them, pinned with everything else.
      '';
    };
  };

  config.home.packages = lib.mkIf cfg.enable (
    import ../lib/packages.nix {
      inherit pkgs;
      inherit (cfg) homebrewCli;
    }
  );
}
