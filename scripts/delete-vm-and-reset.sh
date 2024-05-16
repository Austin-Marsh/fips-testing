#!/bin/bash

# Check if the script is being run from the correct directory
if [[ "$(basename $(pwd))" != "fips-testing" ]]; then
    echo "Please run this script from the 'fips-testing' directory."
    exit 1
fi

# Check if VBoxManage is available
if ! command -v VBoxManage &>/dev/null; then
    echo "VBoxManage is not installed or not in the PATH."
    exit 1
fi

# Set default VM name if not provided as argument
if [ -z "$1" ]; then
    vm_name="RockyServerMinimal-8.9"
else
    vm_name="$1"
fi

# Check if the VM exists
if VBoxManage showvminfo "$vm_name" &>/dev/null; then
    echo "Deleting VM: $vm_name"
    # Power off the VM if it's running
    VBoxManage controlvm "$vm_name" poweroff &>/dev/null
    # Unregister and delete the VM and associated files
    VBoxManage unregistervm "$vm_name" --delete
    echo "VM $vm_name and associated files deleted."
else
    echo "VM $vm_name does not exist."
fi
