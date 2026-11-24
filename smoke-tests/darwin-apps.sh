#!/usr/bin/env bash
# The Brewfile renders from dotfiles.darwin.brewfile and brew bundle finds it;
# Nix GUI apps turn on copyApps. Linux ignores both.
source "$(dirname "$0")/lib.sh"

out=$(eval_raw '
  let
    mk = system: (f.homeConfigurations.${system}.extendModules {
      modules = [ ({ pkgs, ... }: {
        dotfiles.darwin = {
          brewfile = { enable = true; taps = [ "acme/tap" ]; brews = [ "mas" ]; casks = [ "ghostty" "maccy" "slack" "thaw" ]; };
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
  + "maccy=${d.home.activation.maccyPreferences.data or "unset"}\n"
  + "touchid-check=${if d.home.activation ? touchIdSudoCheck then "on" else "off"}\n"
  + "maccy-without-cask=${if (f.homeConfigurations.aarch64-darwin.config.home.activation ? maccyPreferences) then "on" else "off"}\n"
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
grep -q 'KeyboardShortcuts_popup' <<<"$out" || fail "Maccy shortcut not written"
grep -q '{"carbonKeyCode":9,"carbonModifiers":768}' <<<"$out" || fail "Maccy shortcut is not Command-Shift-V"
grep -q 'pasteByDefault -bool true' <<<"$out" || fail "Maccy does not paste on select"
grep -q 'defaults import' <<<"$out" && fail "Maccy preferences replace the whole domain"
grep -qx 'maccy-without-cask=off' <<<"$out" || fail "Maccy preferences written without the maccy cask"
grep -qx 'touchid-check=on' <<<"$out" || fail "no Touch ID sudo check on macOS"
echo "ok: Brewfile, HOMEBREW_BUNDLE_FILE, copyApps, nbs, Maccy preferences and the Touch ID check wired; Linux untouched"
