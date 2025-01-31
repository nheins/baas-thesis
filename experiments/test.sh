#!/bin/bash


confirm_action() {
    read -p "This will PERMANENTLY DELETE ALL DATA on $1. Are you sure? (yes/no): " answer
    if [[ ${answer,,} != "yes" ]]; then
        error_exit "Operation cancelled by user"
    fi
}

confirm_action $1

exit 0
