# Wire the gh CLI's GitHub token into the places that need it so anonymous
# api.github.com rate limits stop biting:
#
#   1. ~/.config/nix/nix.conf - access-tokens entry for `nix flake update`.
#   2. ~/.config/github-token.env - sourceable `export MISE_GITHUB_TOKEN=…` for
#      mise (otherwise hits the 60 req/hr anonymous cap when resolving releases).
#      zsh's envExtra sources this on every shell, including non-interactive
#      ones, so `mise upgrade` from scripts is covered too.
#
# The token is read from `gh auth token` at activation time and never committed
# to the repo or baked into the world-readable Nix store. Rotations via
# `gh auth refresh` are picked up the next time `nbs` runs. Skips silently when
# gh isn't logged in (first-bootstrap chicken-and-egg before `gh auth login`).
{ lib, pkgs, ... }:

{
  home.activation.githubToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ${pkgs.gh}/bin/gh auth status >/dev/null 2>&1; then
      token=$(${pkgs.gh}/bin/gh auth token 2>/dev/null || true)
      if [ -n "$token" ]; then
        mkdir -p "$HOME/.config/nix"
        umask 077

        # 1. nix
        nix_tmp=$(${pkgs.coreutils}/bin/mktemp "$HOME/.config/nix/nix.conf.XXXXXX")
        {
          echo "# Managed by dotfiles flake — modules/shared/github-token.nix"
          echo "# Token from \`gh auth token\`; rotate via \`gh auth refresh\` then \`nbs\`."
          printf 'access-tokens = github.com=%s\n' "$token"
        } > "$nix_tmp"
        chmod 600 "$nix_tmp"
        mv "$nix_tmp" "$HOME/.config/nix/nix.conf"

        # 2. mise (and anything else that wants MISE_GITHUB_TOKEN in env)
        env_tmp=$(${pkgs.coreutils}/bin/mktemp "$HOME/.config/github-token.env.XXXXXX")
        {
          echo "# Managed by dotfiles flake — modules/shared/github-token.nix"
          echo "# Sourced by zsh envExtra; mode 0600. Do not edit by hand."
          printf 'export MISE_GITHUB_TOKEN=%s\n' "$token"
        } > "$env_tmp"
        chmod 600 "$env_tmp"
        mv "$env_tmp" "$HOME/.config/github-token.env"
      fi
    fi
  '';
}
