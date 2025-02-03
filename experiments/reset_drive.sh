#!/bin/bash

# Script to completely wipe a drive and create a fresh partition
# USAGE: ./reset_drive.sh <drive_path> [--fs=ext4|btrfs]
# Example: ./reset_drive.sh /dev/sdb --fs=ext4
# Use --fs flag to specify filesystem type (default: ext4)

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

confirm_action() {
    read -p "This will PERMANENTLY DELETE ALL DATA on $1. Are you sure? (yes/no): " answer
    # ,, makes it all lower case
    if [[ ${answer,,} != "yes" ]]; then
        error_exit "Operation cancelled by user"
    fi
}

# root is needed for these actions
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root (sudo)"
fi

# Parse command line arguments. Bash is so self-explainatory <.<
FILESYSTEM="ext4"
DISCARD=false
for arg in "$@"; do
    case $arg in
        --fs=*)
            FS="${arg#*=}"
            if [[ "$FS" == "ext4" || "$FS" == "btrfs" ]]; then
                FILESYSTEM="$FS"
            else
                error_exit "Invalid filesystem type. Use --fs=ext4 or --fs=btrfs"
            fi
            ;;
        --discard)
            DISCARD=true
            ;;
        /dev/*)
            DRIVE="$arg"
            ;;
        *)
            error_exit "Unknown argument: $arg"
            ;;
    esac
done

# Check if drive path is provided
if [[ -z $DRIVE ]]; then
    error_exit "Drive path not provided. Usage: $0 <drive_path> [--fs=ext4|btrfs]"
fi

# Check if drive exists
if [[ ! -b $DRIVE ]]; then
    error_exit "Drive $DRIVE not found or not a block device"
fi

# Check if drive is mounted
if mount | grep -q "$DRIVE"; then
    error_exit "Drive $DRIVE is currently mounted. Please unmount it first"
fi

# Confirm with user. Better not give a wrong drive ...
confirm_action $DRIVE

echo "Starting drive reset process..."

if [[ "$DISCARD" == true ]]; then
    echo "Discard all blocks on drive $DRIVE"
    blkdiscard $DRIVE
fi

echo "Creating new GPT partition table..."
parted -s $DRIVE mklabel gpt || \
    error_exit "Failed to create GPT partition table"

# Create a single partition using all available space
echo "Creating new partition..."
parted -s $DRIVE mkpart primary 0% 100% || \
    error_exit "Failed to create partition"

NEW_PARTITION="${DRIVE}1"
echo "Formatting partition with $FILESYSTEM..."

case $FILESYSTEM in
    ext4)
        mkfs.ext4 -F $NEW_PARTITION || \
            error_exit "Failed to format partition with ext4"
        ;;
    btrfs)
        mkfs.btrfs -f $NEW_PARTITION || \
            error_exit "Failed to format partition with btrfs"
        ;;
esac

echo "Drive reset completed successfully!"
echo "New partition created: $NEW_PARTITION"
echo "Filesystem type: $FILESYSTEM"
echo
echo "You can now mount the drive using:"
echo "sudo mount $NEW_PARTITION /your/mount/point"
