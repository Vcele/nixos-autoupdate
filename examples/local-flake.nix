# Example: Local Flake Configuration (Simplest)

{ config, pkgs, ... }:

{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    schedule = "daily";
  };
}
