# nixos-autoupdate

NixOS Auto-Update Module - Automatic system updates with advanced features for laptops and desktops.

## Features

✨ **Core Features:**
- Automatic system updates from git repositories or local flakes
- SSH key management via sops-nix (optional)
- Configurable update schedule via systemd timers
- Low-priority CPU and I/O scheduling to minimize system impact
- Automatic retry on failure
- Pre-update SSH connection test

🔋 **Laptop-Specific Features:**
- Wake-from-sleep support using RTC wake alarms
- AC power detection (only update when plugged in)
- Automatic suspend after update if no users logged in

🔔 **User Notifications:**
- Desktop notifications after successful updates
- Notifications shown on next user login
- Configurable urgency and timeout

📦 **Flexible Deployment:**
- Support for git repositories (SSH/HTTPS)
- Support for local (non-git) flakes
- Flake-based for easy integration into NixOS configurations

## Requirements

### For Git-based Updates (Optional)
- sops-nix configured for your host (if using SSH authentication)
- SSH key with access to your git repository
- Git repository information

### For Local Flake Updates
- No special requirements, works out of the box

### For Wake-up Support
- System with RTC wake alarm support (`/sys/class/rtc/rtc0/wakealarm`)
- BIOS/UEFI configured to wake from RTC alarm

### For Notifications
- Desktop environment with D-Bus support
- Graphical session

## Installation

### Using Flakes (Recommended)

1. Add this repository to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-autoupdate.url = "github:Vcele/nixos-autoupdate";
    # ... your other inputs
  };

  outputs = { self, nixpkgs, nixos-autoupdate, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-autoupdate.nixosModules.default
        # ... your other modules
      ];
    };
  };
}
```

2. Configure the module in your system configuration (see Configuration examples below)

### Without Flakes

If you're not using flakes, you can import the module directly:

```nix
{ config, pkgs, ... }:
{
  imports = [
    (builtins.fetchGit {
      url = "https://github.com/Vcele/nixos-autoupdate";
      ref = "main";
    } + "/module.nix")
  ];
  
  # ... your configuration
}
```

## Configuration

### Basic Examples

#### 1. Local Flake (Simplest Setup)

Update from your local system's flake configuration:

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    schedule = "daily";  # Update daily
  };
}
```

#### 2. Git Repository with SSH

```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@github.com/yourusername/nixos-config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets/secrets.yaml;
    sshTestHost = "git@github.com";
    schedule = "04:00";  # Run at 4 AM
  };
}
```

#### 3. Laptop with Wake-up and AC Power

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    
    # Only update when on AC power
    onlyOnACPower = true;
    
    # Wake up from sleep to perform updates
    wakeup = {
      enable = true;
      wakeupTime = "03:55";  # Wake 5 minutes before update
      autoSuspendAfter = true;  # Suspend again if no users logged in
    };
    
    # Notify user about updates
    notification = {
      enable = true;
      urgency = "normal";
      timeout = 30000;  # 30 seconds
    };
    
    schedule = "04:00";  # Update at 4 AM
  };
}
```

#### 4. Full-Featured Configuration

```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ../../../secrets/secrets.yaml;
    
    # Schedule and timing
    schedule = "04:00";
    randomizedDelaySec = "30m";
    
    # Laptop features
    onlyOnACPower = true;
    wakeup = {
      enable = true;
      wakeupTime = "03:55";
      autoSuspendAfter = true;
    };
    
    # Notifications
    notification = {
      enable = true;
      urgency = "normal";
      timeout = 30000;
    };
    
    # Additional options
    flags = [ "--refresh" "--no-write-lock-file" ];
    cpuSchedulingPolicy = "idle";
    ioSchedulingClass = "idle";
    enablePreStartTest = true;
    sshTestHost = "soft-serve -p 23231 info";
  };
}
```

## Configuration Options

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable automatic system updates |
| `flake` | string | `null` | Flake URL (git+ssh://, https://, path:, or local path) |
| `localFlake` | bool | `false` | Use local (non-git) flake, disables git-specific checks |
| `schedule` | string | `"daily"` | When to run updates (systemd timer format, e.g., "04:00", "daily", "Mon,Fri 10:00") |
| `randomizedDelaySec` | string | `"45m"` | Maximum random delay before starting update |
| `flags` | list | `["--refresh"]` | Additional flags for nixos-rebuild |

### SSH Options (for git+ssh repositories)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `sshKeySops` | string | `null` | Sops secret key for SSH private key |
| `sopsFile` | path | `null` | Path to sops file containing SSH key |
| `enablePreStartTest` | bool | `true` | Test SSH connection before update |
| `sshTestHost` | string | `null` | SSH test command (e.g., "git@github.com") |

### Laptop Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `onlyOnACPower` | bool | `false` | Only update when connected to AC power |
| `wakeup.enable` | bool | `false` | Enable wake-from-sleep for updates |
| `wakeup.wakeupTime` | string | `"03:55"` | Time to wake up (HH:MM format) |
| `wakeup.autoSuspendAfter` | bool | `true` | Suspend after update if no users logged in |

### Notification Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `notification.enable` | bool | `false` | Enable desktop notifications |
| `notification.urgency` | enum | `"normal"` | Urgency level: "low", "normal", or "critical" |
| `notification.timeout` | int | `30000` | Notification timeout in milliseconds |

### Performance Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cpuSchedulingPolicy` | string | `"idle"` | CPU scheduling policy ("idle", "batch") |
| `ioSchedulingClass` | string | `"idle"` | IO scheduling class ("idle", "best-effort") |

### Advanced Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `allowDirty` | bool | `false` | Allow updates with uncommitted changes |
| `repository` | string | `null` | Deprecated: Use `flake` instead |

## Setup Guide

### For Git-based Updates with SSH

1. **Generate SSH Key**

```bash
ssh-keygen -t ed25519 -f ./autoupgrade_key -C "nixos-autoupgrade"
```

2. **Add SSH Key to Git Server**

For GitHub:
```bash
# Add the public key to your GitHub account's SSH keys
cat autoupgrade_key.pub
```

For GitLab:
```bash
# Add the public key to your GitLab account's SSH keys
cat autoupgrade_key.pub
```

For self-hosted git (soft-serve):
```bash
ssh soft-serve -p 23231 key add autoupgrade < autoupgrade_key.pub
```

3. **Add Private Key to SOPS**

Add to your `secrets/secrets.yaml`:
```yaml
autoupgrade:
  ssh_key: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    (paste your private key here)
    -----END OPENSSH PRIVATE KEY-----
```

Encrypt with sops:
```bash
sops -e -i secrets/secrets.yaml
```

4. **Enable in Configuration**

```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@github.com/yourusername/nixos-config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets/secrets.yaml;
    sshTestHost = "git@github.com";
  };
}
```

### For Local Flake Updates

Simply enable with `localFlake = true`:

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
  };
}
```

### For Laptops

#### Enable Wake-from-Sleep

1. **Check RTC Wake Support**

```bash
# Check if RTC wake alarm is available
ls -l /sys/class/rtc/rtc0/wakealarm
```

2. **Configure BIOS/UEFI**

Enable "Wake on RTC" or similar option in your BIOS/UEFI settings.

3. **Enable in Configuration**

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    
    wakeup = {
      enable = true;
      wakeupTime = "03:55";
      autoSuspendAfter = true;
    };
    
    schedule = "04:00";
  };
}
```

#### Enable AC Power Detection

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    onlyOnACPower = true;
  };
}
```

This prevents battery drain by only running updates when connected to AC power.

### For Desktop Notifications

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    
    notification = {
      enable = true;
      urgency = "normal";  # or "low" or "critical"
      timeout = 30000;      # 30 seconds
    };
  };
}
```

Notifications will appear:
- Immediately if a user is logged in when the update completes
- On next login if no user was logged in during the update
- Only if the update was successful

## How It Works

### Update Process

1. **Timer triggers** at the configured schedule
2. **Random delay** is applied (prevents simultaneous updates on multiple systems)
3. **Pre-flight checks**:
   - AC power check (if enabled)
   - SSH connectivity test (if enabled and using git+ssh)
   - Git dirty check (unless `allowDirty = true`)
4. **Update execution**: `nixos-rebuild` pulls and builds new configuration
5. **Post-update actions**:
   - Send notification to logged-in users (if enabled)
   - Create notification flag for future logins (if enabled)
   - Auto-suspend if woken by timer and no users logged in (if enabled)
6. **Automatic retry** on failure (up to 6 times within 120 seconds)

### Wake-up Process (for laptops)

1. **Before suspend**: RTC wake alarm is set for configured wakeup time
2. **System suspends** normally
3. **RTC wakes system** at specified time
4. **Update runs** as scheduled
5. **System resuspends** (if `autoSuspendAfter = true` and no users logged in)

### Notification Process

1. **Update completes successfully**: Timestamp saved to `/var/lib/nixos-autoupdate/last-update`
2. **Immediate notification**: If users are logged in, notification sent via D-Bus
3. **Login notification**: On next login, systemd user service checks for recent updates
4. **Notification displayed**: Shows update time and success message

## Monitoring

### Check Update Status

```bash
# Service status
systemctl status nixos-upgrade.service

# Recent logs
journalctl -u nixos-upgrade.service -n 50

# Follow logs in real-time
journalctl -u nixos-upgrade.service -f
```

### Check Timer Status

```bash
# List all timers and see when next update is scheduled
systemctl list-timers nixos-upgrade.timer

# Timer status
systemctl status nixos-upgrade.timer
```

### Check Last Update

```bash
# Check last update timestamp (if notifications enabled)
cat /var/lib/nixos-autoupdate/last-update
```

### Manual Update

```bash
# Trigger an update immediately
systemctl start nixos-upgrade.service
```

## Troubleshooting

### Updates Not Running

1. **Check if module is enabled**:
   ```bash
   nixos-rebuild --show-trace dry-build
   ```

2. **Verify timer is active**:
   ```bash
   systemctl status nixos-upgrade.timer
   systemctl list-timers nixos-upgrade.timer
   ```

3. **Check service logs**:
   ```bash
   journalctl -u nixos-upgrade.service -n 100
   ```

### SSH Connection Failures

1. **Verify secret is decrypted**:
   ```bash
   ls -la /run/secrets/
   ```

2. **Test SSH connection manually**:
   ```bash
   ssh -i /run/secrets/autoupgrade_ssh_key git@github.com
   ```

3. **Check SSH key permissions**:
   ```bash
   ls -l /run/secrets/autoupgrade_ssh_key
   # Should be: -r-------- 1 root root
   ```

### Wake-up Not Working

1. **Check RTC wake support**:
   ```bash
   cat /sys/class/rtc/rtc0/wakealarm
   ```

2. **Verify BIOS setting**: Enable "Wake on RTC" in BIOS/UEFI

3. **Check wake-up service**:
   ```bash
   systemctl status nixos-upgrade-wakeup.service
   ```

### Notifications Not Showing

1. **Check notification service**:
   ```bash
   systemctl --user status nixos-autoupdate-notify.service
   ```

2. **Verify D-Bus is available**:
   ```bash
   echo $DBUS_SESSION_BUS_ADDRESS
   ```

3. **Test notification manually**:
   ```bash
   notify-send "Test" "This is a test notification"
   ```

### AC Power Detection Issues

1. **Check power supply status**:
   ```bash
   cat /sys/class/power_supply/*/online
   ```

2. **Try upower**:
   ```bash
   upower -i /org/freedesktop/UPower/devices/line_power_AC
   ```

## Security Considerations

- 🔐 **SSH keys** are stored encrypted in sops and decrypted only to root (mode 0600)
- 🔑 **Use dedicated SSH keys** for auto-updates (not your personal key)
- 🚫 **Easy revocation**: SSH key can be revoked if compromised
- ✅ **Git dirty check**: Updates skip if working tree is dirty (unless `allowDirty = true`)
- ⚡ **Low priority**: Updates run with idle CPU/IO scheduling to minimize impact
- 🔄 **Automatic retry**: Failed updates retry automatically (up to 6 times)

## Advanced Usage

### Multiple Update Schedules

You can't have multiple schedules in one module, but you can:
- Use systemd timer syntax like `"Mon,Wed,Fri 04:00"`
- Use calendar event syntax like `"*-*-* 04:00:00"`

### Custom Flags

Add custom flags to `nixos-rebuild`:

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    flags = [
      "--refresh"
      "--no-write-lock-file"
      "--option"
      "substituters"
      "https://cache.nixos.org"
    ];
  };
}
```

### Integration with Other Services

The module uses standard systemd units, so you can add dependencies:

```nix
{
  systemd.services.nixos-upgrade = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
```

## Examples

### Desktop Computer

```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@github.com/user/nixos-config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
    sshTestHost = "git@github.com";
    schedule = "04:00";
    notification.enable = true;
  };
}
```

### Laptop

```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;
    onlyOnACPower = true;
    wakeup = {
      enable = true;
      wakeupTime = "03:55";
      autoSuspendAfter = true;
    };
    notification = {
      enable = true;
      urgency = "low";
    };
    schedule = "04:00";
  };
}
```

### Server

```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@gitlab.com/user/server-config?ref=prod";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
    sshTestHost = "git@gitlab.com";
    schedule = "03:00";
    randomizedDelaySec = "1h";
    flags = [ "--refresh" "--no-write-lock-file" ];
  };
}
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - See LICENSE file for details (if applicable)

## Credits

Based on the original NixOS auto-update module, enhanced with laptop and notification features.
