#!/usr/bin/env bash
# The Brewfile renders from dotfiles.darwin.brewfile and brew bundle finds it;
# Nix GUI apps turn on copyApps. Linux ignores both.
source "$(dirname "$0")/lib.sh"

out=$(eval_raw '
  let
    mk = system: (f.homeConfigurations.${system}.extendModules {
      modules = [ ({ pkgs, ... }: {
        dotfiles.darwin = {
          brewfile = { enable = true; taps = [ "acme/tap" ]; brews = [ "mas" ]; casks = [ "ghostty" "slack" ]; };
          apps = [ pkgs.hello ];
        };
      }) ];
    }).config;
    d = mk "aarch64-darwin";
    l = mk "x86_64-linux";
  in
  "${d.home.file.".config/homebrew/Brewfile".text}"
  + "bundle-file=${d.home.sessionVariables.HOMEBREW_BUNDLE_FILE}\n"
  + "copyapps=${if d.targets.darwin.copyApps.enable then "on" else "off"}\n"
  + "homebrew-path=${if d.dotfiles.homebrew.enable then "on" else "off"}\n"
  + "nbs-runs-bundle=${if builtins.match ".*brew bundle.*" d.programs.zsh.initContent != null then "yes" else "no"}\n"
  + "linux-brewfile=${if l.home.file ? ".config/homebrew/Brewfile" then "yes" else "no"}\n"
') || fail "darwin-apps configuration did not evaluate"
echo "$out"
grep -qx 'tap "acme/tap"' <<<"$out" || fail "tap missing from Brewfile"
grep -qx 'brew "mas"' <<<"$out" || fail "formula missing from Brewfile"
grep -qx 'cask "ghostty"' <<<"$out" || fail "cask missing from Brewfile"
grep -qx 'bundle-file=/Users/example/.config/homebrew/Brewfile' <<<"$out" || fail "HOMEBREW_BUNDLE_FILE does not point at the Brewfile"
grep -qx 'copyapps=on' <<<"$out" || fail "darwin.apps does not enable copyApps"
grep -qx 'homebrew-path=on' <<<"$out" || fail "a Brewfile does not put Homebrew on PATH"
grep -qx 'nbs-runs-bundle=yes' <<<"$out" || fail "nbs does not run brew bundle"
grep -qx 'linux-brewfile=no' <<<"$out" || fail "Linux writes a Brewfile"
echo "ok: Brewfile, HOMEBREW_BUNDLE_FILE, copyApps and nbs wired; Linux untouched"
