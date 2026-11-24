# Static skills and agents for every AI tool, as home.file entries.
# Credentials, conversation history and memory stay per account.
#
# `skills` is { <name> = <directory>; } (lib.mkSkills); `claudeAgents` and
# `opencodeAgents` are { <file name> = <path>; }. OpenCode parses `tools:` as a
# permissions record rather than a comma-separated string, so its agents are
# separate files from Claude Code's even when the bodies match.
{
  skills,
  claudeAgents ? { },
  opencodeAgents ? { },
}:
let
  # Codex reads user skills from ~/.agents/skills.
  skillDirs = [
    ".claude/skills"
    ".config/opencode/skills"
    ".gemini/antigravity-cli/skills"
    ".agents/skills"
  ];

  # Each skill directory is linked file by file (`recursive`), so a skill
  # stays a real directory of symlinks. Linking the directory itself would
  # collide with that layout on a machine that had it, and leave
  # `<skill>.backup` copies the tools would load.
  skillFiles = builtins.listToAttrs (
    builtins.concatMap (
      dir:
      map (skill: {
        name = "${dir}/${skill}";
        value = {
          source = skills.${skill};
          recursive = true;
        };
      }) (builtins.attrNames skills)
    ) skillDirs
  );

  agentFiles =
    dir: agents:
    builtins.listToAttrs (
      map (name: {
        name = "${dir}/${name}";
        value.source = agents.${name};
      }) (builtins.attrNames agents)
    );
in
skillFiles
// agentFiles ".claude/agents" claudeAgents
// agentFiles ".config/opencode/agents" opencodeAgents
