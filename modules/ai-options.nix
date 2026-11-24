# The skills and agents the AI-tool modules install. Declared apart from
# ai-files.nix so antigravity-cli.nix can read the skill list without also
# taking over the file links.
{ lib, ... }:

let
  agentDir =
    dir:
    lib.mapAttrs' (name: _: lib.nameValuePair name (dir + "/${name}")) (
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (builtins.readDir dir)
    );
in
{
  options.dotfiles.ai = {
    skills = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = ''
        Skills linked into Claude Code, OpenCode, Antigravity and Codex, as
        { <name> = <directory>; }. Build it with lib.mkSkills so third-party
        skills pass the review gate; homeModules.default sets this flake's set.
      '';
    };
    agents = {
      claude = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = agentDir ../agents/claude;
        defaultText = lib.literalMD "the TDD ensemble in `agents/claude/`";
        description = "Claude Code agents, { \"<name>.md\" = <file>; }, linked into ~/.claude/agents.";
      };
      opencode = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = agentDir ../agents/opencode;
        defaultText = lib.literalMD "the TDD ensemble in `agents/opencode/`";
        description = "OpenCode agents, linked into ~/.config/opencode/agents.";
      };
    };
  };
}
