#!/usr/bin/env bash
# `nix flake init -t .#overlay` produces a flake that evaluates against this
# checkout, under any username: nothing in it assumes whose machine it is.
source "$(dirname "$0")/lib.sh"

dir=$(scratch template)
cp -R templates/overlay/. "$dir/"
printf '%s\n' 'dotfiles-core smoke test copy of templates/overlay; safe to delete.' >"$dir/README.txt"
sed -i.bak -e 's/username = "CHANGE-ME";/username = "smokeuser";/' "$dir/home.nix" && rm "$dir/home.nix.bak"

eval_template() {
  "${NIX[@]}" eval --impure --raw --override-input dotfiles-core "path:$ROOT" \
    "path:${dir// /%20}#$1" 2>"${SMOKE_ERR:-/dev/null}"
}

drv=$(eval_template 'homeConfigurations.work.activationPackage.drvPath') || fail "the template does not evaluate"
echo "drv=$drv"
home=$(eval_template 'homeConfigurations.work.config.home.homeDirectory')
[[ $home == /Users/smokeuser ]] || fail "home directory is $home, not /Users/smokeuser"
tv=$(eval_template 'homeConfigurations.work.config.dotfiles.toolVersions')
[[ $tv == /Users/smokeuser/dotfiles-work/.tool-versions ]] || fail ".tool-versions path is $tv"
brewfile=$(eval_template 'homeConfigurations.work.config.home.file.".config/homebrew/Brewfile".text')
grep -qx 'cask "ghostty"' <<<"$brewfile" || fail "template Brewfile lacks its casks"
for app in build build-switch rollback; do
  eval_template "apps.aarch64-darwin.$app.program" >/dev/null || fail "template app $app does not resolve"
done
echo "ok: template evaluates as smokeuser; home, .tool-versions, Brewfile and apps follow"
