#!/bin/bash
DEV="/dev/sda"
MOUNT="/mnt"

umount ${DEV}
blkdiscard -f ${DEV}
mkfs.ext4 ${DEV}
mount ${DEV} ${MOUNT} 