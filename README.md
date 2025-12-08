# nixos-autoupdate

## old configuration in default.nix (please overwrite)

Auto Update Module
This module provides automatic NixOS system updates by pulling from a git repository using SSH authentication. It's designed to work with sops-nix for secure SSH key management.

Features
Automatic system updates from a git repository
SSH key management via sops-nix
Configurable update schedule
Low-priority CPU and I/O scheduling to minimize system impact
Automatic retry on failure
Pre-update SSH connection test
Requirements
sops-nix configured for your host (already wired in this repo via flake)
SSH key with access to your git repository
Git repository stored in secrets/secrets.yaml (not system-specific secrets)
Configuration
1. Generate SSH Key for Auto-Updates
Generate a dedicated SSH key for the auto-update service:

ssh-keygen -t ed25519 -f ./autoupgrade_key -C "nixos-autoupgrade"
2. Add SSH Key to Your Git Server
Add the public key (autoupgrade_key.pub) to your git server (e.g., soft-serve, GitHub, GitLab).

For soft-serve:

ssh soft-serve -p 23231 key add autoupgrade < autoupgrade_key.pub
3. Add SSH Private Key to SOPS
Add the private key to secrets/secrets.yaml:

autoupgrade:
  ssh_key: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    (paste your private key here)
    -----END OPENSSH PRIVATE KEY-----
Then encrypt it with sops:

sops -e -i secrets/secrets.yaml
4. Enable Auto-Update in Your System Configuration
Add the following to your system's default.nix:

{
  # Enable automatic updates
  system.autoupdate = {
    enable = true;
    repository = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
    sshKeySops = "autoupgrade/ssh_key";
  };
}
Options
system.autoupdate.enable
Type: boolean
Default: false
Description: Enable automatic system updates
system.autoupdate.repository
Type: string
Example: "git+ssh://soft-serve:23231/geek/nixos?ref=flake"
Description: The git repository URL to pull updates from
system.autoupdate.sshKeySops
Type: string
Example: "autoupgrade/ssh_key"
Description: Sops secret key for the SSH private key used to access the git repository
system.autoupdate.sopsFile
Type: path
Default: ../../../secrets/secrets.yaml
Example: ../../../secrets/vcloud_oracle/secrets.yaml
Description: Path to the sops file containing the SSH key secret
system.autoupdate.enablePreStartTest
Type: boolean
Default: true
Description: Enable SSH connection test before attempting upgrade
system.autoupdate.sshTestHost
Type: string or null
Default: null
Example: "soft-serve -p 23231 info" or "git@github.com"
Description: SSH test command to verify connectivity before upgrade (null to disable)
system.autoupdate.flags
Type: list of strings
Default: [ "--refresh" ]
Example: [ "--refresh" "--no-write-lock-file" ]
Description: Additional flags to pass to nixos-rebuild
system.autoupdate.randomizedDelaySec
Type: string
Default: "45m"
Example: "1h"
Description: Maximum random delay before starting the update
system.autoupdate.schedule
Type: string
Default: "daily"
Example: "04:00" or "weekly" or "Mon,Fri 10:00"
Description: When to run automatic updates (systemd timer format)
system.autoupdate.cpuSchedulingPolicy
Type: string
Default: "idle"
Example: "batch"
Description: CPU scheduling policy for the update process
system.autoupdate.ioSchedulingClass
Type: string
Default: "idle"
Example: "best-effort"
Description: IO scheduling class for the update process
Example Configurations
Minimal Configuration (uses shared secrets/secrets.yaml)
system.autoupdate = {
  enable = true;
  repository = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
  sshKeySops = "autoupgrade/ssh_key";
  # sopsFile defaults to ../../../secrets/secrets.yaml
};
Custom Schedule and Flags
system.autoupdate = {
  enable = true;
  repository = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
  sshKeySops = "autoupgrade/ssh_key";
  schedule = "04:00";  # Run at 4 AM
  flags = [ "--refresh" "--no-write-lock-file" ];
  randomizedDelaySec = "30m";
  sshTestHost = "soft-serve -p 23231 info";
};
GitHub/GitLab Repository
system.autoupdate = {
  enable = true;
  repository = "git+ssh://git@github.com/yourusername/nixos-config?ref=main";
  sshKeySops = "autoupgrade/ssh_key";
  sshTestHost = "git@github.com";
};
Using System-Specific Secrets File
system.autoupdate = {
  enable = true;
  repository = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
  sshKeySops = "autoupgrade/ssh_key";
  sopsFile = ../../../secrets/vcloud_oracle/secrets.yaml;  # Override to use system-specific secrets
};
How It Works
The systemd timer triggers at the configured schedule
A random delay (up to randomizedDelaySec) is applied to prevent simultaneous updates on multiple systems
The service runs a pre-start check to verify SSH connectivity to the git server
If the connection succeeds, nixos-rebuild pulls the latest configuration and rebuilds the system
If the update fails, the service automatically retries (up to 6 times within 120 seconds)
The entire process runs with low CPU and I/O priority to minimize system impact
Monitoring
Check the status of auto-updates:

systemctl status nixos-upgrade.service
View recent update logs:

journalctl -u nixos-upgrade.service -n 50
Check when the next update is scheduled:

systemctl list-timers nixos-upgrade.timer
Troubleshooting
Updates not running
Check if the module is enabled: system.autoupdate.enable = true
Verify the timer is active: systemctl status nixos-upgrade.timer
Check the service logs: journalctl -u nixos-upgrade.service
SSH connection failures
Verify the SSH key is correctly decrypted: ls -la /run/secrets/
Test the SSH connection manually: ssh -i /run/secrets/<your-key> soft-serve -p 23231 info
Ensure the public key is added to your git server
Permission errors
Verify the secret has correct permissions (600, owned by root)
Check sops configuration in your system
Security Considerations
The SSH key is stored encrypted in secrets/secrets.yaml
The decrypted key is only accessible to root (mode 0600)
Use a dedicated SSH key (not your personal key) for auto-updates
The key can be easily revoked if compromised
Updates only run when a "clean" git revision is detected (not on dirty working trees)
