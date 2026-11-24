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
    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "tor"
        "whisper-cpp"
      ];
      description = ''
        Package names (pname, as `nix search nixpkgs <name>` shows them) to
        leave out of the core list. A name that matches nothing is an error,
        so a typo cannot silently keep the package.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      let
        all = map (p: p.pname or (lib.getName p)) (
          import ../lib/packages.nix {
            inherit pkgs;
            inherit (cfg) homebrewCli;
          }
        );
        unknown = builtins.filter (n: !(builtins.elem n all)) cfg.exclude;
      in
      [
        {
          assertion = unknown == [ ];
          message = "dotfiles.packages.exclude names packages the core list does not have: ${toString unknown}";
        }
      ];

    home.packages = import ../lib/packages.nix {
      inherit pkgs;
      inherit (cfg) homebrewCli exclude;
    };
  };
}
