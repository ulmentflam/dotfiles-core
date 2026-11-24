#!/usr/bin/env bash
# `nb` builds the configuration from any directory. A consumer's build app may
# resolve `.#` and `./result` against the working directory (a system flake's
# usually does), so nb has to run it from inside the flake directory, and pass
# its arguments on. A stub `nix` on PATH records where and how it ran.
source "$(dirname "$0")/lib.sh"

alias_text=$(eval_raw '
  (f.homeConfigurations.aarch64-darwin.extendModules {
    modules = [ { dotfiles.repo.flakeDir = "$NB_FLAKE"; } ];
  }).config.programs.zsh.shellAliases.nb
') || fail "the nb alias did not evaluate"
echo "nb = $alias_text"

dir=$(scratch nb)
mkdir -p "$dir/bin" "$dir/flake" "$dir/elsewhere"
cat >"$dir/bin/nix" <<'STUB'
#!/bin/sh
{ echo "cwd=$(pwd -P)"; echo "args=$*"; } >"$NB_LOG"
STUB
chmod +x "$dir/bin/nix"

run() {
  NB_FLAKE="$dir/flake" NB_LOG="$dir/log" PATH="$dir/bin:$PATH" \
    zsh -f -c "alias nb=${alias_text@Q}
eval 'cd $dir/elsewhere && nb $* && print after=\$(pwd -P)'" 2>&1
}

out=$(run) || fail "nb failed: $out"
log=$(cat "$dir/log")
grep -qx "cwd=$dir/flake" <<<"$log" || fail "nb did not run from the flake directory: $log"
grep -qx "args=run .#build --" <<<"$log" || fail "nb ran something other than nix run .#build: $log"
grep -qx "after=$dir/elsewhere" <<<"$out" || fail "nb changed the shell's directory: $out"

out=$(run --show-trace) || fail "nb --show-trace failed: $out"
grep -qx "args=run .#build -- --show-trace" <"$dir/log" || fail "nb did not pass its arguments on: $(cat "$dir/log")"
echo "ok: nb runs .#build from the flake directory, from anywhere, and passes its arguments on"
