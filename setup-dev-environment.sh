#!/bin/bash

# Ensure Homebrew is installed
if ! type brew > /dev/null; then
  echo "Homebrew is not installed."
  echo "Please install Homebrew by running the following command:"
  echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

# Ensure wget is installed
if ! command -v wget &> /dev/null; then
    while true; do
        echo "wget is not installed."
        read -p "Would you like to install wget using Homebrew? (yes/no/quit): " choice

        case "$choice" in
            [yY]|[yY][eE][sS])
                # Install wget using Homebrew
                echo "Installing wget using Homebrew..."
                brew install wget
                break
                ;;
            [nN]|[nN][oO])
                echo "wget is required to continue. Please install wget manually."
                exit 1
                ;;
            [qQ]|[qQ][uU][iI][tT])
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter 'yes', 'no', or 'quit'."
                ;;
        esac
    done
fi

# Ensure aria2c is installed
if ! command -v aria2c &> /dev/null; then
    while true; do
        echo "aria2 is not installed."
        read -p "Would you like to install aria2 using Homebrew? (yes/no/quit): " choice

        case "$choice" in
            [yY]|[yY][eE][sS])
                # Install aria2 using Homebrew
                echo "Installing aria2 using Homebrew..."
                brew install aria2
                break
                ;;
            [nN]|[nN][oO])
                echo "Skipping aria2 installation."
                exit 1
                ;;
            [qQ]|[qQ][uU][iI][tT])
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter 'yes', 'no', or 'quit'."
                ;;
        esac
    done
fi

# Check if VirtualBox is installed
if ! type VBoxManage > /dev/null; then
  echo "VirtualBox is not installed. The VBoxManage command was not found"
  echo "Please install VirtualBox from https://www.virtualbox.org/wiki/Downloads"
  exit 1
fi

# Set up directories
SCRIPT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ISO_DIR="$SCRIPT_ROOT/iso"
mkdir -p "$ISO_DIR"

# ISO and signature URLs
ISO_NAME="Rocky-8.9-x86_64-minimal.iso"
ISO_URL="https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.9-x86_64-minimal.iso"
ISO_FILE="$ISO_DIR/$ISO_NAME"
CHECKSUM_URL="https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.9-x86_64-minimal.iso.CHECKSUM"
CHECKSUM_FILE="$ISO_DIR/Rocky-8.9-x86_64-minimal.iso.CHECKSUM"

# Function to verify a rocky linux SHA256 checksum
verify_rocky_checksum() {
    local iso_file="$1"
    local checksum_file="$2"
    
    # Get the expected hash value from the checksum file
    local expected_hash=$(sed -n "s/.*SHA256 (${ISO_NAME}) = \(.*\)/\1/p" "$checksum_file")

    # Calculate the actual hash value of the ISO file
    local actual_hash=$(sha256sum "$iso_file" | cut -d ' ' -f 1)

    # Compare the expected and actual hash values
    if [ "$expected_hash" = "$actual_hash" ]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

# Download the Ubuntu Server Minimal ISO if it doesn't exist
if [ ! -f "$ISO_DIR/$ISO_NAME" ]; then
  echo "Downloading Rocky 8.9 Minimal ISO..."
  # Perform a download using aria2
  echo "Downloading Rocky 8.9"
  aria2c -x 16 -s 16 -o "$ISO_FILE" "$ISO_URL"
  echo "Downloading ISO signature..."
  wget -O "$ISO_DIR/CHECKSUM_FILE" "$CHECKSUM_URL"

  # Verify the ISO
  echo "Verifying ISO..."
  # Call the function to verify checksum
  if verify_rocky_checksum "$ISO_FILE" "$CHECKSUM_FILE"; then
      echo "Hash matches!"
  else
    echo "Hash doesn't match!"
    exit 1
  fi
else
  echo "Rocky Server ISO already downloaded."
fi

VM_FILES_DIR="$SCRIPT_ROOT/vm_files"
mkdir -p "$VM_FILES_DIR"

# Create a new VM
VM_NAME="RockyServerMinimal-8.9"
VM_FILES_DIR="/path/to/your/vm/files"
ISO_FILE="/path/to/your/ubuntu_iso_file.iso"

# Check if VM already exists
if VBoxManage showvminfo "$VM_NAME" &>/dev/null; then
    echo "VM $VM_NAME already exists."
    echo "You can start it with: VBoxManage startvm \"$VM_NAME\""
else
    echo "Creating a new VM: $VM_NAME"
    VBoxManage createvm --name "$VM_NAME" --ostype Ubuntu_64 --register
    VBoxManage modifyvm "$VM_NAME" --memory 4096 --vram 128
    VBoxManage createmedium disk --filename "$VM_FILES_DIR/$VM_NAME/$VM_NAME.vdi" --size 10240 --format VDI
    VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VM_FILES_DIR/$VM_NAME/$VM_NAME.vdi"
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$ISO_FILE"

    echo "VM $VM_NAME created successfully. You can start it with: VBoxManage startvm \"$VM_NAME\""
fi

# Function to host a Kickstart file using Docker and nginx
function host_kickstart {
  local file_path=$1
  local port=$2
  local file_name=$(basename "$file_path")

  # If $file_path is a relative path, expand it to a full path
  if [[ ! $file_path = /* ]]; then
    file_path=$(realpath "$file_path")
  fi

  # Check if Docker is running
  if ! docker info >/dev/null 2>&1; then
    echo "Docker does not seem to be running. Please start Docker and try again."
    exit 1
  fi

  # Check if the port is already in use
  if lsof -i :$port >/dev/null; then
    echo "Port $port is already in use. Please choose a different port."
    exit 1
  fi

  # Check if the specified file exists
  if [ ! -f "$file_path" ]; then
    echo "The specified file does not exist: $file_path"
    exit 1
  fi

  # Run Docker command to start nginx with the specified file
  docker run --name kickstart-host -v "$file_path":/usr/share/nginx/html/"$file_name":ro -p "$port":80 -d nginx >/dev/null

  # Check if the Docker container started successfully
  if [ $? -eq 0 ]; then
    echo "Kickstart file is now being hosted."
    echo "You can access it at http://localhost:$port/$file_name"
  else
    echo "Failed to start the nginx container."
  fi
}

# Call the function with the file path and port number
KICKSTART_FILE="kickstart/ks.cfg"

if [ -f "$SCRIPT_ROOT/$KICKSTART_FILE" ]; then
    echo "ks.cfg exists in $SCRIPT_ROOT/kickstart/ directory."
else
    read -p "ks.cfg does not exist. Do you want to run overwrite_kickstart.sh in the current directory? [y/n]: " choice
    case "$choice" in 
      y|Y ) ./overwrite_kickstart.sh;;
      n|N ) echo "Exiting script."; exit 1;;
      * ) echo "Invalid input. Please enter 'y' or 'n'.";;
    esac
fi

host_kickstart "$KICKSTART_FILE" 8080

# Get the local IP address using `ip a` (on macOS, use `ifconfig`)
LOCAL_IP=$(ifconfig | awk '/inet / && ($2 ~ /^192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])/) {print $2}' | head -n 1)

# Check if an IP address was found
if [ -z "$LOCAL_IP" ]; then
    echo "No local IP address found on typical private ranges."
    exit 1
fi

# Generate the URL for the Kickstart file
KS_URL="http://$LOCAL_IP:8080/ks.cfg"

#confirm the kickstart config url is working. Perform the wget request and suppress output
response=$(wget --spider --server-response "$KS_URL" 2>&1)

# Check if wget returned a success message
if echo "$response" | grep -q "200 OK"; then
    echo "File is available at $KS_URL"
else
    echo "File is not available at $KS_URL"
    echo Exiting
    exit 1
fi

echo "sleeping for 60 seconds"
sleep 60












docker stop kickstart-host
sleep 2
docker rm kickstart-host