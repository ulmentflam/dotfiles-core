# Placeholder identity for this flake's own homeConfigurations, which exist to
# be evaluated by the smoke tests. Nothing here is anyone's real identity.
{
  home = {
    username = "example";
    stateVersion = "25.05";
  };

  dotfiles = {
    user = {
      name = "Example User";
      email = "user@example.invalid";
    };
    repo.path = "~/dotfiles-core";
  };
}
