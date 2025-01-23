#!/bin/bash

# Configuration variables. Use flags?
BASE_SIZE="5G"
APP_SIZE="2G"
CONFIG_SIZE="100M"
OUTPUT_DIR="./images"
MOUNT_POINT="/mnt/image_build"
DEBOOTSTRAP_MIRROR="http://archive.ubuntu.com/ubuntu"

create_base_layer() {
    echo "Creating base layer..."
    
    truncate -s $BASE_SIZE $OUTPUT_DIR/base_image.img
    
    mkfs.ext4 $OUTPUT_DIR/base_image.img
    
    mount -o loop $OUTPUT_DIR/base_image.img $MOUNT_POINT
    
    debootstrap --variant=minbase focal $MOUNT_POINT $DEBOOTSTRAP_MIRROR
    
    # Basic configuration
    chroot $MOUNT_POINT /bin/bash -c "
        # Set timezone
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime
        
        # Configure apt
        echo 'deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse' > /etc/apt/sources.list
        apt-get update
        
        # Install essential packages
        apt-get install -y --no-install-recommends
        
        # Clean up
        apt-get clean
        rm -rf /var/lib/apt/lists/*
    "

    umount $MOUNT_POINT
}

# Verify file system as good as possible
verify_images() {
    echo "Verifying images..."
    
    for img in base_image.img; do
        echo "Checking $img..."
        e2fsck -f $OUTPUT_DIR/$img
                
        file $OUTPUT_DIR/$img
        ls -lh $OUTPUT_DIR/$img
    done
}

# Check for root privileges, otherwise tools are not available
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    return 1
fi

# Prepare output directory
mkdir -p $OUTPUT_DIR
mkdir -p $MOUNT_POINT

# Install required tools. Necessary?!
apt-get update
apt-get install -y debootstrap e2fsprogs
    
create_base_layer
    
verify_images

echo "Image creation complete. Images are in $OUTPUT_DIR"