# Links dotfiles.ai.skills into every AI tool and the agents into Claude Code
# and OpenCode (lib/ai-files.nix).
{ config, ... }:

let
  cfg = config.dotfiles.ai;
in
{
  imports = [ ./ai-options.nix ];

  home.file = import ../lib/ai-files.nix {
    inherit (cfg) skills;
    claudeAgents = cfg.agents.claude;
    opencodeAgents = cfg.agents.opencode;
  };
}
