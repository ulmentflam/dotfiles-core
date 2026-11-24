{ pkgs, lib, ... }:
# Codex via OpenAI's native installer, not Nixpkgs.
#
# Nixpkgs releases trail Codex releases, so a Nix-managed binary can shadow
# the current standalone binary in ~/.local/bin. The native installation under
# ~/.codex/packages/standalone can update without a system rebuild.
#
# Home Manager only bootstraps the installation when the binary is missing.
let
  installer = "https://chatgpt.com/codex/install.sh";
  installerDeps = lib.makeBinPath (import ./native-installer-deps.nix { inherit pkgs; });
in
{
  # Keep native agent binaries ahead of packages from the Nix profile.
  imports = [ ./local-bin-path.nix ];

  home.activation.codexNative = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "$HOME/.local/bin/codex" ]; then
      echo "Installing Codex (native)..."
      # ~/.local/bin leads the PATH so the installer's own check sees the
      # directory already configured. Without it the script tries to append a
      # PATH export to ~/.zshrc, which home-manager owns as a read-only store
      # symlink, and emits a wall of warnings about a temp file it cannot
      # create under /nix/store. It is only ever a warning (the binary still
      # lands), but it is alarming and it is avoidable: local-bin-path.nix
      # genuinely does put the directory on PATH for every shell.
      run ${pkgs.curl}/bin/curl -fsSL ${installer} \
        | PATH="$HOME/.local/bin:${installerDeps}:$PATH" ${pkgs.bash}/bin/bash \
        || true

      # Judge by the binary, not the exit status. The vendor script's last
      # step tries to launch the CLI interactively and returns non-zero under
      # activation even when the install worked, so keying the warning off
      # `||` reports a failure that did not happen. The reverse case is what
      # hid this bug for so long, so be explicit in both directions.
      if [ -x "$HOME/.local/bin/codex" ]; then
        echo "Codex installed."
      else
        echo >&2 "warning: Codex native install failed; rerun: curl -fsSL ${installer} | sh"
      fi
    fi
  '';
}
