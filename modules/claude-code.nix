{ pkgs, lib, ... }:
# Claude Code via Anthropic's native installer, not Homebrew.
#
# The `claude-code@latest` cask disables Claude Code's own background
# auto-updater (it detects a brew-managed install), so every release turned
# into "Update available! Run: brew upgrade claude-code@latest", which in this
# setup meant an `nbs`. The native install under ~/.local/share/claude keeps
# itself current on the `latest` channel with no rebuild involved.
#
# Home-manager only bootstraps: install once if the binary is missing, and
# (macOS only, guarded on the brew binary) retire the cask once so
# /opt/homebrew/bin/claude stops shadowing ~/.local/bin/claude. Both steps
# are no-ops afterwards. On a Mac running `nbs`, homebrew.onActivation's
# `cleanup = "uninstall"` removes the cask first; the explicit step covers a
# home-manager activation that runs without brew bundle.
#
let
  installer = "https://claude.ai/install.sh";
  cask = "claude-code@latest";
  brew = "/opt/homebrew/bin/brew";
  installerDeps = lib.makeBinPath (import ./native-installer-deps.nix { inherit pkgs; });
in
{
  # The installer puts the binary in ~/.local/bin and, on a home-manager
  # managed shell, cannot edit .zshrc to add it. Do that here for every
  # profile, including in nested shells that inherit a stripped PATH.
  imports = [ ./local-bin-path.nix ];

  home.activation.claudeCodeNative = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.local/bin/claude" ]; then
      echo "Installing Claude Code (native, latest channel)..."
      # ~/.local/bin leads the PATH so the installer's own check sees the
      # directory already configured. Without it the script tries to append a
      # PATH export to ~/.zshrc, which home-manager owns as a read-only store
      # symlink, and emits a wall of warnings about a temp file it cannot
      # create under /nix/store. It is only ever a warning (the binary still
      # lands), but it is alarming and it is avoidable: local-bin-path.nix
      # genuinely does put the directory on PATH for every shell.
      run ${pkgs.curl}/bin/curl -fsSL ${installer} \
        | PATH="$HOME/.local/bin:${installerDeps}:$PATH" ${pkgs.bash}/bin/bash -s latest \
        || true

      # Judge by the binary, not the exit status. The vendor script's last
      # step tries to launch the CLI interactively and returns non-zero under
      # activation even when the install worked, so keying the warning off
      # `||` reports a failure that did not happen. The reverse case is what
      # hid this bug for so long, so be explicit in both directions.
      if [ -x "$HOME/.local/bin/claude" ]; then
        echo "Claude Code installed."
      else
        echo >&2 "warning: Claude Code native install failed; rerun: curl -fsSL ${installer} | bash -s latest"
      fi
    fi

    # Merge the attribution setting into settings.json rather than owning the
    # file: Claude Code writes its own keys there (model, plugins, status
    # line) and a managed symlink would fight it. Empty strings suppress the
    # "Generated with Claude Code" PR footer and the Co-Authored-By commit
    # trailer. includeCoAuthoredBy is the deprecated predecessor; drop it so
    # the two can never disagree.
    CC_SETTINGS="$HOME/.claude/settings.json"
    run ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude"
    [ -f "$CC_SETTINGS" ] || echo '{}' > "$CC_SETTINGS"
    if ${pkgs.jq}/bin/jq '.attribution = { commit: "", pr: "" } | del(.includeCoAuthoredBy)' \
      "$CC_SETTINGS" > "$CC_SETTINGS.tmp"; then
      run ${pkgs.coreutils}/bin/mv "$CC_SETTINGS.tmp" "$CC_SETTINGS"
    else
      ${pkgs.coreutils}/bin/rm -f "$CC_SETTINGS.tmp"
      echo >&2 "warning: could not disable Claude Code attribution; $CC_SETTINGS is not valid JSON."
    fi

    if [ -x ${brew} ] && ${brew} list --cask ${cask} >/dev/null 2>&1; then
      echo "Retiring the ${cask} cask in favour of the native install..."
      run ${brew} uninstall --cask ${cask} \
        || echo >&2 "warning: could not uninstall the ${cask} cask; run: brew uninstall --cask ${cask}"
    fi
  '';
}
