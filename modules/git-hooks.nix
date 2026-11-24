# Point each listed checkout at its committed hooks (.githooks/), which means a
# pre-commit hook that rejects .nix files that aren't nixfmt-clean.
#
# Why core.hooksPath instead of writing into .git/hooks: .git/ isn't version
# controlled, so anything written there is invisible and drifts per clone.
# .githooks/ is committed, reviewable, and identical on every machine.
#
# Scoped with `git config --local` on purpose. Setting core.hooksPath in the
# global ~/.gitconfig would apply the hook to *every* repo on the machine,
# including ones with no Nix in them.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles;
  block = repo: ''
    repo="${repo}"
    hooks="$repo/.githooks"

    # Skip silently when the repo isn't checked out at the expected path — the
    # standalone home-manager profile can be applied on a box without it.
    if [ -e "$repo/.git" ] && [ -d "$hooks" ]; then
      chmod +x "$hooks"/* 2>/dev/null || true

      current=$(${pkgs.git}/bin/git -C "$repo" config --local --get core.hooksPath 2>/dev/null || true)
      if [ "$current" != ".githooks" ]; then
        ${pkgs.git}/bin/git -C "$repo" config --local core.hooksPath .githooks
        echo "dotfiles: core.hooksPath -> .githooks (pre-commit nixfmt check enabled)"
      fi
    fi
  '';
in
{
  imports = [ ./options.nix ];

  options.dotfiles.gitHooks.repos = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ (lib.replaceStrings [ "~" ] [ "$HOME" ] cfg.repo.path) ];
    defaultText = lib.literalMD "`dotfiles.repo.path`, with `~` as `$HOME`";
    description = "Checkouts whose core.hooksPath is set to their .githooks/ at activation.";
  };

  config.home.activation.dotfilesGitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n" block cfg.gitHooks.repos
  );
}
