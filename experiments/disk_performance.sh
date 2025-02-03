#!/bin/bash

# Default values
FILE_SIZE="100M"
TARGET_DIR="/mnt"
MODE="count"
DURATION=60  # seconds
COUNT=10     # number of iterations
PATTERN="random"  # can be "random" or "zero"

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -s, --size SIZE      File size (default: 100M)"
    echo "  -d, --dir DIR        Target directory (default: current directory)"
    echo "  -t, --time SECONDS   Run for specified duration"
    echo "  -c, --count NUMBER   Run specified number of iterations"
    echo "  -p, --pattern TYPE   Data pattern: random or zero (default: random)"
    echo "  -h, --help          Show this help message"
    echo
    echo "Example:"
    echo "  $0 -s 1G -d /mnt/testdrive -t 300 -p zero"
    echo "  $0 -s 500M -d /mnt/testdrive -c 20 -p random"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--size)
            FILE_SIZE="$2"
            shift 2
            ;;
        -d|--dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        -t|--time)
            MODE="time"
            DURATION="$2"
            shift 2
            ;;
        -c|--count)
            MODE="count"
            COUNT="$2"
            shift 2
            ;;
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate target directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory $TARGET_DIR does not exist"
    exit 1
fi
if [ ! -w "$TARGET_DIR" ]; then
    echo "Error: Directory $TARGET_DIR is not writable"
    exit 1
fi

# Set data source based on pattern
if [ "$PATTERN" = "random" ]; then
    DATA_SOURCE="/dev/urandom"
elif [ "$PATTERN" = "zero" ]; then
    DATA_SOURCE="/dev/zero"
else
    echo "Error: Invalid pattern. Use 'random' or 'zero'"
    exit 1
fi

# Initialize counters
iteration=0
start_time=$(date +%s)
total_bytes=0

echo "Starting disk write test..."
echo "Target directory: $TARGET_DIR"
echo "File size: $FILE_SIZE"
echo "Pattern: $PATTERN"
if [ "$MODE" = "time" ]; then
    echo "Duration: $DURATION seconds"
else
    echo "Count: $COUNT iterations"
fi

test_write() {
    local file="$TARGET_DIR/test_${iteration}.tmp"
    
    # Write file and capture timing
    time_output=$(TIMEFORMAT='%R'; time (
        dd if=$DATA_SOURCE of="$file" bs=$FILE_SIZE count=1 2>/dev/null
        sync
    ) 2>&1)
        
    echo "Iteration $iteration: $time_output seconds "
    
    # Cleanup
    rm "$file"
}

# Main loop
while true; do
    # Check exit conditions
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ "$MODE" = "time" ] && [ $elapsed -ge $DURATION ]; then
        break
    elif [ "$MODE" = "count" ] && [ $iteration -ge $COUNT ]; then
        break
    fi
    
    test_write
    iteration=$((iteration + 1))
done

# Print summary
echo
echo "Test completed:"
echo "Total iterations: $iteration"
echo "Total time: $elapsed seconds"