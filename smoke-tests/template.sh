#!/usr/bin/env bash
# `nix flake init -t .#overlay` produces a flake that evaluates against this
# checkout, under any username: nothing in it assumes whose machine it is.
source "$(dirname "$0")/lib.sh"

dir=$(scratch template)
cp -R templates/overlay/. "$dir/"
printf '%s\n' 'dotfiles-core smoke test copy of templates/overlay; safe to delete.' >"$dir/README.txt"
sed -i.bak -e 's/username = "CHANGE-ME";/username = "smokeuser";/' "$dir/home.nix" && rm "$dir/home.nix.bak"

eval_template() {
  local attr=$1
  shift
  "${NIX[@]}" eval --impure --raw --override-input dotfiles-core "path:$ROOT" \
    "path:${dir// /%20}#$attr" "$@" 2>"${SMOKE_ERR:-/dev/null}"
}

drv=$(eval_template 'homeConfigurations.work.activationPackage.drvPath') || fail "the template does not evaluate"
echo "drv=$drv"
home=$(eval_template 'homeConfigurations.work.config.home.homeDirectory')
[[ $home == /Users/smokeuser ]] || fail "home directory is $home, not /Users/smokeuser"
tv=$(eval_template 'homeConfigurations.work.config.dotfiles.toolVersions')
[[ $tv == /Users/smokeuser/dotfiles-work/.tool-versions ]] || fail ".tool-versions path is $tv"
brewfile=$(eval_template 'homeConfigurations.work.config.home.file.".config/homebrew/Brewfile".text')
grep -qx 'cask "ghostty"' <<<"$brewfile" || fail "template Brewfile lacks its casks"
grep -qx 'cask "cursor"' <<<"$brewfile" || fail "template Brewfile lacks Cursor"
for cask in maccy thaw; do
  grep -qx "cask \"$cask\"" <<<"$brewfile" || fail "template Brewfile lacks $cask"
done
eval_template 'homeConfigurations.work.config.home.activation.maccyPreferences.data' | grep -q pasteByDefault \
  || fail "template does not set Maccy's preferences"
pkgs=$(eval_template 'homeConfigurations.work.config.home.packages' --apply 'ps: builtins.concatStringsSep " " (map (p: p.pname or p.name) ps)')
for dropped in tor brev-cli age-plugin-yubikey libfido2; do
  grep -qw "$dropped" <<<"$pkgs" && fail "template still installs $dropped"
done
grep -qw mise <<<"$pkgs" || fail "template does not install mise"
grep -qw colima <<<"$pkgs" || fail "template lost colima"
for app in build build-switch rollback; do
  eval_template "apps.aarch64-darwin.$app.program" >/dev/null || fail "template app $app does not resolve"
done
echo "ok: template evaluates as smokeuser; home, .tool-versions, Brewfile (with Cursor), packages (mise; no tor, brev-cli or YubiKey tools) and apps follow"
