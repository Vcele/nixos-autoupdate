# Example: Server Configuration with GitLab

{ config, pkgs, ... }:

{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@gitlab.com/yourusername/server-config?ref=production";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = /etc/nixos/secrets/secrets.yaml;
    sshTestHost = "git@gitlab.com";
    
    schedule = "03:00";
    randomizedDelaySec = "2h";
    flags = [ "--refresh" "--no-write-lock-file" ];
    
    # Server-optimized scheduling
    cpuSchedulingPolicy = "idle";
    ioSchedulingClass = "idle";
  };
}
