{ pkgs, ... }:

{
  languages.javascript.enable = true;
  languages.javascript.package = pkgs.bun;
  pre-commit.hooks = {
    prettier.enable = true;
  };
}
