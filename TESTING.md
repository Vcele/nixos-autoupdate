# Testing Guide for nixos-autoupdate

This document provides comprehensive testing instructions for all features of the nixos-autoupdate module.

## Automated Tests

Run the automated test suite to verify basic functionality:

```bash
cd test
./run-tests.sh
```

This will validate:
- Flake structure and syntax
- Module option definitions
- Wake-up functionality components
- AC power detection
- Notification system
- Documentation completeness

## Manual Testing

Since this is a NixOS module, full integration testing requires a NixOS system. Below are instructions for testing each feature.

### Prerequisites

1. A NixOS system (physical or VM)
2. Flakes enabled in your configuration:
   ```nix
   nix.settings.experimental-features = [ "nix-command" "flakes" ];
   ```

### Test 1: Basic Local Flake Update

**Goal:** Verify that the module can update from a local flake.

1. Add the module to your system's `flake.nix`:
   ```nix
   {
     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
       nixos-autoupdate.url = "github:Vcele/nixos-autoupdate";
     };
     
     outputs = { self, nixpkgs, nixos-autoupdate, ... }: {
       nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
         modules = [
           nixos-autoupdate.nixosModules.default
           {
             system.autoupdate = {
               enable = true;
               localFlake = true;
               schedule = "minutely";  # For testing
             };
           }
           # ... your other modules
         ];
       };
     };
   }
   ```

2. Rebuild your system:
   ```bash
   sudo nixos-rebuild switch
   ```

3. Verify the timer is active:
   ```bash
   systemctl status nixos-upgrade.timer
   systemctl list-timers nixos-upgrade.timer
   ```

4. Check the service configuration:
   ```bash
   systemctl cat nixos-upgrade.service
   ```

5. Trigger a manual update:
   ```bash
   sudo systemctl start nixos-upgrade.service
   ```

6. Monitor the logs:
   ```bash
   journalctl -u nixos-upgrade.service -f
   ```

**Expected Result:** The service should run successfully and update your system.

### Test 2: Git Repository with SSH

**Goal:** Verify that the module can update from a git repository using SSH.

**Prerequisites:**
- sops-nix configured
- SSH key generated and added to your git server

1. Set up your secrets as described in the README
2. Configure the module:
   ```nix
   {
     system.autoupdate = {
       enable = true;
       flake = "git+ssh://git@github.com/youruser/your-nixos-config?ref=main";
       sshKeySops = "autoupgrade/ssh_key";
       sopsFile = ./secrets/secrets.yaml;
       sshTestHost = "git@github.com";
       schedule = "daily";
     };
   }
   ```

3. Rebuild and test:
   ```bash
   sudo nixos-rebuild switch
   sudo systemctl start nixos-upgrade.service
   journalctl -u nixos-upgrade.service -n 50
   ```

**Expected Result:** 
- The SSH connection test should succeed
- The system should pull from your git repository
- The update should complete successfully

### Test 3: AC Power Detection

**Goal:** Verify that updates only run when on AC power.

**Prerequisites:**
- A laptop or system with battery

1. Configure the module:
   ```nix
   {
     system.autoupdate = {
       enable = true;
       localFlake = true;
       onlyOnACPower = true;
       schedule = "minutely";  # For testing
     };
   }
   ```

2. Rebuild your system:
   ```bash
   sudo nixos-rebuild switch
   ```

3. Test with battery power:
   ```bash
   # Disconnect AC power
   sudo systemctl start nixos-upgrade.service
   journalctl -u nixos-upgrade.service -n 20
   ```

   **Expected:** Service should skip update with message "System is not connected to AC power"

4. Test with AC power:
   ```bash
   # Connect AC power
   sudo systemctl start nixos-upgrade.service
   journalctl -u nixos-upgrade.service -n 20
   ```

   **Expected:** Service should proceed with update

### Test 4: Wake-up Functionality

**Goal:** Verify that the system can wake from sleep to perform updates.

**Prerequisites:**
- System with RTC wake alarm support
- BIOS/UEFI configured for RTC wake

1. Verify RTC support:
   ```bash
   ls -l /sys/class/rtc/rtc0/wakealarm
   cat /proc/driver/rtc
   ```

2. Configure the module:
   ```nix
   {
     system.autoupdate = {
       enable = true;
       localFlake = true;
       wakeup = {
         enable = true;
         wakeupTime = "14:30";  # Set to a few minutes from now
         autoSuspendAfter = true;
       };
       schedule = "14:35";  # 5 minutes after wakeup
     };
   }
   ```

3. Rebuild:
   ```bash
   sudo nixos-rebuild switch
   ```

4. Check that wakeup service is configured:
   ```bash
   systemctl status nixos-upgrade-wakeup.service
   ```

5. Manually test RTC alarm:
   ```bash
   # Set alarm for 2 minutes from now
   sudo bash -c 'echo 0 > /sys/class/rtc/rtc0/wakealarm'
   sudo bash -c "echo $(date -d '+2 minutes' +%s) > /sys/class/rtc/rtc0/wakealarm"
   
   # Verify it's set
   cat /sys/class/rtc/rtc0/wakealarm
   
   # Suspend the system
   sudo systemctl suspend
   ```

   **Expected:** System should wake up after 2 minutes

6. For full integration test:
   - Let the system suspend normally
   - The RTC alarm should be set automatically before suspend
   - System should wake at the configured time
   - Update should run
   - System should suspend again if no users are logged in

**Expected Result:** System wakes up, runs the update, and suspends again (if configured).

### Test 5: Desktop Notifications

**Goal:** Verify that users receive notifications after updates.

**Prerequisites:**
- Graphical desktop environment
- D-Bus running

1. Configure the module:
   ```nix
   {
     system.autoupdate = {
       enable = true;
       localFlake = true;
       notification = {
         enable = true;
         urgency = "normal";
         timeout = 30000;
       };
       schedule = "minutely";  # For testing
     };
   }
   ```

2. Rebuild:
   ```bash
   sudo nixos-rebuild switch
   ```

3. Verify the user service is installed:
   ```bash
   systemctl --user cat nixos-autoupdate-notify.service
   ```

4. Test notification manually:
   ```bash
   # Create a fake update timestamp
   sudo mkdir -p /var/lib/nixos-autoupdate
   sudo bash -c "echo $(date -Iseconds) > /var/lib/nixos-autoupdate/last-update"
   
   # Trigger the notification service
   systemctl --user start nixos-autoupdate-notify.service
   ```

   **Expected:** You should see a desktop notification

5. For full integration test:
   - Trigger an actual update: `sudo systemctl start nixos-upgrade.service`
   - If logged in, you should see an immediate notification
   - If not logged in, log out and log back in
   - You should see a notification on login

**Expected Result:** Desktop notification appears with update information.

### Test 6: Combined Laptop Configuration

**Goal:** Test all laptop features together.

1. Configure with all features:
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
       randomizedDelaySec = "30m";
     };
   }
   ```

2. Rebuild and verify all components:
   ```bash
   sudo nixos-rebuild switch
   
   # Check all services
   systemctl status nixos-upgrade.timer
   systemctl status nixos-upgrade.service
   systemctl status nixos-upgrade-wakeup.service
   systemctl --user status nixos-autoupdate-notify.service
   ```

3. Full workflow test:
   - Ensure AC power is connected
   - Let system suspend overnight
   - In the morning, check if update ran:
     ```bash
     journalctl -u nixos-upgrade.service --since "yesterday"
     cat /var/lib/nixos-autoupdate/last-update
     ```

**Expected Result:** 
- System wakes at 03:55
- Update runs at ~04:00 (with random delay)
- System suspends again if no users logged in
- Notification appears on next login

## Troubleshooting Tests

### Check Service Status

```bash
# Timer status and next run time
systemctl list-timers nixos-upgrade.timer

# Service status
systemctl status nixos-upgrade.service

# Recent logs
journalctl -u nixos-upgrade.service -n 50

# Follow logs in real-time
journalctl -u nixos-upgrade.service -f
```

### Check Configuration

```bash
# View generated service file
systemctl cat nixos-upgrade.service

# View timer configuration
systemctl cat nixos-upgrade.timer

# Check if secrets are properly decrypted (if using sops)
ls -la /run/secrets/
```

### Manual Triggers

```bash
# Manually trigger an update
sudo systemctl start nixos-upgrade.service

# Restart the timer
sudo systemctl restart nixos-upgrade.timer

# Reset failed state if service failed
sudo systemctl reset-failed nixos-upgrade.service
```

### Debug AC Power Detection

```bash
# Check power supply status
cat /sys/class/power_supply/*/online

# List all power supplies
ls -l /sys/class/power_supply/

# Use upower
upower -i /org/freedesktop/UPower/devices/line_power_AC
upower -i /org/freedesktop/UPower/devices/battery_BAT0
```

### Debug Wake-up

```bash
# Check RTC device
ls -l /sys/class/rtc/rtc0/wakealarm

# Read current alarm
cat /sys/class/rtc/rtc0/wakealarm

# Check RTC info
cat /proc/driver/rtc

# Check wakeup service logs
journalctl -u nixos-upgrade-wakeup.service -n 20
```

### Debug Notifications

```bash
# Check D-Bus session
echo $DBUS_SESSION_BUS_ADDRESS

# Test notify-send
notify-send "Test" "This is a test notification"

# Check notification state
cat /var/lib/nixos-autoupdate/last-update

# View user service logs
journalctl --user -u nixos-autoupdate-notify.service -n 20

# Manually trigger notification service
systemctl --user start nixos-autoupdate-notify.service
```

## Performance Testing

### Resource Usage During Update

Monitor resource usage while an update is running:

```bash
# Start update in background
sudo systemctl start nixos-upgrade.service &

# Monitor CPU usage (should be low priority)
top -p $(pgrep -f nixos-rebuild)

# Monitor I/O (should be idle class)
iotop -p $(pgrep -f nixos-rebuild)

# Check scheduling
ps -o pid,comm,class,rtprio,ni,pri -p $(pgrep -f nixos-rebuild)
```

**Expected:** Update process should use minimal resources due to idle scheduling.

## Security Testing

### SSH Key Permissions

```bash
# Check secret permissions (should be 0600, owned by root)
ls -l /run/secrets/autoupgrade_ssh_key

# Verify secret is only readable by root
sudo -u nobody cat /run/secrets/autoupgrade_ssh_key  # Should fail
```

### Git Dirty Check

```bash
# Make local changes to your flake
echo "# test" >> /etc/nixos/flake.nix

# Try to run update (should skip if allowDirty = false)
sudo systemctl start nixos-upgrade.service
journalctl -u nixos-upgrade.service -n 20
```

## Continuous Testing

For ongoing validation, you can:

1. Enable verbose logging:
   ```nix
   systemd.services.nixos-upgrade.serviceConfig.StandardOutput = "journal+console";
   ```

2. Set up monitoring:
   ```bash
   # Create a simple monitoring script
   while true; do
     systemctl status nixos-upgrade.timer
     systemctl status nixos-upgrade.service
     sleep 60
   done
   ```

3. Use systemd timers to run tests:
   ```bash
   # Create a test timer that runs every hour
   systemctl list-timers --all
   ```

## Reporting Issues

When reporting issues, please include:

1. Your module configuration
2. Output of:
   ```bash
   systemctl status nixos-upgrade.service
   journalctl -u nixos-upgrade.service -n 100
   systemctl cat nixos-upgrade.service
   nixos-rebuild --version
   ```
3. For wake-up issues:
   ```bash
   cat /proc/driver/rtc
   cat /sys/class/rtc/rtc0/wakealarm
   ```
4. For notification issues:
   ```bash
   echo $DBUS_SESSION_BUS_ADDRESS
   systemctl --user status nixos-autoupdate-notify.service
   ```

## Success Criteria

All features are working correctly if:

- ✅ Timer triggers at scheduled times
- ✅ Updates complete successfully
- ✅ AC power detection works (if enabled)
- ✅ System wakes from sleep (if enabled)
- ✅ System auto-suspends after update (if enabled)
- ✅ Notifications appear on login (if enabled)
- ✅ SSH authentication works (if using git+ssh)
- ✅ Resource usage is minimal (idle scheduling)
- ✅ Secrets are properly protected
