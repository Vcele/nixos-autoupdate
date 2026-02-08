# Example: Desktop Configuration with Git Repository

{ config, pkgs, ... }:

{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@github.com/yourusername/nixos-config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets/secrets.yaml;
    sshTestHost = "git@github.com";
    
    # Notifications
    notification = {
      enable = true;
      urgency = "normal";
    };
    
    schedule = "04:00";
    randomizedDelaySec = "1h";
  };
}
