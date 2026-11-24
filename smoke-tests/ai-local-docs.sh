#!/usr/bin/env bash
# The generated instruction file: one document under all six tool paths,
# carrying the live aliases, the configured programs and the declared
# packages, plus whatever prose the consumer supplies.
source "$(dirname "$0")/lib.sh"

for system in aarch64-darwin x86_64-linux; do
  echo "==> $system"
  out=$(eval_raw "
    let
      c = (f.homeConfigurations.$system.extendModules {
        modules = [ { dotfiles.ai.docs.prose = \"## My Rules\\n\\n- smoke-prose\\n\"; } ];
      }).config;
      t = p: c.home.file.\${p}.text;
      paths = [ \"CLAUDE.local.md\" \"AGENTS.local.md\" \"GEMINI.local.md\" \".claude/CLAUDE.md\" \".codex/AGENTS.md\" \".gemini/GEMINI.md\" ];
      same = builtins.all (p: t p == t \"CLAUDE.local.md\") paths;
    in
    (if same then \"same=true\\n\" else \"same=false\\n\") + t \"CLAUDE.local.md\"
  ") || fail "$system doc did not evaluate"
  grep -qx 'same=true' <<<"$out" || fail "$system tool paths carry different text"
  grep -q '^# Local machine profile' <<<"$out" || fail "$system doc has no title"
  grep -q 'smoke-prose' <<<"$out" || fail "$system doc drops dotfiles.ai.docs.prose"
  grep -q '^yolo ' <<<"$out" || fail "$system doc does not list the aliases"
  grep -q '`zsh`' <<<"$out" || fail "$system doc does not list configured programs"
  grep -q '^- `ripgrep`\|^- `jq`' <<<"$out" || fail "$system doc does not list packages"
  grep -q '—' <<<"$out" && fail "$system doc contains an em dash"
  echo "ok"
done
