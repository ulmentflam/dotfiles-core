{ lib, ... }:
# Keep ~/.local/bin on PATH for *every* zsh, not just the first one in an
# environment.
#
# `home.sessionPath` alone is not enough. It is emitted into
# hm-session-vars.sh, which home-manager guards with __HM_SESS_VARS_SOURCED so
# the file runs once per environment. Any process that exports that guard and
# then rebuilds PATH without ~/.local/bin poisons every descendant shell: the
# guard reports "already sourced", so the entry is never re-added and nothing
# downstream can recover it.
#
# cmux does exactly that. Inside a cmux session the guard is set and
# ~/.local/bin is absent, so `cyolo` failed with "codex not found in PATH"
# (the cmux shim strips itself from PATH and re-execs `codex`) while a clean
# login shell resolved the very same binary.
#
# .zshenv runs for every zsh invocation, interactive or not, login or not, so
# prepend there as well. The case guard makes it idempotent, so this is a
# no-op whenever sessionPath already did the job.
#
# Imported by claude-code.nix and codex.nix, the two modules that put binaries
# in ~/.local/bin. Module imports dedupe, so pulling it in from both is fine.
{
  home.sessionPath = lib.mkBefore [ "$HOME/.local/bin" ];

  programs.zsh.envExtra = lib.mkBefore ''
    # Native agent binaries (claude, codex) live here. Idempotent: see
    # modules/shared/local-bin-path.nix for why sessionPath is not sufficient.
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
  '';
}
