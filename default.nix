{
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.system.autoupdate;
in
{
  options.system.autoupdate = {
    enable = mkEnableOption "Enable automatic system updates";

    # option to set the git repository URL
    repository = mkOption {
      type = types.str;
      example = "git+ssh://soft-serve:23231/geek/nixos?ref=flake";
      description = "The git repository URL to pull updates from";
    };

    # option to set the sops secret key for the SSH key
    sshKeySops = mkOption {
      type = types.str;
      example = "autoupgrade/ssh_key";
      description = "Sops secret key for the SSH private key used to access the git repository";
    };

    # option to set the sops file path
    sopsFile = mkOption {
      type = types.path;
      default = ../../../../secrets/secrets.yaml;
      example = literalExpression "../../../../secrets/secrets.yaml";
      description = "Path to the sops file containing the SSH key secret";
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
      description = "When to run automatic updates (systemd timer format)";
    };

    # option to set CPU scheduling policy
    cpuSchedulingPolicy = mkOption {
      type = types.str;
      default = "idle";
      example = "batch";
      description = "CPU scheduling policy for the update process";
    };

    # option to set IO scheduling class
    ioSchedulingClass = mkOption {
      type = types.str;
      default = "idle";
      example = "best-effort";
      description = "IO scheduling class for the update process";
    };

    # option to allow updates even with dirty git tree
    allowDirty = mkOption {
      type = types.bool;
      default = false;
      description = "Allow automatic updates even when the local git tree is dirty (has uncommitted changes)";
    };
  };

  config = mkIf cfg.enable {
    # Set up sops secret for the SSH key
    # By default reads from secrets/secrets.yaml, but can be overridden
    sops.secrets.${cfg.sshKeySops} = {
      mode = "0600";
      owner = "root";
      group = "root";
      sopsFile = cfg.sopsFile;
    };

    # Configure automatic system updates
    system.autoUpgrade = {
      enable = true;
      flake = cfg.repository;
      flags = cfg.flags;
      randomizedDelaySec = cfg.randomizedDelaySec;
      dates = cfg.schedule;
    };

    # Configure the nixos-upgrade systemd service
    systemd.services.nixos-upgrade = mkMerge [
      {
        # Set SSH command to use the decrypted SSH key
        environment = {
          GIT_SSH_COMMAND = "ssh -i ${config.sops.secrets.${cfg.sshKeySops}.path} -o StrictHostKeyChecking=accept-new";
        };

        # Service restart configuration
        startLimitIntervalSec = 120;
        startLimitBurst = 6;

        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "20";
          CPUSchedulingPolicy = cfg.cpuSchedulingPolicy;
          IOSchedulingClass = cfg.ioSchedulingClass;
        };
      }

      # Add preStart test only if enabled
      (mkIf (cfg.enablePreStartTest && cfg.sshTestHost != null) {
        preStart = mkBefore "ssh -i ${config.sops.secrets.${cfg.sshKeySops}.path} -o StrictHostKeyChecking=accept-new ${cfg.sshTestHost}";
      })

      # Add git dirty check unless allowDirty is true
      (mkIf (!cfg.allowDirty) {
        preStart = mkBefore ''
          if [ "$(${inputs.self.rev or "dirty"})" = "dirty" ]; then
            echo "Git tree is dirty, skipping auto-update. Set allowDirty = true to override."
            exit 0
          fi
        '';
      })
    ];
  };
}
