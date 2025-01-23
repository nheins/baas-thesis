#!/bin/bash

# Check for root privileges, otherwise tools are not available
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    return 1
fi

######################################
# !!!! BE CAREFUL WHAT TO PUT HERE !!!
######################################
DEVICE_PATH="/dev/sdd1"

OUTPUT_DIR="./monitorings"

# Create output directory
mkdir -p ${OUTPUT_DIR}

# Move to seperate file or start in background
# Start monitoring
# ../.venv/bin/python ../ssd_monitor.py --device ${DEVICE_PATH} --output ${OUTPUT_DIR} --interval 1

# Deploy base image
dd if=../images/base_image.img of=${DEVICE_PATH} bs=4M status=progress
