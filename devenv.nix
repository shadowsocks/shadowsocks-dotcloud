{ pkgs, ... }:

{
  languages.javascript.enable = true;
  languages.javascript.package = pkgs.bun;
}
