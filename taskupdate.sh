#!/usr/bin/env bash

# Determine the machine (RPI or DELL) based on CPU architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm"* ]]; then
    MACHINE="RPI"
    REMOTE_HOST="10.0.0.235" 
    REMOTE_USER="klein"
    REMOTE_SSH="ssh $REMOTE_USER@$REMOTE_HOST"
elif [[ "$ARCH" == "x86_64" ]]; then
    MACHINE="DELL"
    REMOTE_HOST="73.251.121.88" 
    REMOTE_USER="klein"
    REMOTE_PORT=22
    REMOTE_SSH="ssh -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
else
    echo "Unknown machine architecture: $ARCH"
    exit 1
fi

echo "Running on: $MACHINE"

# Local file paths
LOCAL_FILE="$HOME/.local/share/todo/tasks.txt"
LAST_MERGED="$HOME/.local/share/todo/last_merged_tasks.txt"

# Ensure the local files exist
touch "$LOCAL_FILE"
touch "$LAST_MERGED"

REMOTE_FILE="/home/$REMOTE_USER/.local/share/todo/tasks.txt"

# Temporary files
REMOTE_TEMP="/tmp/remote_task.txt"
TEMP_MERGED="/tmp/merged_tasks.txt"

# Function to fetch file contents from the remote machine
fetch_remote_file() {
    echo "Fetching tasks from remote ($REMOTE_HOST)..."
    if $REMOTE_SSH "test -f $REMOTE_FILE"; then
        $REMOTE_SSH "cat $REMOTE_FILE" > "$REMOTE_TEMP"
    else
        echo "Remote tasks file does not exist, creating an empty file."
        touch "$REMOTE_TEMP"
    fi
}

# Fetch remote file contents
fetch_remote_file

# Ensure all files are sorted
sort -o "$LOCAL_FILE" "$LOCAL_FILE"
sort -o "$REMOTE_TEMP" "$REMOTE_TEMP"

# Merge logic considering deletions
if [[ -f "$LAST_MERGED" ]]; then
    echo "Merging tasks with deletion tracking..."
    # Identify deletions on both local and remote
    comm -23 "$LAST_MERGED" "$LOCAL_FILE" > /tmp/deleted_in_local.txt
    comm -23 "$LAST_MERGED" "$REMOTE_TEMP" > /tmp/deleted_in_remote.txt

    # Combine local and remote files
    cat "$LOCAL_FILE" "$REMOTE_TEMP" | sort -u > /tmp/combined.txt

    # Remove deleted items
    grep -vxFf /tmp/deleted_in_local.txt /tmp/combined.txt > /tmp/temp1.txt
    grep -vxFf /tmp/deleted_in_remote.txt /tmp/temp1.txt > "$TEMP_MERGED"

    # Clean up temporary files
    rm /tmp/deleted_in_local.txt /tmp/deleted_in_remote.txt /tmp/combined.txt /tmp/temp1.txt
else
    echo "No previous merge file found. Performing first-time merge."
    cat "$LOCAL_FILE" "$REMOTE_TEMP" | sort -u > "$TEMP_MERGED"
fi

# Update both local and remote databases
cp "$TEMP_MERGED" "$LOCAL_FILE"
scp -P "$REMOTE_PORT" "$TEMP_MERGED" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_FILE"

# Save the merged version for future comparison
cp "$TEMP_MERGED" "$LAST_MERGED"

# Clean up
rm "$REMOTE_TEMP" "$TEMP_MERGED"

echo "Merge completed successfully."
