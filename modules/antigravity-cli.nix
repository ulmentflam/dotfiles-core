{
  config,
  pkgs,
  lib,
  ...
}:
# Antigravity CLI (`agy`) via Google's native installer, matching how
# claude-code.nix and codex.nix handle Claude Code and Codex.
#
# Being a Home Manager module, every account that imports it gets both the
# CLI and its skill registration, with no per-user wiring in a host config.
let
  installer = "https://antigravity.google/cli/install.sh";
  installerDeps = lib.makeBinPath (import ./native-installer-deps.nix { inherit pkgs; });

  # Skill directories to register in settings.json: every installed skill
  # (dotfiles.ai.skills). The files themselves are linked into place by
  # ai-files.nix; this only tells the CLI to look there.
  skillPaths = map (skill: ".gemini/antigravity-cli/skills/${skill}") (
    builtins.attrNames config.dotfiles.ai.skills
  );
in
{
  # The installer targets ~/.local/bin, same as the other two.
  imports = [
    ./local-bin-path.nix
    ./ai-options.nix
  ];

  home.activation = {
    antigravityNative = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.local/bin/agy" ]; then
        echo "Installing Antigravity CLI (native)..."
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

        # Judge by the binary, not the exit status: these vendor scripts end
        # by trying to launch or configure a shell, which fails under
        # activation even when the install worked. See codex.nix.
        if [ -x "$HOME/.local/bin/agy" ]; then
          echo "Antigravity CLI installed."
        else
          echo >&2 "warning: Antigravity CLI install failed; rerun: curl -fsSL ${installer} | bash"
        fi
      fi
    '';

    # Merge our skill paths into whatever settings.json already holds, rather
    # than owning the file: the CLI writes its own keys there (auth, model
    # choice, MCP servers) and a managed symlink would fight it.
    # Paths under our skills directory are replaced wholesale, so a skill that
    # is renamed or removed here stops being registered; anything else the
    # user registered is kept.
    antigravitySkills = lib.hm.dag.entryAfter [ "antigravityNative" ] ''
      AG_DIR="$HOME/.gemini/antigravity-cli"
      AG_SETTINGS="$AG_DIR/settings.json"
      run ${pkgs.coreutils}/bin/mkdir -p "$AG_DIR"
      [ -f "$AG_SETTINGS" ] || echo '{}' > "$AG_SETTINGS"
      if ${pkgs.jq}/bin/jq --argjson skills '${builtins.toJSON skillPaths}' \
        '.skills = ([(.skills // [])[] | select(startswith(".gemini/antigravity-cli/skills/") | not)] + $skills | unique)' \
        "$AG_SETTINGS" > "$AG_SETTINGS.tmp"; then
        run ${pkgs.coreutils}/bin/mv "$AG_SETTINGS.tmp" "$AG_SETTINGS"
      else
        ${pkgs.coreutils}/bin/rm -f "$AG_SETTINGS.tmp"
        echo >&2 "warning: could not register Antigravity skills; $AG_SETTINGS is not valid JSON."
      fi
    '';
  };
}
