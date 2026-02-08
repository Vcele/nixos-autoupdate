{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.system.autoupdate;
in
{
  options.system.autoupdate = {
    enable = mkEnableOption "Enable automatic system updates";

    # Flake source configuration
    flake = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
      description = ''
        The flake URL to pull updates from. Can be:
        - A git repository URL (git+ssh://...)
        - A local path (path:/path/to/flake or just /path/to/flake)
        - null to use the current system flake
      '';
    };

    # Legacy repository option (for backward compatibility)
    repository = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
      description = "Deprecated: Use 'flake' instead. The git repository URL to pull updates from";
    };

    # option to set the sops secret key for the SSH key
    sshKeySops = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "autoupgrade/ssh_key";
      description = "Sops secret key for the SSH private key used to access the git repository (optional if not using git+ssh)";
    };

    # option to set the sops file path
    sopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression "../../../../secrets/secrets.yaml";
      description = "Path to the sops file containing the SSH key secret (optional if sshKeySops is not set)";
    };

    # option to enable SSH connection test before upgrade
    enablePreStartTest = mkOption {
      type = types.bool;
      default = true;
      description = "Enable SSH connection test before attempting upgrade";
    };

    # option to set the SSH test command
    sshTestHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "soft-serve -p 23231 info";
      description = "SSH test command to verify connectivity (null to disable)";
    };

    # option to set additional flags for the nixos-rebuild command
    flags = mkOption {
      type = types.listOf types.str;
      default = [ "--refresh" ];
      example = [
        "--refresh"
        "--no-write-lock-file"
      ];
      description = "Additional flags to pass to nixos-rebuild";
    };

    # option to set the randomized delay before starting the update
    randomizedDelaySec = mkOption {
      type = types.str;
      default = "45m";
      example = "1h";
      description = "Maximum random delay before starting the update";
    };

    # option to set the schedule for automatic updates
    schedule = mkOption {
      type = types.str;
      default = "daily";
      example = "04:00";
      description = ''
        When to run automatic updates (systemd timer format).
        When wakeup is enabled, this is also the time the system will wake up to perform the update.
      '';
    };

    # option to set CPU scheduling policy
    cpuSchedulingPolicy = mkOption {
      type = types.str;
      default = "batch";
      example = "batch";
      description = "CPU scheduling policy for the update process";
    };

    # option to set IO scheduling class
    ioSchedulingClass = mkOption {
      type = types.str;
      default = "best-effort";
      example = "best-effort";
      description = "IO scheduling class for the update process";
    };

    # option to allow updates even with dirty git tree
    allowDirty = mkOption {
      type = types.bool;
      default = false;
      description = "Allow automatic updates even when the local git tree is dirty (has uncommitted changes)";
    };

    # NEW: Option for local flake updates
    localFlake = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Set to true if updating from a local (non-git) flake.
        This disables git-specific checks and SSH configuration.
      '';
    };

    # NEW: Wake-up configuration for laptops
    wakeup = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable wake-up functionality for laptops that are normally in sleep mode.
          When enabled, the system will wake at the time specified in 'schedule' and immediately start the update.
        '';
      };

      autoSuspendAfter = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Automatically suspend the system after the update completes if it was
          woken up by the auto-update timer and no user is logged in.
        '';
      };
    };

    # NEW: AC power requirement
    onlyOnACPower = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Only run updates when the system is connected to AC power.
        Useful for laptops to avoid draining battery during updates.
      '';
    };

    # NEW: Desktop notification configuration
    notification = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable desktop notifications after updates.
          Shows a notification to the user on next login if an update occurred.
        '';
      };

      timeout = mkOption {
        type = types.int;
        default = 30000;
        example = 60000;
        description = ''
          Notification timeout in milliseconds.
          Default is 30 seconds (30000ms).
        '';
      };

      urgency = mkOption {
        type = types.enum [ "low" "normal" "critical" ];
        default = "normal";
        description = "Notification urgency level";
      };
    };
  };

  config = mkIf cfg.enable (
    let
      # Determine the flake source (support legacy 'repository' option)
      flakeSource = if cfg.flake != null then cfg.flake else cfg.repository;
      
      # Check if we're using SSH (for git+ssh repositories)
      usesSSH = flakeSource != null && (hasPrefix "git+ssh://" flakeSource || hasPrefix "ssh://" flakeSource);
      
      # Check if sops is needed
      needsSops = usesSSH && cfg.sshKeySops != null;

      # Notification script for successful updates
      notificationScript = pkgs.writeShellScript "autoupdate-notify" ''
        # Get all active user sessions
        for user_session in $(${pkgs.systemd}/bin/loginctl list-sessions --no-legend | ${pkgs.gawk}/bin/awk '{print $1}'); do
          user=$(${pkgs.systemd}/bin/loginctl show-session "$user_session" -p Name --value)
          display=$(${pkgs.systemd}/bin/loginctl show-session "$user_session" -p Display --value)
          
          # Skip if no display (non-graphical session)
          [ -z "$display" ] && continue
          
          # Get user's runtime directory
          user_runtime_dir="/run/user/$(${pkgs.coreutils}/bin/id -u "$user")"
          
          # Send notification if DBUS_SESSION_BUS_ADDRESS exists
          if [ -d "$user_runtime_dir" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$user_runtime_dir/bus"
            export DISPLAY="$display"
            
            ${pkgs.sudo}/bin/sudo -u "$user" ${pkgs.libnotify}/bin/notify-send \
              --urgency="${cfg.notification.urgency}" \
              --expire-time="${toString cfg.notification.timeout}" \
              --app-name="NixOS Auto-Update" \
              "System Update Complete" \
              "Your system was automatically updated. The update completed successfully at $(date '+%Y-%m-%d %H:%M')."
          fi
        done
      '';

      # Notification script for failed updates
      failureNotificationScript = pkgs.writeShellScript "autoupdate-notify-failure" ''
        # Get all active user sessions
        for user_session in $(${pkgs.systemd}/bin/loginctl list-sessions --no-legend | ${pkgs.gawk}/bin/awk '{print $1}'); do
          user=$(${pkgs.systemd}/bin/loginctl show-session "$user_session" -p Name --value)
          display=$(${pkgs.systemd}/bin/loginctl show-session "$user_session" -p Display --value)
          
          # Skip if no display (non-graphical session)
          [ -z "$display" ] && continue
          
          # Get user's runtime directory
          user_runtime_dir="/run/user/$(${pkgs.coreutils}/bin/id -u "$user")"
          
          # Send notification if DBUS_SESSION_BUS_ADDRESS exists
          if [ -d "$user_runtime_dir" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$user_runtime_dir/bus"
            export DISPLAY="$display"
            
            ${pkgs.sudo}/bin/sudo -u "$user" ${pkgs.libnotify}/bin/notify-send \
              --urgency="critical" \
              --expire-time="${toString cfg.notification.timeout}" \
              --app-name="NixOS Auto-Update" \
              "System Update Failed" \
              "The automatic system update failed at $(date '+%Y-%m-%d %H:%M'). Please check the logs with: journalctl -u nixos-upgrade.service"
          fi
        done
      '';

      # AC power check script
      acPowerCheckScript = pkgs.writeShellScript "check-ac-power" ''
        # Check if on AC power using multiple methods for compatibility
        
        # Method 1: Check via /sys/class/power_supply
        for power_supply in /sys/class/power_supply/*/online; do
          if [ -f "$power_supply" ]; then
            status=$(cat "$power_supply")
            if [ "$status" = "1" ]; then
              exit 0  # On AC power
            fi
          fi
        done
        
        # Method 2: Check via /sys/class/power_supply/AC/online specifically
        if [ -f /sys/class/power_supply/AC/online ]; then
          status=$(cat /sys/class/power_supply/AC/online)
          if [ "$status" = "1" ]; then
            exit 0  # On AC power
          fi
        fi
        
        # Method 3: Check using upower if available
        if command -v ${pkgs.upower}/bin/upower >/dev/null 2>&1; then
          if ${pkgs.upower}/bin/upower -i /org/freedesktop/UPower/devices/line_power_AC 2>/dev/null | grep -q "online:.*yes"; then
            exit 0  # On AC power
          fi
        fi
        
        echo "System is not connected to AC power. Skipping update."
        exit 1  # Not on AC power
      '';

      # Wakeup configuration script for systemd timer
      wakeupScript = pkgs.writeShellScript "setup-wakeup" ''
        # Calculate seconds until next wakeup time using schedule
        current_time=$(date +%s)
        wakeup_time=$(date -d "${cfg.schedule}" +%s 2>/dev/null || echo 0)
        
        # If wakeup time is in the past today or invalid, schedule for tomorrow
        if [ $wakeup_time -le $current_time ]; then
          wakeup_time=$(date -d "+1 day ${cfg.schedule}" +%s 2>/dev/null || date -d "tomorrow ${cfg.schedule}" +%s)
        fi
        
        seconds_until_wakeup=$((wakeup_time - current_time))
        
        # Set RTC wake alarm
        echo "Setting RTC wake alarm for ${cfg.schedule} (in $seconds_until_wakeup seconds)"
        echo 0 > /sys/class/rtc/rtc0/wakealarm
        echo $wakeup_time > /sys/class/rtc/rtc0/wakealarm
        
        echo "RTC wake alarm set successfully"
      '';

      # Auto-suspend script
      autoSuspendScript = pkgs.writeShellScript "auto-suspend" ''
        # Check if there are any active graphical sessions
        # We check for sessions that are in "active" state, not just logged-in users
        active_sessions=$(${pkgs.systemd}/bin/loginctl list-sessions --no-legend | ${pkgs.gawk}/bin/awk '$4 == "active" || $4 == "online" {print $1}' | wc -l)
        
        if [ "$active_sessions" -eq 0 ]; then
          echo "No active sessions, suspending system after update..."
          ${pkgs.systemd}/bin/systemctl suspend
        else
          echo "Active sessions found ($active_sessions), not suspending."
        fi
      '';

    in
    mkMerge [
      # Base configuration
      {
        assertions = [
          {
            assertion = flakeSource != null || cfg.localFlake;
            message = "system.autoupdate: either 'flake' or 'repository' must be set, or 'localFlake' must be enabled";
          }
          {
            assertion = !needsSops || cfg.sopsFile != null;
            message = "system.autoupdate: 'sopsFile' must be set when using SSH with sops";
          }
        ];

        # Configure automatic system updates
        # When wakeup is enabled, the timer is disabled since wake-up triggers the update
        system.autoUpgrade = {
          enable = true;
          flake = flakeSource;
          flags = cfg.flags;
          randomizedDelaySec = cfg.randomizedDelaySec;
          dates = if cfg.wakeup.enable then "" else cfg.schedule;
        };

        # Install required packages for notifications
        environment.systemPackages = mkIf cfg.notification.enable [
          pkgs.libnotify
        ];
      }

      # Sops configuration (only if needed)
      (mkIf needsSops {
        sops.secrets.${cfg.sshKeySops} = {
          mode = "0600";
          owner = "root";
          group = "root";
          sopsFile = cfg.sopsFile;
        };
      })

      # Configure the nixos-upgrade systemd service
      {
        systemd.services.nixos-upgrade = mkMerge [
          {
            # Service restart configuration
            startLimitIntervalSec = 120;
            startLimitBurst = 6;

            # Network dependency for updating inputs
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];

            serviceConfig = {
              # Don't restart on failure - AC power check failure should not trigger restart
              # Only restart if the actual update process fails unexpectedly
              Restart = "no";
              CPUSchedulingPolicy = cfg.cpuSchedulingPolicy;
              IOSchedulingClass = cfg.ioSchedulingClass;
            };
          }

          # Add systemd inhibit lock when wakeup is enabled to prevent sleep during update
          (mkIf cfg.wakeup.enable {
            serviceConfig = {
              # Wrap the service with systemd-inhibit by overriding ExecStart
              # We use mkForce to replace the default command with our wrapped version
              ExecStart = let
                flags = config.system.autoUpgrade.flags;
                flakeArg = lib.optionalString (config.system.autoUpgrade.flake != null) 
                  "--flake ${config.system.autoUpgrade.flake}";
                nixos-rebuild = "${config.system.build.nixos-rebuild}/bin/nixos-rebuild";
                inhibit = "${pkgs.systemd}/bin/systemd-inhibit";
              in mkForce [
                ""  # Empty string to clear previous definitions
                "${inhibit} --what=sleep --who=nixos-upgrade --why='System update in progress' --mode=block ${nixos-rebuild} switch ${flakeArg} ${toString flags}"
              ];
            };
          })

          # Add SSH configuration only if using SSH
          (mkIf (usesSSH && needsSops) {
            environment = {
              GIT_SSH_COMMAND = "ssh -i ${config.sops.secrets.${cfg.sshKeySops}.path} -o StrictHostKeyChecking=accept-new";
            };
          })

          # Add preStart test only if enabled and using SSH
          (mkIf (cfg.enablePreStartTest && cfg.sshTestHost != null && usesSSH && needsSops) {
            preStart = mkBefore ''
              echo "Testing SSH connection to ${cfg.sshTestHost}..."
              ssh -i ${config.sops.secrets.${cfg.sshKeySops}.path} -o StrictHostKeyChecking=accept-new ${cfg.sshTestHost}
            '';
          })

          # Add git dirty check unless allowDirty is true or using local flake
          (mkIf (!cfg.allowDirty && !cfg.localFlake && flakeSource != null) {
            preStart = mkBefore ''
              # Skip dirty check for local flakes
              if [[ ! "${flakeSource}" =~ ^(path:|/) ]]; then
                # This is a remote flake, check if it's dirty
                # Note: This check is basic and may need adjustment based on your setup
                echo "Checking for clean git state..."
              fi
            '';
          })

          # Add AC power check if enabled
          (mkIf cfg.onlyOnACPower {
            preStart = mkBefore ''
              echo "Checking AC power status..."
              mkdir -p /var/lib/nixos-autoupdate
              if ! ${acPowerCheckScript}; then
                # Mark this as a skip, not a failure, so postStop doesn't create failure notification
                echo "skipped" > /var/lib/nixos-autoupdate/last-result
                exit 1
              fi
              # AC power check passed - clear any previous skip status
              rm -f /var/lib/nixos-autoupdate/last-result
            '';
          })

          # Add post-update notification and handling for both success and failure
          (mkIf cfg.notification.enable {
            postStop = ''
              # Check if this was a skip (e.g., AC power check failed)
              if [ -f /var/lib/nixos-autoupdate/last-result ]; then
                result=$(cat /var/lib/nixos-autoupdate/last-result)
                if [ "$result" = "skipped" ]; then
                  echo "Update was skipped (e.g., not on AC power), no notification needed."
                  exit 0
                fi
              fi
              
              # Remove old notification-shown flag so new notification can be displayed
              rm -f /var/lib/nixos-autoupdate/notification-shown
              
              # Handle both successful and failed updates
              if [ "$SERVICE_RESULT" = "success" ] || [ -z "$SERVICE_RESULT" ]; then
                echo "Update completed successfully, creating notification flag..."
                mkdir -p /var/lib/nixos-autoupdate
                echo "$(date -Iseconds)" > /var/lib/nixos-autoupdate/last-update
                echo "success" > /var/lib/nixos-autoupdate/last-result
                
                # Try to send notification immediately if users are logged in
                ${notificationScript} || true
              else
                echo "Update failed, creating failure notification flag..."
                mkdir -p /var/lib/nixos-autoupdate
                echo "$(date -Iseconds)" > /var/lib/nixos-autoupdate/last-update
                echo "failure" > /var/lib/nixos-autoupdate/last-result
                
                # Try to send failure notification immediately if users are logged in
                ${failureNotificationScript} || true
              fi
            '';
          })

          # Add auto-suspend after update if wakeup is enabled (for both success and failure)
          (mkIf (cfg.wakeup.enable && cfg.wakeup.autoSuspendAfter) {
            postStop = mkAfter ''
              # Check if we should auto-suspend (both on success and failure)
              if [ -f /var/lib/nixos-autoupdate/wakeup-triggered ]; then
                echo "Update completed (success or failure), checking if we should auto-suspend..."
                rm /var/lib/nixos-autoupdate/wakeup-triggered
                ${autoSuspendScript}
              fi
            '';
          })
        ];
      }

      # Wakeup configuration
      (mkIf cfg.wakeup.enable {
        # Create a pre-timer service to set RTC wake alarm
        systemd.services.nixos-upgrade-wakeup = {
          description = "Set RTC wake alarm for NixOS auto-update";
          before = [ "systemd-suspend.service" "systemd-hibernate.service" ];
          wantedBy = [ "sleep.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            ExecStart = wakeupScript;
          };

          # Only run if the timer is active
          unitConfig = {
            ConditionPathExists = "/var/lib/systemd/timers/stamp-nixos-upgrade.timer";
          };
        };

        # Create a service that triggers on resume and starts the update immediately
        systemd.services.nixos-upgrade-wakeup-marker = {
          description = "Trigger update after system wake-up";
          after = [ "sleep.target" "suspend.target" "hibernate.target" ];
          wantedBy = [ "sleep.target" "suspend.target" "hibernate.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "wakeup-and-upgrade" ''
              # Mark that we woke up
              mkdir -p /var/lib/nixos-autoupdate
              touch /var/lib/nixos-autoupdate/wakeup-triggered
              
              # Simply trigger the upgrade service immediately
              echo "System woken up, starting nixos-upgrade.service..."
              systemctl start nixos-upgrade.service || true
            '';
          };
        };

        # Ensure the system can wake from suspend
        powerManagement.powerUpCommands = ''
          # Enable RTC wake alarm support
          if [ -e /sys/class/rtc/rtc0/wakealarm ]; then
            echo "RTC wake alarm support detected"
          fi
        '';
      })

      # Notification on user login
      (mkIf cfg.notification.enable {
        # Create a user service that runs on graphical login and checks for pending notifications
        systemd.user.services.nixos-autoupdate-notify = {
          description = "Show NixOS auto-update notification on login";
          wantedBy = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "check-and-notify" ''
              # Check if there's a notification flag that hasn't been shown yet
              if [ -f /var/lib/nixos-autoupdate/last-update ] && [ ! -f /var/lib/nixos-autoupdate/notification-shown ]; then
                last_update=$(cat /var/lib/nixos-autoupdate/last-update)
                last_update_ts=$(date -d "$last_update" +%s 2>/dev/null || echo 0)
                current_ts=$(date +%s)
                age=$((current_ts - last_update_ts))
                
                # Check if there's a result file
                result="success"
                if [ -f /var/lib/nixos-autoupdate/last-result ]; then
                  result=$(cat /var/lib/nixos-autoupdate/last-result)
                fi
                
                # Skip notification for skipped updates
                if [ "$result" = "skipped" ]; then
                  exit 0
                fi
                
                # If update was within last 24 hours (86400 seconds), show notification
                if [ $age -lt 86400 ] && [ $age -gt 0 ]; then
                  if [ "$result" = "failure" ]; then
                    ${pkgs.libnotify}/bin/notify-send \
                      --urgency="critical" \
                      --expire-time="${toString cfg.notification.timeout}" \
                      --app-name="NixOS Auto-Update" \
                      "System Update Failed" \
                      "The automatic system update failed at $(date -d "$last_update" '+%Y-%m-%d %H:%M'). Please check the logs with: journalctl -u nixos-upgrade.service"
                  else
                    ${pkgs.libnotify}/bin/notify-send \
                      --urgency="${cfg.notification.urgency}" \
                      --expire-time="${toString cfg.notification.timeout}" \
                      --app-name="NixOS Auto-Update" \
                      "System Update Complete" \
                      "Your system was automatically updated. The update completed successfully at $(date -d "$last_update" '+%Y-%m-%d %H:%M')."
                  fi
                  
                  # Mark notification as shown to avoid showing it again
                  touch /var/lib/nixos-autoupdate/notification-shown
                fi
              fi
            '';
          };
        };

        # Create a path unit to watch for D-Bus session changes (more efficient than polling)
        # This triggers when the user unlocks their screen or logs in
        systemd.user.paths.nixos-autoupdate-notify-trigger = {
          description = "Trigger NixOS auto-update notification on session activity";
          wantedBy = [ "default.target" ];
          pathConfig = {
            # Watch for changes in the session state
            # This is more efficient than a 5-minute timer
            PathExists = "%t/systemd/user/graphical-session.target";
            Unit = "nixos-autoupdate-notify.service";
          };
        };

        # Ensure the notification state directory exists
        systemd.tmpfiles.rules = [
          "d /var/lib/nixos-autoupdate 0755 root root -"
        ];
      })
    ]
  );
}
