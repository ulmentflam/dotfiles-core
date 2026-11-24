#!/usr/bin/env bash
# `about` runs in zsh and prints every entry intact, including ones with a
# single quote (the core's own Brewfile entry has one). The entries are
# spliced into a single-quoted string, so an unescaped quote would end it.
source "$(dirname "$0")/lib.sh"

render() {
  eval_raw "
    (f.homeConfigurations.aarch64-darwin.extendModules {
      modules = [ { $1 } ];
    }).config.programs.zsh.initContent
  " || fail "initContent did not evaluate"
}
# The core's own entries, with a Brewfile so its entry is listed.
default_init=$(render 'dotfiles.darwin.brewfile = { enable = true; casks = [ "ghostty" ]; };')
# A consumer's own entry, quotes and a dollar sign included.
custom_init=$(render 'dotfiles.zsh.about.entries = [ "tool|quoted|it'"'"'s a '"'"'quoted'"'"' entry; $HOME stays literal" ];')

dir=$(scratch about)
# The function body, from `about() {` to the brace closing it at the same indent.
extract() {
  awk '
    !on && /^[[:space:]]*about\(\) \{$/ { on = 1; match($0, /^[[:space:]]*/); indent = substr($0, 1, RLENGTH) }
    on { print }
    on && $0 == indent "}" { exit }
  ' >"$dir/$1.zsh"
  [ -s "$dir/$1.zsh" ] || fail "about() not found in the $1 initContent"
}
extract default <<<"$default_init"
extract custom <<<"$custom_init"
run() { zsh -f -c "source '$dir/$1.zsh' && about ${2:-}" 2>&1; }

out=$(run default) || fail "about failed: $out"
grep -q "brew bundle  *install and upgrade the Brewfile's apps" <<<"$out" || fail "the Brewfile entry lost its apostrophe or broke the list"
grep -q "nbs  *FN: build-switch" <<<"$out" || fail "entries after the Brewfile one are missing"
out=$(run default brewfile) || fail "about <pattern> failed: $out"
grep -q "brew bundle" <<<"$out" || fail "about <pattern> does not find the Brewfile entry"
out=$(run custom) || fail "about failed: $out"
grep -q "it's a 'quoted' entry; \$HOME stays literal" <<<"$out" || fail "an entry with single quotes is not printed intact"
echo "ok: about prints entries with single quotes intact, filtered or not"
