# Migration Guide

This guide helps users migrate from the old default.nix module to the new flake-based module.

## Overview

The nixos-autoupdate module has been completely rewritten as a proper NixOS flake with many new features:

- ✨ Local (non-git) flake support
- 🔋 Laptop wake-up functionality
- ⚡ AC power detection
- 🔔 Desktop notifications
- 📦 Proper flake structure

## Migration Steps

### Option 1: Using Flakes (Recommended)

If you're already using flakes:

**Before:**
```nix
{
  imports = [
    /path/to/nixos-autoupdate/default.nix
  ];
  
  system.autoupdate = {
    enable = true;
    repository = "git+ssh://...";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
  };
}
```

**After:**
```nix
# In your flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-autoupdate.url = "github:Vcele/nixos-autoupdate";
  };
  
  outputs = { nixpkgs, nixos-autoupdate, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-autoupdate.nixosModules.default
        {
          system.autoupdate = {
            enable = true;
            flake = "git+ssh://...";  # Changed from 'repository'
            sshKeySops = "autoupgrade/ssh_key";
            sopsFile = ./secrets.yaml;
          };
        }
      ];
    };
  };
}
```

### Option 2: Without Flakes

If you're not using flakes yet:

**Before:**
```nix
{
  imports = [
    /path/to/nixos-autoupdate/default.nix
  ];
  
  system.autoupdate = {
    enable = true;
    repository = "git+ssh://...";
    # ... other options
  };
}
```

**After:**
```nix
{
  imports = [
    /path/to/nixos-autoupdate/module.nix  # Changed from default.nix
  ];
  
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://...";  # Changed from 'repository'
    # ... other options (same as before)
  };
}
```

**Note:** The old `default.nix` still exists and imports `module.nix` for backward compatibility, but it's recommended to import `module.nix` directly.

## Configuration Changes

### Renamed Options

| Old Option | New Option | Notes |
|------------|------------|-------|
| `repository` | `flake` | `repository` still works but is deprecated |

### New Options

You can now use these new options:

```nix
{
  system.autoupdate = {
    # ... existing options ...
    
    # Local flake support (no git required)
    localFlake = true;
    
    # AC power detection
    onlyOnACPower = true;
    
    # Wake-up configuration
    wakeup = {
      enable = true;
      wakeupTime = "03:55";
      autoSuspendAfter = true;
    };
    
    # Desktop notifications
    notification = {
      enable = true;
      urgency = "normal";
      timeout = 30000;
    };
  };
}
```

## Breaking Changes

### None! 🎉

The migration is fully backward compatible:
- Old option names still work (`repository` → `flake`)
- All existing functionality is preserved
- New features are opt-in

## Example Migrations

### Example 1: Basic Git Setup

**Before:**
```nix
{
  system.autoupdate = {
    enable = true;
    repository = "git+ssh://git@github.com/user/config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
    schedule = "daily";
  };
}
```

**After (minimal changes):**
```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@github.com/user/config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
    schedule = "daily";
  };
}
```

**After (with new features):**
```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://git@github.com/user/config?ref=main";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
    schedule = "daily";
    
    # Add notifications
    notification = {
      enable = true;
    };
  };
}
```

### Example 2: Laptop Configuration

**Before:**
```nix
{
  system.autoupdate = {
    enable = true;
    repository = "git+ssh://...";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
    schedule = "04:00";
  };
}
```

**After (with laptop features):**
```nix
{
  system.autoupdate = {
    enable = true;
    flake = "git+ssh://...";
    sshKeySops = "autoupgrade/ssh_key";
    sopsFile = ./secrets.yaml;
    schedule = "04:00";
    
    # Laptop-specific features
    onlyOnACPower = true;
    wakeup = {
      enable = true;
      wakeupTime = "03:55";
      autoSuspendAfter = true;
    };
    notification = {
      enable = true;
    };
  };
}
```

### Example 3: Local Flake

**Before (not possible with old module):**

**After:**
```nix
{
  system.autoupdate = {
    enable = true;
    localFlake = true;  # No git repository needed!
    schedule = "daily";
    
    notification = {
      enable = true;
    };
  };
}
```

## Testing Your Migration

1. **Backup your current configuration**
   ```bash
   sudo nixos-rebuild build
   ```

2. **Update your configuration** with the new module

3. **Test the build**
   ```bash
   sudo nixos-rebuild dry-build
   ```

4. **Apply the changes**
   ```bash
   sudo nixos-rebuild switch
   ```

5. **Verify the service**
   ```bash
   systemctl status nixos-upgrade.timer
   systemctl status nixos-upgrade.service
   ```

6. **Check the configuration**
   ```bash
   systemctl cat nixos-upgrade.service
   ```

## Rollback

If you encounter issues, you can easily rollback:

```bash
# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or select a specific generation
nixos-rebuild switch --switch-generation <number>
```

## Getting Help

If you encounter issues during migration:

1. Check the [TESTING.md](TESTING.md) file for troubleshooting steps
2. Review the [README.md](README.md) for configuration examples
3. Open an issue on GitHub with:
   - Your configuration
   - Error messages
   - Output of `systemctl status nixos-upgrade.service`

## Why Migrate?

Benefits of the new module:

1. **Flake support** - Proper integration with modern NixOS
2. **Local flakes** - No git repository required
3. **Laptop features** - Wake-up and AC power detection
4. **Notifications** - Know when updates complete
5. **Better documentation** - Comprehensive README and examples
6. **Better testing** - Automated test suite included
7. **Active development** - New features and improvements

## Timeline

- **Old module (default.nix)**: Deprecated but still functional
- **New module (module.nix)**: Recommended for all new deployments
- **Support**: Both versions supported, old version will be maintained for compatibility

## Questions?

See the [README.md](README.md) for full documentation or open an issue on GitHub.
