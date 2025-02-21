#!/bin/bash

# Enable IOMMU for Proxmox - Enhanced Version
# Usage: ./enable_iommu_proxmox.sh [-h] [-d] [-v]
#   -h: Show help
#   -d: Dry-run mode (simulate changes)
#   -v: Verbose output

# Constants
GRUB_FILE="/etc/default/grub"
MODULES_FILE="/etc/modules"
LOG_FILE="/var/log/iommu_setup.log"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

# Default options
DRY_RUN=0
VERBOSE=0

# Function to log messages
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
    [ "$VERBOSE" -eq 1 ] && echo "$message"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [-h] [-d] [-v]"
    echo "  -h: Show this help message"
    echo "  -d: Dry-run mode (simulate changes without applying)"
    echo "  -v: Verbose output"
    echo "Enables IOMMU for Proxmox by configuring GRUB and kernel modules."
    exit 0
}

# Parse command-line options
while getopts "hdv" opt; do
    case "$opt" in
        h) show_usage ;;
        d) DRY_RUN=1 ;;
        v) VERBOSE=1 ;;
        ?) exit 1 ;;
    esac
done

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Function to detect CPU manufacturer
get_cpu_manufacturer() {
    if lscpu | grep -i "GenuineIntel" >/dev/null 2>&1; then
        echo "intel"
    elif lscpu | grep -i "AuthenticAMD" >/dev/null 2>&1; then
        echo "amd"
    else
        echo "unknown"
    fi
}

# Function to backup a file
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$file$BACKUP_SUFFIX" || {
            log "Error: Failed to backup $file"
            exit 1
        }
        log "Backed up $file to $file$BACKUP_SUFFIX"
    fi
}

# Function to configure GRUB
configure_grub() {
    local cpu_type="$1"
    local grub_entry=""

    [ "$cpu_type" == "intel" ] && grub_entry="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet intel_iommu=on iommu=pt\""
    [ "$cpu_type" == "amd" ] && grub_entry="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet amd_iommu=on iommu=pt\""

    if [ -z "$grub_entry" ]; then
        log "Error: Invalid CPU type for GRUB configuration"
        exit 1
    fi

    if [ ! -w "$GRUB_FILE" ]; then
        log "Error: $GRUB_FILE is not writable"
        exit 1
    }

    backup_file "$GRUB_FILE"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "Dry-run: Would update $GRUB_FILE with: $grub_entry"
    else
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet.*|$grub_entry|" "$GRUB_FILE" || {
            log "Error: Failed to update $GRUB_FILE"
            exit 1
        }
        update-grub || {
            log "Error: Failed to run update-grub"
            exit 1
        }
        log "Updated GRUB configuration for $cpu_type CPU"
    fi
}

# Function to configure modules
configure_modules() {
    local vfio_entries=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")

    if [ ! -w "$MODULES_FILE" ]; then
        log "Error: $MODULES_FILE is not writable"
        exit 1
    }

    backup_file "$MODULES_FILE"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "Dry-run: Would update $MODULES_FILE with VFIO modules"
    else
        sed -i '/vfio\|vfio_iommu_type1\|vfio_pci\|vfio_virqfd/d' "$MODULES_FILE" || {
            log "Error: Failed to clean $MODULES_FILE"
            exit 1
        }
        for entry in "${vfio_entries[@]}"; do
            echo "$entry" >> "$MODULES_FILE" || {
                log "Error: Failed to append $entry to $MODULES_FILE"
                exit 1
            }
        done
        log "Updated $MODULES_FILE with VFIO modules"
    fi
}

# Main logic
log "Starting IOMMU configuration for Proxmox"
cpu_type=$(get_cpu_manufacturer)

case "$cpu_type" in
    "intel"|"amd")
        log "Detected $cpu_type CPU"
        configure_grub "$cpu_type"
        configure_modules
        log "Configuration completed for $cpu_type CPU"
        ;;
    *)
        log "Error: Unsupported CPU type or detection failed"
        exit 1
        ;;
esac

# Reboot prompt with timeout
if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run: Would prompt for reboot"
else
    echo -n "Reboot now? (y/n, default y in 10s): "
    read -t 10 choice
    choice=${choice:-y}
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        log "Rebooting system"
        reboot
    else
        log "Please reboot later to apply changes"
    fi
fi

exit 0
