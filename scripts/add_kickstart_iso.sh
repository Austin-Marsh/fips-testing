#!/bin/bash

# Help function to display usage instructions
usage() {
  echo "Usage: $0 <path_to_iso> <path_to_target_file>"
  echo "Example: $0 /path/to/source.iso /path/to/target/file"
  exit 1
}

# Check if both arguments are provided
if [[ -z "$1" || -z "$2" ]]; then
  echo "Error: Missing arguments."
  usage
fi

# Define the path to the ISO and the local file to be copied
ISO="$1"
TARGET_FILE="$2"

# Get the root directory of the project
PROJECT_ROOT=$(dirname "$0")/..

# Source the functions file
source "$PROJECT_ROOT/lib/ensure_command_available.sh"

# dependencies
ensure_command_available hdiutil
ensure_command_available mkisofs

# Check if the ISO file exists
if [[ ! -f "$ISO" ]]; then
  echo "ISO file not found: $ISO"
  exit 1
fi

# Check if the target file exists
if [[ ! -f "$TARGET_FILE" ]]; then
  echo "Target file not found: $TARGET_FILE"
  exit 1
fi

# Create temporary directories for mounting and extracting the ISO
MOUNT_DIR=$(mktemp -d)
EXTRACT_DIR=$(mktemp -d)

# Mount the ISO file
hdiutil attach "$ISO" -mountpoint "$MOUNT_DIR"

# Copy the contents of the mounted ISO to the extraction directory
rsync -av "$MOUNT_DIR/" "$EXTRACT_DIR/"

# Unmount the ISO file
hdiutil detach "$MOUNT_DIR"

# Copy the target file to the desired location within the extracted ISO
mkdir -p "$EXTRACT_DIR/root"
cp "$TARGET_FILE" "$EXTRACT_DIR/root/install.ks"

# Create a new ISO file with the modified contents
NEW_ISO="${ISO%.iso}-modified.iso"
mkisofs -o "$NEW_ISO" -R -J -V "Custom ISO" "$EXTRACT_DIR"

# Clean up temporary directories
rm -rf "$TEMP_DIR" "$MOUNT_DIR" "$EXTRACT_DIR"

echo "New ISO created: $NEW_ISO"