# MacShot Offline's preferences: the screenshot shortcuts, CleanShot X's file
# names and its folder. Shared by modules/darwin-apps.nix (Home Manager
# activation) and by consumers that apply them elsewhere, such as a login
# script for an account Home Manager activates from outside its session.
#
# MacShot is sandboxed, but cfprefsd routes a plain `defaults write` of its
# bundle id into its container, before first launch and after.
{ lib }:

rec {
  domain = "com.sw33tlie.macshot.offline";

  defaultDirectory = "Desktop/screenshots";

  defaultFilenames = {
    # CleanShot X's "Screenshot %t - %a %y-%m-%d at %H.%M.%S" with its @2x
    # Retina suffix. MacShot saves at full Retina resolution (downscaleRetina
    # off), but cannot tell a 1x display apart, so a capture there is labelled
    # @2x too. {app} and the {HH} {mm} {ss} parts need MacShot 4.4.
    filenameTemplate = "Screenshot {window} - {app} {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}@2x";
    # Used instead when no app is known (a whole-display capture), the way
    # CleanShot drops " - %a".
    filenameTemplateNoApp = "Screenshot {window} {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}@2x";
    # Recordings carry no window title, and CleanShot adds no @2x to them.
    recordingFilenameTemplate = "Screenshot {app} {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}";
    recordingFilenameTemplateNoApp = "Screenshot {yyyy}-{MM}-{dd} at {HH}.{mm}.{ss}";
  };

  # Shell lines that apply the preferences. `directory` is relative to
  # `homeDirectory` (null leaves the folder alone); `prefix` goes before each
  # command that changes something, for Home Manager's `run `.
  preferences =
    {
      homeDirectory,
      directory ? defaultDirectory,
      filenames ? defaultFilenames,
      prefix ? "",
    }:
    ''
      # Command-Shift-4 for an area, Command-Shift-3 for the screen. Carbon
      # virtual key codes (kVK_ANSI_4 = 21, kVK_ANSI_3 = 20) and modifiers
      # (cmdKey | shiftKey = 768), the form MacShot's HotkeyManager reads.
      # Clearing hotkeyDisabled_<slot> undoes a "None" chosen in its settings.
      ${prefix}/usr/bin/defaults write ${domain} hotkeyKeyCode -int 21
      ${prefix}/usr/bin/defaults write ${domain} hotkeyModifiers -int 768
      ${prefix}/usr/bin/defaults write ${domain} hotkeyFullScreenKeyCode -int 20
      ${prefix}/usr/bin/defaults write ${domain} hotkeyFullScreenModifiers -int 768
      ${prefix}/usr/bin/defaults delete ${domain} hotkeyDisabled_1 2>/dev/null || true
      ${prefix}/usr/bin/defaults delete ${domain} hotkeyDisabled_2 2>/dev/null || true

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          key: template:
          "${prefix}/usr/bin/defaults write ${domain} ${key} -string ${lib.escapeShellArg template}"
        ) filenames
      )}
    ''
    + lib.optionalString (directory != null) ''

      # The folder, as the path MacShot shows and offers in its folder panel.
      # Its saves go through a security-scoped bookmark only the app can
      # create, so when the path changes, drop a bookmark for the old folder:
      # MacShot then asks once, starting here.
      want=${lib.escapeShellArg "${homeDirectory}/${directory}"}
      ${prefix}mkdir -p "$want"
      if [ "$(/usr/bin/defaults read ${domain} saveDirectory 2>/dev/null)" != "$want" ]; then
        ${prefix}/usr/bin/defaults write ${domain} saveDirectory -string "$want"
        ${prefix}/usr/bin/defaults delete ${domain} saveDirectoryBookmark 2>/dev/null || true
      fi
    '';
}
