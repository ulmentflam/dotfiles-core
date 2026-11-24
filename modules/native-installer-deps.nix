# Tools the vendor install scripts (Claude Code, Codex, Antigravity) shell out
# to by bare name.
#
# Home-manager runs activation with a minimal PATH carrying almost none of
# these, and every one of those scripts ends in `|| warning`, so a missing tool
# produced a warning that scrolled past in a long `nbs` while activation
# reported success. That is how the Claude Code and Codex steps managed to be
# silent no-ops for as long as they existed: first `tar`, then `shasum`.
#
# One list, three consumers, so a gap found for one installer is closed for
# all of them. Derived by enumerating every bare command each script invokes,
# not by grepping for a single idiom such as `command -v` (that is what missed
# `shasum`, which the Darwin checksum branch calls outright).
#
# wget is deliberately absent: the scripts reach for it only when curl is
# missing, and curl is here.
{ pkgs }:

[
  pkgs.coreutils # install, chmod, mkdir, rm, cut, uname, sha256sum
  pkgs.curl
  pkgs.file
  pkgs.gawk
  pkgs.gnugrep
  pkgs.gnused
  pkgs.gnutar
  pkgs.gzip
  pkgs.jq
  pkgs.openssl
  pkgs.perl # shasum; coreutils' sha256sum covers the linux branch only
  pkgs.unzip
  pkgs.xz
  pkgs.zstd
]
