#!/bin/bash

# Default variable values
ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.1-x86_64.iso"
ISO_NAME="alpine-VIRT.iso"
VM_NAME="alpine_vm"
VM_DISK="alpine_vm.qcow2"
DISK_SIZE="10G"
MEMORY="4096"
CPUS="4"
VNC_PORT=":0"
VNC_DISPLAY_PORT=5900  # Default VNC display port for :0
VNC_PASSWORD="your_password"
MONITOR_SOCKET="/tmp/qemu-monitor-socket"


# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --delete-vm       Delete the VM. Exits after."
    echo "  -h, --help        Display this help message"
    echo "  --iso-url         Specify the URL of the ISO file (default: $ISO_URL)"
    echo "  --iso-name        Specify the name of the ISO file (default: $ISO_NAME)"
    echo "  --vm-name         Specify the name of the VM (default: $VM_NAME)"
    echo "  --vm-disk         Specify the name of the VM disk (default: $VM_DISK)"
    echo "  --disk-size       Specify the size of the VM disk (default: $DISK_SIZE)"
    echo "  --memory          Specify the memory size for the VM (default: $MEMORY)"
    echo "  --cpus            Specify the number of CPUs for the VM (default: $CPUS)"
    exit 1
}

# Parse command line arguments
while [[ "$1" != "" ]]; do
    case $1 in
        --delete-vm )
            DELETE_VM=true
            ;;
        --iso-url )
            shift
            ISO_URL=$1
            ;;
        --iso-name )
            shift
            ISO_NAME=$1
            ;;
        --vm-name )
            shift
            VM_NAME=$1
            ;;
        --vm-disk )
            shift
            VM_DISK=$1
            ;;
        --disk-size )
            shift
            DISK_SIZE=$1
            ;;
        --memory )
            shift
            MEMORY=$1
            ;;
        --cpus )
            shift
            CPUS=$1
            ;;
        -h | --help )
            usage
            ;;
        * )
            echo "Invalid argument: $1"
            usage
            ;;
    esac
    shift
done

# Function to stop and delete the VM
cleanup_vm() {
    echo "Stopping and deleting the VM..."

    # Stop the VM
    pkill -f "qemu-system-x86_64 -name $VM_NAME"

    # Find and delete VM disk images
    VM_DISKS=$(qemu-img info --backing-chain $VM_NAME | grep 'file:' | awk '{print $2}')
    if [ -z "$VM_DISKS" ]; then
        echo "No disk images found for VM: $VM_NAME"
    else
        for VM_DISK in $VM_DISKS; do
            if [ -f $VM_DISK ]; then
                rm -f $VM_DISK
                echo "Deleted disk image: $VM_DISK"
            else
                echo "Disk image $VM_DISK not found."
            fi
        done
    fi

    echo "VM cleanup complete!"
}

# Check if --delete-vm was passed
if [ "$DELETE_VM" = true ]; then
    echo "The --delete-vm argument was provided."
    cleanup_vm
    echo "Exiting..."
    exit 1
else
    echo "No --delete-vm argument provided."
fi

# Required utilities

# Get the root directory of the project
PROJECT_ROOT=$(dirname "$0")/..

# Source the functions file
source "$PROJECT_ROOT/lib/ensure_command_available.sh"

# dependencies
ensure_command_available aria2c
ensure_command_available qemu-system-x86_64
ensure_command_available qemu-img
ensure_command_available socat

# Download Linux ISO
if [ ! -f $ISO_NAME ]; then
  echo "Downloading Alpine Linux ISO..."
  aria2c -x 16 -s 16 -o "$ISO_NAME" "$ISO_URL"
fi

# Create a QCOW2 disk image
if [ ! -f $VM_DISK ]; then
 echo "Creating QCOW2 disk image..."
 qemu-img create -f qcow2 $VM_DISK $DISK_SIZE
fi

# Create a kickstart script for unattended installation
cat << 'EOF' > ks.cfg
# Alpine Linux kickstart script

# Set root password
rootpw --iscrypted $(echo 'root:password' | mkpasswd -s -m sha-512)

# Network configuration
network --bootproto=dhcp --device=eth0

# System timezone
timezone UTC

# Bootloader configuration
bootloader --location=mbr

# Partition clearing information
clearpart --all --initlabel

# Disk partitioning information
part / --fstype=ext4 --size=1 --grow

# Packages to install
%packages
@standard
openssh
%end

# Post installation scripts
%post
echo "root:password" | chpasswd
apk update
apk upgrade
rc-update add sshd
%end
EOF

kickstart_path=$(realpath ./ks.cfg)

echo "kickstart path: $kickstart_path"

# Assigning the command to a variable
qemu_command="qemu-system-x86_64 \
  -name "$VM_NAME" \
  -m "$MEMORY" \
  -smp cpus="$CPUS" \
  -hda "$VM_DISK" \
  -cdrom "$ISO_NAME" \
  -boot d \
  -netdev user,id=user.0 \
  -device e1000,netdev=user.0 \
  -monitor stdio \
  -vnc "$VNC_PORT" \
  -drive file="$kickstart_path",format=raw,if=virtio"

# Echoing the command with word wrap
echo "Running QEMU command:"
echo "$qemu_command" | fold -w 80 -s

# Terminate all running QEMU processes
echo "Terminating all running QEMU processes..."
pkill qemu-system-x86_64

# Wait a moment to ensure all processes are terminated
sleep 2

# Check if the VNC port is available
if lsof -i :$VNC_DISPLAY_PORT; then
  echo "VNC port $VNC_DISPLAY_PORT is still in use. Releasing the port..."
  PID=$(lsof -t -i :$VNC_DISPLAY_PORT)
  if [ -n "$PID" ]; then
    echo "Killing process $PID using port $VNC_DISPLAY_PORT..."
    kill -9 $PID
    sleep 2
  fi
fi

# Remove any existing monitor socket file
rm -f $MONITOR_SOCKET

qemu-system-x86_64 \
  -name "$VM_NAME" \
  -m "$MEMORY" \
  -smp cpus="$CPUS" \
  -drive "file=$VM_DISK,if=virtio,index=0,media=disk" \
  -cdrom "$ISO_NAME" \
  -boot d \
  -netdev user,id=user.0 \
  -device e1000,netdev=user.0 \
  -monitor unix:$MONITOR_SOCKET,server,nowait \
  -vnc "$VNC_PORT,password=on" \
  -drive "file=$kickstart_path,format=raw,if=virtio,index=1,media=disk" \
  &
# Wait a moment for the VM to start
sleep 2

# Set the VNC password using the QEMU monitor
echo "Setting VNC password..."
(echo "change vnc password"; echo "$VNC_PASSWORD") | socat - UNIX-CONNECT:$MONITOR_SOCKET

# Determine the VNC URL
VNC_URL="vnc://localhost:$VNC_DISPLAY_PORT"
echo "VNC URL to access the VM: $VNC_URL"

# Attempt to open the VNC viewer on macOS
if command -v open > /dev/null; then
  open "$VNC_URL"
else
  echo "Please open your VNC viewer and connect to $VNC_URL"
fi