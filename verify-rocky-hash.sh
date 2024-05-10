#!/bin/bash

# URL to the checksum file
checksum_url="$1"

# File path to the ISO file
iso_file="$2"

# Function to calculate SHA256 hash of a file
calculate_sha256() {
    sha256sum "$1" | cut -d ' ' -f 1
}

# Download the checksum file
wget -q "$checksum_url" -O checksum.txt

# Extract hash value from the checksum file
iso_filename=$(basename "$iso_file")
iso_hash=$(grep -oP "(?<=${iso_filename} = ).*" checksum.txt)

# Calculate SHA256 hash of the ISO file
iso_file_hash=$(calculate_sha256 "$iso_file")

# Check if hashes match
if [ "$iso_file_hash" = "$iso_hash" ]; then
    echo "Checksum verification successful!"
else
    echo "Checksum verification failed!"
fi

# Clean up - remove checksum file
rm checksum.txt
