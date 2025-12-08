# Quick Start Guide

Get started with nixos-autoupdate in 5 minutes or less!

## For Laptop Users (Simplest Setup)

Want automatic updates on your laptop with wake-up support and notifications? Here's the quickest way:

### 1. Add to your flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-autoupdate.url = "github:Vcele/nixos-autoupdate";
  };
  
  outputs = { nixpkgs, nixos-autoupdate, ... }: {
    nixosConfigurations.your-laptop = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-autoupdate.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### 2. Add to your configuration.nix

```nix
{
  # Enable flakes if not already enabled
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Enable auto-update with laptop features
  system.autoupdate = {
    enable = true;
    localFlake = true;  # Use your local flake
    
    # Only update when plugged in
    onlyOnACPower = true;
    
    # Wake up to update
    wakeup = {
      enable = true;
      wakeupTime = "03:55";  # Wake 5 minutes before update
      autoSuspendAfter = true;  # Sleep again if no one's logged in
    };
    
    # Show notification after update
    notification = {
      enable = true;
    };
    
    # Update at 4 AM daily
    schedule = "04:00";
  };
}
```

### 3. Apply and test

```bash
# Apply the configuration
sudo nixos-rebuild switch

# Verify it's working
systemctl status nixos-upgrade.timer
systemctl list-timers nixos-upgrade.timer

# Test manually (will run immediately)
sudo systemctl start nixos-upgrade.service
journalctl -u nixos-upgrade.service -f
```

**That's it!** Your laptop will now:
- Wake up at 3:55 AM (if sleeping)
- Update at 4:00 AM (only if on AC power)
- Go back to sleep (if no users logged in)
- Show you a notification on next login

---

## For Desktop Users

Want simple daily updates with notifications?

### 1. Add to flake.nix (same as above)

### 2. Add to configuration.nix

```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  system.autoupdate = {
    enable = true;
    localFlake = true;
    schedule = "daily";
    
    notification = {
      enable = true;
    };
  };
}
```

### 3. Apply

```bash
sudo nixos-rebuild switch
```

---

## For Git Repository Users

Using a git repository for your NixOS config?

### Prerequisites
1. Generate SSH key:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/autoupgrade_key -C "nixos-autoupgrade"
   ```

2. Add public key to your git server (GitHub, GitLab, etc.)

3. Set up sops-nix with your SSH private key

### Configuration

```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@github.com/yourusername/nixos-config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets/secrets.yaml;
    sshTestHost = "git@github.com";
    schedule = "04:00";
    
    notification = {
      enable = true;
    };
  };
}
```

---

## Verification Checklist

After setup, verify everything works:

- [ ] Timer is active: `systemctl status nixos-upgrade.timer`
- [ ] Service is configured: `systemctl cat nixos-upgrade.service`
- [ ] Next run is scheduled: `systemctl list-timers nixos-upgrade.timer`
- [ ] Manual trigger works: `sudo systemctl start nixos-upgrade.service`
- [ ] (Laptop) AC detection works: Try with/without AC power
- [ ] (Laptop) RTC wake is available: `ls /sys/class/rtc/rtc0/wakealarm`
- [ ] (Notifications) Notify works: `notify-send "Test" "Hello"`

---

## Common Configurations

### Update every morning at 4 AM
```nix
schedule = "04:00";
```

### Update weekly on Monday mornings
```nix
schedule = "Mon 04:00";
```

### Update twice daily
```nix
schedule = "*-*-* 04:00,16:00";
```

### Update but only on AC power (laptops)
```nix
onlyOnACPower = true;
```

### Update with longer random delay
```nix
randomizedDelaySec = "2h";
```

---

## Troubleshooting

### Updates not running?
```bash
# Check timer status
systemctl status nixos-upgrade.timer

# Check service logs
journalctl -u nixos-upgrade.service -n 50

# Try manual trigger
sudo systemctl start nixos-upgrade.service
```

### AC power check failing?
```bash
# Check power status
cat /sys/class/power_supply/*/online

# Temporarily disable AC check for testing
# In configuration.nix:
# onlyOnACPower = false;
```

### Wake-up not working?
```bash
# Check RTC support
ls -l /sys/class/rtc/rtc0/wakealarm

# Enable in BIOS (look for "Wake on RTC" or similar)
```

### Notifications not showing?
```bash
# Test notify-send
notify-send "Test" "This is a test"

# Check D-Bus
echo $DBUS_SESSION_BUS_ADDRESS

# View user service
systemctl --user status nixos-autoupdate-notify.service
```

---

## Next Steps

- 📖 Read the [full README](README.md) for all options
- 🧪 See [TESTING.md](TESTING.md) for detailed testing instructions
- 📦 Check [examples/](examples/) for more configuration ideas
- 🔄 See [MIGRATION.md](MIGRATION.md) if upgrading from old module

---

## Need Help?

- 📋 Check the [README](README.md) for detailed documentation
- 🐛 Open an issue on GitHub if you find a bug
- 💡 Share your configuration if you have a cool setup!

---

**Happy auto-updating! 🚀**
