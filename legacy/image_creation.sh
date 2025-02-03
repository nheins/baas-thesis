#!/bin/bash

# Configuration variables.
RUN_BASE_LAYER=false
RUN_APP_LAYER=false
RUN_VERIFY=true

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

create_app_layer() {
    echo "Creating application layer..."
    
    truncate -s $APP_SIZE $OUTPUT_DIR/app_layer.img
    mkfs.ext4 $OUTPUT_DIR/app_layer.img
    mount -o loop $OUTPUT_DIR/app_layer.img $MOUNT_POINT
    
    debootstrap --variant=minbase focal $MOUNT_POINT $DEBOOTSTRAP_MIRROR

    chroot $MOUNT_POINT /bin/bash -c "
        apt-get update
        
        # Install web server and database
        apt-get install -y --no-install-recommends \
            nginx \
        
        # Clean up
        apt-get clean
        rm -rf /var/lib/apt/lists/*
        
        # Basic nginx configuration
        echo 'server {
            listen 80 default_server;
            root /var/www/html;
            index index.php index.html;
            
            location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
            }
        }' > /etc/nginx/sites-available/default
    "
    
    umount $MOUNT_POINT
}

# Verify file system as good as possible
verify_images() {
    echo "Verifying images..."
    
    for img in base_image.img app_layer.img config_layer.img; do
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

while (( $# >= 1 )); do 
    case $1 in
    --base) RUN_BASE_LAYER=true;;
    --app) RUN_APP_LAYER=true;;
    --no-verify) RUN_VERIFY=false;;
    *) break;
    esac;
    shift
done

# Call functions based on options
if [ "$RUN_BASE_LAYER" = true ]; then
    create_base_layer
fi

if [ "$RUN_APP_LAYER" = true ]; then
    create_app_layer
fi

if [ "$RUN_VERIFY" = true ]; then
    verify_images
fi    

echo "Image creation complete. Images are in $OUTPUT_DIR"