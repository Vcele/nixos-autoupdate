# Example: Laptop Configuration with Wake-up and AC Power

{ config, pkgs, ... }:

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
    randomizedDelaySec = "30m";
  };
}
