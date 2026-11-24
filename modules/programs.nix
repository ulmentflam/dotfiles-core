# The programs module: lib/programs.nix as `programs`, plus the standalone
# defaults for the rebuild functions and the `about` list. A nix-darwin or
# NixOS consumer can instead assign lib.programs to `programs` itself and set
# those two options.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.dotfiles;
  brewfile = config.dotfiles.darwin.brewfile.enable or false;
in
{
  imports = [ ./options.nix ];

  dotfiles.zsh = {
    rebuildFunctions = lib.mkDefault (
      import ./zsh/rebuild.nix {
        inherit lib brewfile;
        churnyInputs = lib.concatStringsSep " " cfg.repo.churnyInputs;
        inherit (cfg.repo) path flakeDir;
        inherit (cfg) toolVersions;
      }
    );
    about.entries = lib.mkDefault (
      import ./zsh/about-entries.nix {
        inherit (cfg.repo) path flakeDir gitConfigFile;
        inherit brewfile;
      }
    );
  };

  programs = import ../lib/programs.nix { inherit config pkgs lib; };
}
