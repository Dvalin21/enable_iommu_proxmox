# enable_iommu_proxmox


Explanation of Enhancements

User-Friendliness:

Added -h flag with usage instructions.

Verbose mode (-v) for detailed output.

Clearer reboot prompt with a 10-second timeout defaulting to "yes".

Error Handling:

Checks for root privileges.

Validates file writability and command success with exit codes.

Creates backups of modified files with timestamps.

Enterprise Features:

Logging to /var/log/iommu_setup.log for auditing.

Dry-run mode (-d) to test without changes.

Configurable via command-line flags.

Robustness:

Case-insensitive CPU detection with grep -i.

Structured error messages and graceful exits.

Backup mechanism to rollback manually if needed.

Security:

Explicit root check to prevent unauthorized runs.
File backups reduce risk of irreversible changes.
