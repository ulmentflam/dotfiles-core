#!/usr/bin/env bash
# The Brewfile renders from dotfiles.darwin.brewfile and brew bundle finds it;
# Nix GUI apps turn on copyApps. Linux ignores both.
source "$(dirname "$0")/lib.sh"

out=$(eval_raw '
  let
    mk = system: (f.homeConfigurations.${system}.extendModules {
      modules = [ ({ pkgs, ... }: {
        dotfiles.darwin = {
          brewfile = { enable = true; taps = [ "acme/tap" ]; brews = [ "mas" ]; casks = [ "ghostty" "maccy" "macshot-offline" "slack" "thaw" ]; };
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
  + "macshot=${d.home.activation.macshotPreferences.data or "unset"}\n"
  + "macshot-without-cask=${if (f.homeConfigurations.aarch64-darwin.config.home.activation ? macshotPreferences) then "on" else "off"}\n"
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
# MacShot Offline: Command-Shift-4 area and Command-Shift-3 screen (Carbon key
# codes 21 and 20, modifiers 768), CleanShot-style names, and macOS's own
# bindings for those keys (symbolic hotkeys 30 and 28) off, in the typed form
# the hotkey loader reads, then reloaded.
grep -q 'com.sw33tlie.macshot.offline hotkeyKeyCode -int 21' <<<"$out" || fail "MacShot area hotkey is not Command-Shift-4"
grep -q 'com.sw33tlie.macshot.offline hotkeyFullScreenKeyCode -int 20' <<<"$out" || fail "MacShot screen hotkey is not Command-Shift-3"
grep -q 'com.sw33tlie.macshot.offline hotkeyFullScreenModifiers -int 768' <<<"$out" || fail "MacShot screen hotkey modifiers are not Command-Shift"
# CleanShot's "Screenshot %t - %a %y-%m-%d at %H.%M.%S" with its @2x suffix,
# saved to ~/Desktop/screenshots like CleanShot's exportPath.
grep -q -- "filenameTemplate -string 'Screenshot {window} - {app} {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}@2x'" <<<"$out" || fail "MacShot screenshot names do not follow CleanShot's"
grep -q -- "filenameTemplateNoApp -string 'Screenshot {window} {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}@2x'" <<<"$out" || fail "MacShot names without an app do not drop ' - <app>'"
grep -q -- "recordingFilenameTemplate -string 'Screenshot {app} {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}'" <<<"$out" || fail "MacShot recording names do not follow CleanShot's"
grep -q -- "recordingFilenameTemplateNoApp -string 'Screenshot {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}'" <<<"$out" || fail "MacShot recording names without an app are not set"
grep -q 'want=/Users/example/Desktop/screenshots' <<<"$out" || fail "MacShot does not save to ~/Desktop/screenshots"
grep -q 'saveDirectoryBookmark' <<<"$out" || fail "a bookmark for another folder is not cleared when the folder changes"
grep -q -- "-dict-add 28 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>51</integer><integer>20</integer><integer>1179648</integer></array>" <<<"$out" || fail "macOS still owns Command-Shift-3"
grep -q -- "-dict-add 30 '<dict><key>enabled</key><false/>.*<integer>52</integer><integer>21</integer><integer>1179648</integer>" <<<"$out" || fail "macOS still owns Command-Shift-4"
grep -q 'activateSettings -u' <<<"$out" || fail "the shortcut change is not reloaded"
grep -qx 'macshot-without-cask=off' <<<"$out" || fail "MacShot preferences written without the macshot-offline cask"
echo "ok: MacShot Offline takes Command-Shift-3 and Command-Shift-4 from macOS"

# lib.macshot.preferences, the form a login script uses: no Home Manager
# `run`, the folder under the given home.
lib_out=$(eval_raw 'f.lib.macshot.preferences { homeDirectory = "/Users/example"; }') \
  || fail "lib.macshot.preferences did not evaluate"
grep -q "want=/Users/example/Desktop/screenshots" <<<"$lib_out" || fail "lib.macshot.preferences ignores homeDirectory"
grep -q "^/usr/bin/defaults write com.sw33tlie.macshot.offline filenameTemplate -string 'Screenshot {window} - {app} " <<<"$lib_out" \
  || fail "lib.macshot.preferences does not write CleanShot X's names"
! grep -q '^ *run ' <<<"$lib_out" || fail "lib.macshot.preferences adds Home Manager's run without a prefix"
echo "ok: lib.macshot.preferences renders for a login script"
