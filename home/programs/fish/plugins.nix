{ lib, pkgs }:

let
  bobthefish = {
    name = "theme-bobthefish";
    src = pkgs.fish-bobthefish-theme;
  };
in
{
  completions = {
    # keytool completions removed — package not available in flake inputs
    # Can be added manually later via a separate derivation if needed
  };

  theme = bobthefish;
  prompt = lib.readFile "${bobthefish.src}/fish_prompt.fish";
}
