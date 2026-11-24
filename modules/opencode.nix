# OpenCode defaults merged into ~/.config/opencode/opencode.json at activation.
#
# Merged rather than linked: OpenCode writes its own keys there (auth, model
# picks) and a read-only store link would fight it. On a conflict the existing
# file wins, so a hand edit survives a rebuild. An invalid file is left exactly
# as it is and reported.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.ai.opencode;
in
{
  options.dotfiles.ai.opencode.settings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    example = {
      model = "anthropic/claude-sonnet-5-5";
      autoupdate = "notify";
    };
    description = "opencode.json defaults. Empty leaves the file alone.";
  };

  config.home.activation.opencodeSettings = lib.mkIf (cfg.settings != { }) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      OPENCODE_DIR="$HOME/.config/opencode"
      SETTINGS_FILE="$OPENCODE_DIR/opencode.json"
      BASE_CONFIG=${lib.escapeShellArg (builtins.toJSON cfg.settings)}
      run ${pkgs.coreutils}/bin/mkdir -p "$OPENCODE_DIR"
      if [ -f "$SETTINGS_FILE" ]; then
        if ${pkgs.jq}/bin/jq -s '.[0] * .[1]' <(echo "$BASE_CONFIG") "$SETTINGS_FILE" \
             > "$SETTINGS_FILE.tmp" 2>/dev/null; then
          run ${pkgs.coreutils}/bin/mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        else
          ${pkgs.coreutils}/bin/rm -f "$SETTINGS_FILE.tmp"
          echo >&2 "warning: $SETTINGS_FILE is not valid JSON, so the OpenCode defaults were not merged."
          echo >&2 "         Fix it (jq . \"$SETTINGS_FILE\" shows where) and switch again."
        fi
      else
        echo "$BASE_CONFIG" | ${pkgs.jq}/bin/jq '.' > "$SETTINGS_FILE"
      fi
    ''
  );
}
