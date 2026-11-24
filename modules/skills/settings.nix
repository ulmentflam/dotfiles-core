# Environment the installed third-party skills read, applied to every account
# that installs them. Each setting answers a finding in reviews/<name>.md.
_: {
  home.sessionVariables = {
    # superpowers' brainstorming companion embeds a primeradiant.com logo
    # tagged with the installed version on every page it serves, which the
    # code calls telemetry and the skill never discloses (reviews/superpowers.md).
    SUPERPOWERS_DISABLE_TELEMETRY = "1";
  };
}
